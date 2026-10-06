import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../models/models.dart';
import '../services/material_catalog.dart';
import '../widgets/floor_3d_painter.dart';
import 'model_asset_catalog.dart';
import 'render_quality.dart';
import 'zamer_scene_geometry.dart';

/// GPU-backed 3D viewport for Zamер.
///
/// Measurement data remains in millimetres in [FloorPlan]. It is converted to
/// metres only at the renderer boundary because Flutter Scene uses metres and
/// +Y as the up axis. This keeps CAD/measurement calculations deterministic
/// while allowing a conventional realtime 3D scene.
class ZamerGpuViewport extends StatefulWidget {
  const ZamerGpuViewport({
    super.key,
    required this.floor,
    required this.rotation,
    required this.tilt,
    required this.zoom,
    required this.cutaway,
    required this.pan,
    required this.walkMode,
    required this.walkX,
    required this.walkY,
    this.walkFovDegrees = 76,
    this.quality = ZamerRenderQuality.quality,
  });

  final FloorPlan floor;
  final double rotation;
  final double tilt;
  final double zoom;
  final bool cutaway;
  final Offset pan;
  final bool walkMode;
  final double walkX;
  final double walkY;
  final double walkFovDegrees;
  final ZamerRenderQuality quality;

  @override
  State<ZamerGpuViewport> createState() => ZamerGpuViewportState();
}

class ZamerGpuViewportState extends State<ZamerGpuViewport>
    with WidgetsBindingObserver {
  Scene? _scene;
  final Map<String, Node> _modelTemplates = <String, Node>{};
  final List<_WallVisual> _wallVisuals = <_WallVisual>[];
  final List<Node> _ceilingNodes = <Node>[];
  final List<SpotLight> _shadowSpots = <SpotLight>[];
  final Map<String, Texture2D> _finishTextures = <String, Texture2D>{};
  final Map<String, Texture2D> _normalTextures = <String, Texture2D>{};
  final Map<String, Texture2D> _dataTextures = <String, Texture2D>{};
  Texture2D? _concreteTexture;
  Texture2D? _plasterTexture;

  ZamerSceneGeometry? _geometry;
  Object? _loadError;
  bool _ready = false;
  int _buildGeneration = 0;
  bool _initializing = false;
  int _retryAttempt = 0;
  Timer? _retryTimer;
  int _lastFloorFingerprint = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastFloorFingerprint = _floorFingerprint();
    // Wait until the visible 3D tab has produced its first Android surface.
    // Initialising Flutter Scene while this widget was offstage was the main
    // reason some devices needed a complete app restart before 3D appeared.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_ready) {
      _scheduleRetry(immediate: true);
    }
  }

  void _scheduleRetry({bool immediate = false}) {
    if (!mounted || _ready) return;
    _retryTimer?.cancel();
    _retryAttempt++;
    final delay = immediate
        ? Duration.zero
        : Duration(milliseconds: math.min(3200, 350 + _retryAttempt * 350));
    _retryTimer = Timer(delay, _initialize);
  }

  @override
  void didUpdateWidget(covariant ZamerGpuViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quality != widget.quality) {
      _configureScene();
    }
    final fingerprint = _floorFingerprint();
    if (!identical(oldWidget.floor, widget.floor) ||
        fingerprint != _lastFloorFingerprint) {
      _lastFloorFingerprint = fingerprint;
      _rebuildScene();
    }
  }

  int _floorFingerprint() {
    final values = <Object?>[
      widget.floor.defaultHeightMm,
      widget.floor.walls.length,
      widget.floor.planObjects.length,
      widget.floor.electricalPoints.length,
    ];
    for (final wall in widget.floor.walls) {
      values.addAll(<Object?>[
        wall.id,
        wall.startNodeId,
        wall.endNodeId,
        wall.thicknessMm,
        wall.heightOverrideMm,
        wall.openings.length,
      ]);
    }
    for (final meta in widget.floor.roomMetas) {
      final m = meta.materials;
      values.addAll(<Object?>[
        meta.faceKey,
        m.floorMode,
        m.floorMaterialId,
        m.floorDirectionDeg,
        m.tileWidthMm,
        m.tileHeightMm,
        m.tilePattern,
        m.tileOffsetXMm,
        m.tileOffsetYMm,
        m.laminatePlankLengthMm,
        m.laminatePlankWidthMm,
        m.laminatePattern,
        m.laminateOffsetMode,
        m.laminateOffsetXMm,
        m.laminateOffsetYMm,
        m.wallMaterialId,
        m.wallPaintColorArgb,
        m.wallTile,
        m.wallTileMaterialId,
        m.wallTileTintArgb,
        m.wallTileWidthMm,
        m.wallTileHeightMm,
        m.wallTileOffsetXMm,
        m.wallTileOffsetYMm,
        m.wallTileGroutMm,
      ]);
      final runIds = <String>{
        ...m.wallTileRunOffsetX.keys,
        ...m.wallTileRunOffsetY.keys,
        ...m.wallTileRunEnabled.keys,
        ...m.wallTileRunMirrored.keys,
      }.toList()..sort();
      for (final runId in runIds) {
        values.addAll(<Object?>[
          runId,
          m.wallTileRunOffsetX[runId],
          m.wallTileRunOffsetY[runId],
          m.wallTileRunEnabled[runId],
          m.wallTileRunMirrored[runId],
        ]);
      }
    }
    for (final object in widget.floor.planObjects) {
      values.addAll(<Object?>[
        object.id,
        object.catalogId,
        object.xMm,
        object.yMm,
        object.widthMm,
        object.depthMm,
        object.heightMm,
        object.elevationMm,
        object.rotationDeg,
      ]);
    }
    return Object.hashAll(values);
  }

  Future<void> _initialize() async {
    if (_initializing || !mounted) return;
    _initializing = true;
    try {
      // flutter_scene requires its static GPU resources to be initialized
      // after a real surface exists. The viewport now retries automatically,
      // so a transient first-frame GPU failure never requires an app restart.
      await Scene.initializeStaticResources();
      if (!mounted) return;
      _scene?.removeAll();
      _scene = Scene();
      _configureScene();
      await _loadFinishTextures();
      await _rebuildScene();
      if (!mounted) return;
      _retryTimer?.cancel();
      _retryAttempt = 0;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _ready = false;
      });
      _scheduleRetry();
    } finally {
      _initializing = false;
    }
  }

  void retryGpu() {
    _retryAttempt = 0;
    _scheduleRetry(immediate: true);
  }

  void _configureScene() {
    final scene = _scene;
    if (scene == null) return;

    if (widget.quality == ZamerRenderQuality.photo4k) {
      _configurePhotoLighting();
      return;
    }

    final isQuality = widget.quality == ZamerRenderQuality.quality;
    scene.environmentSettings = EnvironmentSettings(
      toneMapping: ToneMappingMode.pbrNeutral,
      environmentIntensity: isQuality ? 1.0 : 0.82,
      exposure: isQuality ? 1.02 : 0.96,
      colorGradingEnabled: isQuality,
      brightness: 1.0,
      contrast: isQuality ? 1.025 : 1.0,
      saturation: isQuality ? 1.015 : 1.0,
      temperature: isQuality ? 0.012 : 0.0,
      ambientOcclusionEnabled: widget.quality.ambientOcclusionEnabled,
      ambientOcclusionRadius: 0.24,
      ambientOcclusionIntensity: isQuality ? 0.64 : 0.45,
      ambientOcclusionBias: 0.04,
      ambientOcclusionSampleCount: widget.quality.ambientOcclusionSamples,
      ambientOcclusionHalfResolution: true,
      screenSpaceReflectionsEnabled: widget.quality.reflectionsEnabled,
      screenSpaceReflectionsIntensity: isQuality ? 0.32 : 0.0,
      screenSpaceReflectionsMaxDistance: 12,
      screenSpaceReflectionsThickness: 0.45,
      screenSpaceReflectionsStride: 4,
      screenSpaceReflectionsMaxSteps: isQuality ? 48 : 16,
      screenSpaceReflectionsBlur: 0.22,
      screenSpaceReflectionsResolutionScale:
          widget.quality.reflectionsResolutionScale,
      bloomEnabled: widget.quality.bloomEnabled,
      bloomThreshold: 1.30,
      bloomIntensity: isQuality ? 0.035 : 0.0,
      bloomScatter: 0.55,
      vignetteEnabled: false,
      autoExposureEnabled: false,
    );
    scene.antiAliasingMode = AntiAliasingMode.auto;
    scene.environmentIntensity = isQuality ? 1.0 : 0.82;
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-0.45, -1.0, -0.32)..normalize(),
      color: vm.Vector3(1.0, 0.97, 0.92),
      intensity: isQuality ? 2.75 : 2.35,
      castsShadow: true,
      cacheStaticShadows: false,
      shadowMapResolution: widget.quality.shadowMapResolution,
      shadowMaxDistance: isQuality ? 40 : 30,
      shadowSoftness: isQuality ? 0.20 : 0.12,
    );
    scene.ambientOcclusion
      ..enabled = widget.quality.ambientOcclusionEnabled
      ..halfResolution = true
      ..sampleCount = widget.quality.ambientOcclusionSamples
      ..radius = 0.24
      ..intensity = isQuality ? 0.64 : 0.45
      ..bias = 0.04;
    scene.globalIllumination
      ..enabled = isQuality
      ..volumeMode = IrradianceVolumeMode.fitScene
      ..resolution = vm.Vector3(12, 6, 12)
      ..intensity = isQuality ? 0.72 : 0.0
      ..hysteresis = 0.93
      ..shadowBias = 0.28
      ..visibility = 0.78
      ..visibilityBias = 0.065
      ..probeUpdateBudget = isQuality ? 96 : 0
      ..injectionResolution = IrradianceInjectionResolution.eighth
      ..fireflyClamp = 6.0
      ..emissiveGiBoost = 1.35
      ..updateWhenIdleOnly = isQuality
      ..bakeOnly = false;
    _configureLocalLightQuality(widget.quality);
  }

  void _configurePhotoLighting() {
    final scene = _scene;
    if (scene == null) return;
    scene.environmentSettings = EnvironmentSettings(
      toneMapping: ToneMappingMode.pbrNeutral,
      environmentIntensity: 1.15,
      exposure: 1.06,
      colorGradingEnabled: true,
      brightness: 1.01,
      contrast: 1.04,
      saturation: 1.025,
      temperature: 0.025,
      ambientOcclusionEnabled: true,
      ambientOcclusionRadius: 0.28,
      ambientOcclusionIntensity: 0.72,
      ambientOcclusionBias: 0.035,
      ambientOcclusionSampleCount: 12,
      ambientOcclusionHalfResolution: false,
      screenSpaceReflectionsEnabled: true,
      screenSpaceReflectionsIntensity: 0.55,
      screenSpaceReflectionsMaxDistance: 18,
      screenSpaceReflectionsThickness: 0.42,
      screenSpaceReflectionsStride: 3,
      screenSpaceReflectionsMaxSteps: 96,
      screenSpaceReflectionsBlur: 0.18,
      screenSpaceReflectionsResolutionScale: 1.0,
      bloomEnabled: true,
      bloomThreshold: 1.12,
      bloomIntensity: 0.09,
      bloomScatter: 0.62,
      vignetteEnabled: true,
      vignetteIntensity: 0.08,
      vignetteRadius: 0.86,
      vignetteSmoothness: 0.55,
      autoExposureEnabled: true,
      autoExposureStrength: 0.45,
      autoExposureCompensation: 0.15,
      autoExposureMinEv: -1.2,
      autoExposureMaxEv: 1.8,
    );
    scene.antiAliasingMode = AntiAliasingMode.auto;
    scene.environmentIntensity = 1.15;
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-0.38, -1.0, -0.28)..normalize(),
      color: vm.Vector3(1.0, 0.965, 0.90),
      intensity: 3.05,
      castsShadow: true,
      cacheStaticShadows: false,
      shadowMapResolution: 2048,
      shadowMaxDistance: 45,
      shadowSoftness: 0.30,
    );
    scene.ambientOcclusion
      ..enabled = true
      ..halfResolution = false
      ..sampleCount = 8
      ..radius = 0.30
      ..intensity = 0.82
      ..bias = 0.035;
    scene.globalIllumination
      ..enabled = true
      ..volumeMode = IrradianceVolumeMode.fitScene
      ..resolution = vm.Vector3(16, 8, 16)
      ..intensity = 0.92
      ..hysteresis = 0.88
      ..shadowBias = 0.26
      ..visibility = 0.86
      ..visibilityBias = 0.055
      ..probeUpdateBudget = 0
      ..injectionResolution = IrradianceInjectionResolution.quarter
      ..fireflyClamp = 5.5
      ..emissiveGiBoost = 1.65
      ..updateWhenIdleOnly = false
      ..bakeOnly = false;
    _configureLocalLightQuality(ZamerRenderQuality.photo4k);
  }

  void _configureLocalLightQuality(ZamerRenderQuality quality) {
    final enabled = quality != ZamerRenderQuality.performance;
    final resolution = quality == ZamerRenderQuality.photo4k ? 1024 : 512;
    final softness = quality == ZamerRenderQuality.photo4k ? 2.4 : 1.6;
    for (final light in _shadowSpots) {
      light
        ..castsShadow = enabled
        ..shadowMapResolution = resolution
        ..shadowNear = 0.055
        ..shadowNormalBias = 0.025
        ..shadowDepthBias = 0.00015
        ..shadowSoftness = softness;
    }
  }

  Future<void> _loadFinishTextures() async {
    for (final preset in MaterialCatalog.presets) {
      final asset = preset.textureAsset;
      if (asset != null) {
        final candidates = <String>{
          asset,
          if (preset.pattern == 'wood' && asset.endsWith('.png'))
            asset.replaceFirst('.png', '_half.png'),
          if (preset.pattern == 'wood' && asset.endsWith('.png'))
            asset.replaceFirst('.png', '_third.png'),
        };
        for (final candidate in candidates) {
          if (_finishTextures.containsKey(candidate)) continue;
          try {
            _finishTextures[candidate] = await Texture2D.fromAsset(candidate);
          } catch (_) {
            // A missing decorative map must never take the complete room down.
          }
        }
      }

      final normalAsset = preset.normalAsset;
      if (normalAsset != null && !_normalTextures.containsKey(normalAsset)) {
        try {
          _normalTextures[normalAsset] = await Texture2D.fromAsset(
            normalAsset,
            content: TextureContent.normal,
          );
        } catch (_) {
          // PBR companions are optional while the library is being migrated.
        }
      }

      for (final dataAsset in <String?>[
        preset.metallicRoughnessAsset,
        preset.occlusionAsset,
      ]) {
        if (dataAsset == null || _dataTextures.containsKey(dataAsset)) continue;
        try {
          _dataTextures[dataAsset] = await Texture2D.fromAsset(
            dataAsset,
            content: TextureContent.data,
          );
        } catch (_) {
          // The base color still renders if a companion map is unavailable.
        }
      }
    }
    _concreteTexture ??= await Texture2D.fromAsset(
      'assets/textures/concrete_soft.png',
    );
    _plasterTexture ??= await Texture2D.fromAsset(
      'assets/textures/plaster_warm.png',
    );
  }

  Future<void> _rebuildScene() async {
    final generation = ++_buildGeneration;
    if (mounted) {
      setState(() {
        _ready = false;
        _loadError = null;
      });
    }

    final scene = _scene;
    if (scene == null) {
      if (mounted) {
        setState(() {
          _loadError = StateError('GPU-контекст недоступен');
          _ready = false;
        });
      }
      return;
    }

    final geometry = ZamerSceneGeometry.fromFloor(widget.floor);
    _geometry = geometry;
    scene.removeAll();
    _wallVisuals.clear();
    _ceilingNodes.clear();
    _shadowSpots.clear();

    final floorMaterialCache = <String, PhysicallyBasedMaterial>{};
    for (final surface in geometry.floors) {
      final node = _buildFloorNode(surface, geometry.bounds, floorMaterialCache);
      if (node != null) scene.add(node);
      final ceiling = _buildCeilingNode(surface, geometry.bounds);
      if (ceiling != null) {
        _ceilingNodes.add(ceiling);
        scene.add(ceiling);
      }
    }

    for (final wall in geometry.walls) {
      final node = _buildWallNode(wall, geometry.bounds);
      scene.add(node);
      _wallVisuals.add(
        _WallVisual(
          node: node,
          x: _mx(wall.centerXMm, geometry.bounds),
          z: _mz(wall.centerYMm, geometry.bounds),
        ),
      );
    }

    for (final opening in geometry.openings) {
      scene.add(_buildOpeningNode(opening, geometry.bounds));
    }
    for (final point in geometry.electrical) {
      scene.add(_buildElectricalNode(point, geometry.bounds));
    }

    for (final object in geometry.objects) {
      if (generation != _buildGeneration) return;
      final node = await _buildObjectNode(object, geometry.bounds);
      if (generation != _buildGeneration) return;
      scene.add(node);
    }

    if (!mounted || generation != _buildGeneration) return;
    setState(() => _ready = true);
  }

  Node? _buildFloorNode(
    ZamerFloorSurface surface,
    ZamerSceneBounds bounds,
    Map<String, PhysicallyBasedMaterial> materialCache,
  ) {
    if (surface.polygonMm.length < 3) return null;
    final indices = _triangulate(surface.polygonMm);
    if (indices.isEmpty) return null;

    final preset = MaterialCatalog.byId(surface.materialId);
    if (surface.laminatePattern == 'herringbone' &&
        preset.pattern == 'wood') {
      return _buildHerringboneFloorNode(
        surface,
        bounds,
        materialCache,
        indices,
      );
    }

    final uvScale = _floorUvScaleMm(surface);
    final effectiveDirection = surface.materialMode.toLowerCase().contains('tile')
        ? surface.directionDeg + (surface.tilePattern == 'diagonal' ? 45 : 0)
        : surface.directionDeg;
    final angle = effectiveDirection * math.pi / 180;
    final ca = math.cos(angle), sa = math.sin(angle);
    final isTile = surface.materialMode.toLowerCase().contains('tile') ||
        MaterialCatalog.byId(surface.materialId).pattern == 'tile';
    final offX = isTile ? surface.tileOffsetXMm : surface.laminateOffsetXMm;
    final offY = isTile ? surface.tileOffsetYMm : surface.laminateOffsetYMm;
    final builder = GeometryBuilder(deduplicate: false)
      ..normal(vm.Vector3(0, 1, 0));
    for (final point in surface.polygonMm) {
      final dx = point.x - surface.anchorXMm;
      final dy = point.y - surface.anchorYMm;
      final rx = dx * ca + dy * sa + offX;
      final ry = -dx * sa + dy * ca + offY;
      builder
        ..texCoord(vm.Vector2(rx / uvScale.$1, ry / uvScale.$2))
        ..addVertex(
          vm.Vector3(
            _mx(point.x, bounds),
            0.006,
            _mz(point.y, bounds),
          ),
        );
    }
    for (var i = 0; i < indices.length; i += 3) {
      builder.addTriangle(indices[i], indices[i + 1], indices[i + 2]);
    }

    final key = '${surface.materialMode}:${surface.materialId}';
    final material = materialCache.putIfAbsent(
      key,
      () => _floorMaterial(surface),
    );
    return Node(
      name: 'floor:${surface.roomKey}',
      mesh: Mesh(builder.build(), material),
    )
      ..castsShadows = false
      ..shadowStatic = true;
  }

  Node _buildHerringboneFloorNode(
    ZamerFloorSurface surface,
    ZamerSceneBounds bounds,
    Map<String, PhysicallyBasedMaterial> materialCache,
    List<int> roomIndices,
  ) {
    final plankLength = math.max(240.0, surface.plankLengthMm);
    final plankWidth = math.max(55.0, surface.plankWidthMm);
    final angle = surface.directionDeg * math.pi / 180;
    final ca = math.cos(angle);
    final sa = math.sin(angle);

    math.Point<double> toLocal(math.Point<double> p) {
      final dx = p.x - surface.anchorXMm;
      final dy = p.y - surface.anchorYMm;
      return math.Point<double>(
        dx * ca + dy * sa,
        -dx * sa + dy * ca,
      );
    }

    math.Point<double> toWorld(math.Point<double> p) => math.Point<double>(
          surface.anchorXMm + p.x * ca - p.y * sa,
          surface.anchorYMm + p.x * sa + p.y * ca,
        );

    final localRoom = surface.polygonMm.map(toLocal).toList(growable: false);
    var minX = localRoom.first.x;
    var maxX = minX;
    var minY = localRoom.first.y;
    var maxY = minY;
    for (final p in localRoom.skip(1)) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }

    final roomTriangles = <List<math.Point<double>>>[];
    for (var i = 0; i < roomIndices.length; i += 3) {
      roomTriangles.add(<math.Point<double>>[
        surface.polygonMm[roomIndices[i]],
        surface.polygonMm[roomIndices[i + 1]],
        surface.polygonMm[roomIndices[i + 2]],
      ]);
    }

    // The dark receiver is only visible through the tiny gaps between planks.
    // It makes the bevel/joint readable without baking a fake herringbone
    // pattern into the wood texture.
    final baseBuilder = GeometryBuilder(deduplicate: false)
      ..normal(vm.Vector3(0, 1, 0));
    for (final p in surface.polygonMm) {
      baseBuilder
        ..texCoord(vm.Vector2.zero())
        ..addVertex(vm.Vector3(_mx(p.x, bounds), 0.004, _mz(p.y, bounds)));
    }
    for (var i = 0; i < roomIndices.length; i += 3) {
      baseBuilder.addTriangle(
        roomIndices[i],
        roomIndices[i + 1],
        roomIndices[i + 2],
      );
    }

    final root = Node(name: 'floor-herringbone:${surface.roomKey}');
    root.add(
      Node(
        name: 'floor-herringbone-joints:${surface.roomKey}',
        mesh: Mesh(
          baseBuilder.build(),
          _pbr(
            vm.Vector4(0.075, 0.058, 0.045, 1),
            roughness: 0.90,
          )..doubleSided = true,
        ),
      )
        ..castsShadows = false
        ..shadowStatic = true,
    );

    final builder = GeometryBuilder(deduplicate: false)
      ..normal(vm.Vector3(0, 1, 0));
    final run = plankLength / math.sqrt2;
    final pitch = plankWidth * math.sqrt2;
    final ox = surface.laminateOffsetXMm % plankLength;
    final oy = surface.laminateOffsetYMm % plankWidth;
    final firstRow = ((minY - plankLength - oy) / pitch).floor();
    final lastRow = ((maxY + plankLength - oy) / pitch).ceil();
    final firstCol = ((minX - plankLength - ox) / run).floor();
    final lastCol = ((maxX + plankLength - ox) / run).ceil();
    var boardCount = 0;

    for (var row = firstRow; row <= lastRow && boardCount < 20000; row++) {
      final y = row * pitch + oy;
      for (var col = firstCol; col <= lastCol && boardCount < 20000; col++) {
        final x = col * run + ox;
        final y0 = y + (col.isOdd ? run : 0);
        final y1 = y + (col.isOdd ? 0 : run);
        var boardLocal = <math.Point<double>>[
          math.Point<double>(x, y0),
          math.Point<double>(x + run, y1),
          math.Point<double>(x + run, y1 + pitch),
          math.Point<double>(x, y0 + pitch),
        ];

        // A sub-percent inset exposes the joint receiver and reads as a bevel
        // at normal phone viewing distances without exploding vertex count.
        final centerX =
            boardLocal.fold<double>(0, (sum, p) => sum + p.x) / 4;
        final centerY =
            boardLocal.fold<double>(0, (sum, p) => sum + p.y) / 4;
        const insetScale = 0.994;
        boardLocal = boardLocal
            .map(
              (p) => math.Point<double>(
                centerX + (p.x - centerX) * insetScale,
                centerY + (p.y - centerY) * insetScale,
              ),
            )
            .toList(growable: false);

        final boardWorld = boardLocal.map(toWorld).toList(growable: false);
        final p0 = boardWorld[0];
        final p1 = boardWorld[1];
        final p3 = boardWorld[3];
        var alongX = p1.x - p0.x;
        var alongY = p1.y - p0.y;
        final alongLength = math.sqrt(alongX * alongX + alongY * alongY);
        if (alongLength < 0.001) continue;
        alongX /= alongLength;
        alongY /= alongLength;
        var perpX = -alongY;
        var perpY = alongX;
        if ((p3.x - p0.x) * perpX + (p3.y - p0.y) * perpY < 0) {
          perpX = -perpX;
          perpY = -perpY;
        }

        final shadeIndex = ((row * 31 + col * 17).abs()) % 4;
        final shade = const <double>[0.94, 0.975, 1.0, 0.96][shadeIndex];

        for (final triangle in roomTriangles) {
          final clipped = _clipPolygonToConvex(boardWorld, triangle);
          if (clipped.length < 3) continue;
          final vertexIndices = <int>[];
          for (final p in clipped) {
            final dx = p.x - p0.x;
            final dy = p.y - p0.y;
            final u = (dx * alongX + dy * alongY) / plankLength;
            final v = (dx * perpX + dy * perpY) / plankWidth;
            builder
              ..color(vm.Vector4(shade, shade, shade, 1))
              ..texCoord(vm.Vector2(u, v));
            vertexIndices.add(
              builder.addVertex(
                vm.Vector3(_mx(p.x, bounds), 0.008, _mz(p.y, bounds)),
              ),
            );
          }
          for (var i = 1; i < vertexIndices.length - 1; i++) {
            builder.addTriangle(
              vertexIndices[0],
              vertexIndices[i],
              vertexIndices[i + 1],
            );
          }
        }
        boardCount++;
      }
    }

    final key = '${surface.materialMode}:${surface.materialId}:herringbone';
    final material = materialCache.putIfAbsent(
      key,
      () => _floorMaterial(surface),
    );
    root.add(
      Node(
        name: 'floor-herringbone-planks:${surface.roomKey}',
        mesh: Mesh(builder.build(), material),
      )
        ..castsShadows = false
        ..shadowStatic = true,
    );
    return root;
  }

  PhysicallyBasedMaterial _floorMaterial(ZamerFloorSurface surface) {
    final preset = MaterialCatalog.byId(surface.materialId);
    final mode = surface.materialMode.toLowerCase();
    final texture = _textureForFloorSurface(surface, preset);
    final roughness = preset.roughness ??
        (preset.pattern == 'tile'
            ? 0.40
            : preset.pattern == 'wood'
                ? 0.54
                : preset.pattern == 'concrete'
                    ? 0.86
                    : 0.70);
    final tint = texture == null
        ? _vectorColor(preset.color)
        : vm.Vector4(0.98, 0.98, 0.98, 1);
    final material = _pbr(
      tint,
      roughness: roughness,
      texture: texture,
      normalTexture: preset.normalAsset == null
          ? null
          : _normalTextures[preset.normalAsset],
      metallicRoughnessTexture: preset.metallicRoughnessAsset == null
          ? null
          : _dataTextures[preset.metallicRoughnessAsset],
      occlusionTexture: preset.occlusionAsset == null
          ? null
          : _dataTextures[preset.occlusionAsset],
      normalScale: preset.normalScale,
      occlusionStrength: preset.occlusionStrength,
    )..doubleSided = true;
    return material;
  }

  TextureSource? _textureForFloorSurface(
    ZamerFloorSurface surface,
    VisualMaterialPreset preset,
  ) {
    final asset = preset.textureAsset;
    if (asset != null && preset.pattern == 'wood' &&
        surface.laminatePattern != 'herringbone') {
      if (surface.laminateOffsetMode == 'half') {
        final candidate = asset.replaceFirst('.png', '_half.png');
        final texture = _finishTextures[candidate];
        if (texture != null) return texture;
      } else if (surface.laminateOffsetMode == 'third') {
        final candidate = asset.replaceFirst('.png', '_third.png');
        final texture = _finishTextures[candidate];
        if (texture != null) return texture;
      }
    }
    return _textureForPreset(preset, fallbackMode: surface.materialMode.toLowerCase());
  }

  (double, double) _floorUvScaleMm(ZamerFloorSurface surface) {
    final preset = MaterialCatalog.byId(surface.materialId);
    final mode = surface.materialMode.toLowerCase();
    if (preset.pattern == 'tile' || mode.contains('tile') || mode.contains('плит')) {
      return (
        math.max(60.0, surface.tileWidthMm),
        math.max(60.0, surface.tileHeightMm),
      );
    }
    if (preset.pattern == 'concrete' || mode.contains('бетон')) {
      return const (1000.0, 1000.0);
    }
    if (surface.laminatePattern == 'herringbone') {
      return (
        math.max(240.0, surface.plankLengthMm),
        math.max(80.0, surface.plankWidthMm),
      );
    }
    final repeatX = surface.laminateOffsetMode == 'third' ? 3.0 :
        surface.laminateOffsetMode == 'half' ? 2.0 : 1.0;
    final repeatY = surface.laminateOffsetMode == 'third' ? 3.0 :
        surface.laminateOffsetMode == 'half' ? 2.0 : 1.0;
    return (
      math.max(240.0, surface.plankLengthMm) * repeatX,
      math.max(80.0, surface.plankWidthMm) * repeatY,
    );
  }

  PhysicallyBasedMaterial _wallCoreMaterial() => _pbr(
        vm.Vector4(0.78, 0.79, 0.79, 1),
        roughness: 0.92,
      )..doubleSided = true;

  PhysicallyBasedMaterial _wallFinishMaterial(
    ZamerWallFinishLayer finish,
    ZamerWallPiece wall,
  ) {
    final id = finish.tileEnabled ? finish.tileMaterialId : finish.materialId;
    final preset = MaterialCatalog.byId(id);
    final texture = _textureForPreset(
      preset,
      fallbackMode: finish.tileEnabled ? 'tile' : 'wall',
    );
    final presetColor = finish.tileEnabled
        ? Color(finish.tileTintArgb)
        : (finish.materialId.startsWith('paint-')
            ? (finish.wallColorArgb == 0
                ? preset.color
                : Color(finish.wallColorArgb))
            : preset.color);
    final source = _vectorColor(presetColor);
    final tint = texture == null
        ? source
        : (finish.tileEnabled
            ? vm.Vector4(
                0.28 + source.x * 0.72,
                0.28 + source.y * 0.72,
                0.28 + source.z * 0.72,
                1,
              )
            : vm.Vector4(
                0.92 + source.x * 0.08,
                0.92 + source.y * 0.08,
                0.92 + source.z * 0.08,
                1,
              ));
    final material = _pbr(
      tint,
      roughness: preset.roughness ??
          (finish.tileEnabled
              ? 0.40
              : (preset.pattern == 'concrete' ? 0.90 : 0.82)),
      texture: texture,
      normalTexture: preset.normalAsset == null
          ? null
          : _normalTextures[preset.normalAsset],
      metallicRoughnessTexture: preset.metallicRoughnessAsset == null
          ? null
          : _dataTextures[preset.metallicRoughnessAsset],
      occlusionTexture: preset.occlusionAsset == null
          ? null
          : _dataTextures[preset.occlusionAsset],
      normalScale: preset.normalScale,
      occlusionStrength: preset.occlusionStrength,
    )..doubleSided = false;
    if (finish.tileEnabled && texture != null) {
      final tileW = math.max(20.0, finish.tileWidthMm);
      final tileH = math.max(20.0, finish.tileHeightMm);
      final transform = TextureTransform(
        scale: vm.Vector2(
          (finish.tileMirrored ? -1.0 : 1.0) *
              math.max(1.0, wall.lengthMm / tileW),
          math.max(1.0, wall.heightMm / tileH),
        ),
        offset: vm.Vector2(
          finish.tileMirrored
              ? 1.0 - finish.tileOffsetXMm / tileW
              : finish.tileOffsetXMm / tileW,
          -finish.tileOffsetYMm / tileH,
        ),
      );
      material.baseColorTextureTransform = transform;
      material.normalTextureTransform = TextureTransform(
        scale: transform.scale.clone(),
        offset: transform.offset.clone(),
        rotation: transform.rotation,
      );
      material.metallicRoughnessTextureTransform = TextureTransform(
        scale: transform.scale.clone(),
        offset: transform.offset.clone(),
        rotation: transform.rotation,
      );
      material.occlusionTextureTransform = TextureTransform(
        scale: transform.scale.clone(),
        offset: transform.offset.clone(),
        rotation: transform.rotation,
      );
    }
    return material;
  }

  TextureSource? _textureForPreset(
    VisualMaterialPreset preset, {
    required String fallbackMode,
  }) {
    final asset = preset.textureAsset;
    if (asset != null && _finishTextures[asset] != null) {
      return _finishTextures[asset];
    }
    if (preset.pattern == 'concrete' || fallbackMode.contains('бетон')) {
      return _concreteTexture;
    }
    if (preset.pattern == 'brick') return _plasterTexture;
    return null;
  }

  vm.Vector4 _vectorColor(Color color) => vm.Vector4(
        color.r,
        color.g,
        color.b,
        color.a,
      );

  Node? _buildCeilingNode(
    ZamerFloorSurface surface,
    ZamerSceneBounds bounds,
  ) {
    if (surface.polygonMm.length < 3) return null;
    final indices = _triangulate(surface.polygonMm);
    if (indices.isEmpty) return null;
    final builder = GeometryBuilder(deduplicate: false)
      ..normal(vm.Vector3(0, -1, 0));
    for (final point in surface.polygonMm) {
      builder
        ..texCoord(vm.Vector2(point.x / 1000, point.y / 1000))
        ..addVertex(vm.Vector3(
          _mx(point.x, bounds),
          surface.ceilingHeightMm / 1000,
          _mz(point.y, bounds),
        ));
    }
    for (var i = 0; i < indices.length; i += 3) {
      builder.addTriangle(indices[i + 2], indices[i + 1], indices[i]);
    }
    final material = _pbr(
      vm.Vector4(0.94, 0.94, 0.92, 1),
      roughness: 0.88,
    )..doubleSided = true;
    return Node(
      name: 'ceiling:${surface.roomKey}',
      mesh: Mesh(builder.build(), material),
    )
      ..castsShadows = true
      ..shadowStatic = true
      ..visible = widget.walkMode;
  }

  Node? _buildUnderWallFloorNode(
    ZamerWallPiece wall,
    ZamerSceneGeometry geometry,
    Map<String, PhysicallyBasedMaterial> materialCache,
  ) {
    if (geometry.floors.isEmpty) return null;
    ZamerFloorSurface nearest = geometry.floors.first;
    var best = double.infinity;
    for (final surface in geometry.floors) {
      if (surface.polygonMm.isEmpty) continue;
      var cx = 0.0, cy = 0.0;
      for (final p in surface.polygonMm) {
        cx += p.x;
        cy += p.y;
      }
      cx /= surface.polygonMm.length;
      cy /= surface.polygonMm.length;
      final dx = cx - wall.centerXMm;
      final dy = cy - wall.centerYMm;
      final d2 = dx * dx + dy * dy;
      if (d2 < best) {
        best = d2;
        nearest = surface;
      }
    }
    final key = '${nearest.materialMode}:${nearest.materialId}:under-wall';
    final material = materialCache.putIfAbsent(
      key,
      () => _floorMaterial(nearest),
    );
    final node = Node(
      name: 'floor-under-wall:${wall.wallId}',
      mesh: Mesh(
        CuboidGeometry(
          vm.Vector3(
            math.max(0.01, (wall.lengthMm + 8) / 1000),
            0.012,
            math.max(0.01, (wall.thicknessMm + 18) / 1000),
          ),
        ),
        material,
      ),
    );
    node
      ..position = vm.Vector3(
        _mx(wall.centerXMm, geometry.bounds),
        -0.002,
        _mz(wall.centerYMm, geometry.bounds),
      )
      ..rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        -wall.angleRad,
      )
      ..castsShadows = false
      ..shadowStatic = true;
    return node;
  }

  Node _buildWallNode(
    ZamerWallPiece wall,
    ZamerSceneBounds bounds,
  ) {
    final root = Node(name: 'wall:${wall.wallId}')
      ..position = vm.Vector3(
        _mx(wall.centerXMm, bounds),
        0,
        _mz(wall.centerYMm, bounds),
      )
      ..rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        -wall.angleRad,
      );

    final core = Node(
      name: 'wall-core:${wall.wallId}',
      mesh: Mesh(
        CuboidGeometry(
          vm.Vector3(
            math.max(0.002, wall.lengthMm / 1000),
            math.max(0.002, wall.heightMm / 1000),
            math.max(0.002, wall.thicknessMm / 1000),
          ),
        ),
        _wallCoreMaterial(),
      ),
    )
      ..position = vm.Vector3(
        0,
        (wall.bottomMm + wall.heightMm / 2) / 1000,
        0,
      )
      ..shadowStatic = true;
    root.add(core);

    for (final finish in wall.finishes) {
      // A wall finish is a real one-sided surface, not the material of the
      // whole cuboid. This prevents tile from leaking through to the opposite
      // room while still allowing each side of a shared wall to have its own
      // paint/tile settings.
      final thin = finish.tileEnabled ? 0.004 : 0.002;
      final layer = Node(
        name: 'wall-finish:${wall.wallId}:${finish.roomKey}:${finish.sideSign}',
        mesh: Mesh(
          CuboidGeometry(
            vm.Vector3(
              math.max(0.002, wall.lengthMm / 1000),
              math.max(0.002, wall.heightMm / 1000),
              thin,
            ),
          ),
          _wallFinishMaterial(finish, wall),
        ),
      )
        ..position = vm.Vector3(
          0,
          (wall.bottomMm + wall.heightMm / 2) / 1000,
          finish.sideSign * (wall.thicknessMm / 2000 + thin / 2 + 0.0005),
        )
        ..castsShadows = finish.tileEnabled
        ..shadowStatic = true;
      root.add(layer);
    }

    return root;
  }

  Node _buildOpeningNode(
    ZamerOpeningPlacement opening,
    ZamerSceneBounds bounds,
  ) {
    final root = Node(name: 'opening:${opening.id}')
      ..position = vm.Vector3(
        _mx(opening.xMm, bounds),
        0,
        _mz(opening.yMm, bounds),
      )
      ..rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        -opening.rotationRad,
      );

    final frameMaterial = _pbr(
      vm.Vector4(0.56, 0.43, 0.31, 1),
      roughness: 0.58,
    );
    final whiteFrameMaterial = _pbr(
      vm.Vector4(0.93, 0.94, 0.95, 1),
      roughness: 0.48,
    );
    final frame = opening.type == OpeningType.window
        ? whiteFrameMaterial
        : frameMaterial;
    final depthM = math.max(0.055, (opening.wallThicknessMm + 14) / 1000);
    final widthM = math.max(0.20, opening.widthMm / 1000);
    final heightM = math.max(0.20, opening.heightMm / 1000);
    const frameBarM = 0.045;

    Node bar({
      required String name,
      required double x,
      required double y,
      required double width,
      required double height,
      double depth = 0,
      PhysicallyBasedMaterial? material,
    }) {
      final node = Node(
        name: name,
        mesh: Mesh(
          CuboidGeometry(
            vm.Vector3(
              math.max(0.008, width),
              math.max(0.008, height),
              depth > 0 ? depth : depthM,
            ),
          ),
          material ?? frame,
        ),
      )
        ..position = vm.Vector3(x, y, 0)
        ..shadowStatic = true;
      return node;
    }

    final bottomM = opening.sillHeightMm / 1000;
    final topM = bottomM + heightM;
    root
      ..add(
        bar(
          name: 'opening-frame-left',
          x: -widthM / 2 + frameBarM / 2,
          y: bottomM + heightM / 2,
          width: frameBarM,
          height: heightM,
        ),
      )
      ..add(
        bar(
          name: 'opening-frame-right',
          x: widthM / 2 - frameBarM / 2,
          y: bottomM + heightM / 2,
          width: frameBarM,
          height: heightM,
        ),
      )
      ..add(
        bar(
          name: 'opening-frame-top',
          x: 0,
          y: topM - frameBarM / 2,
          width: widthM,
          height: frameBarM,
        ),
      );

    if (opening.type == OpeningType.window) {
      root.add(
        bar(
          name: 'opening-frame-bottom',
          x: 0,
          y: bottomM + frameBarM / 2,
          width: widthM,
          height: frameBarM,
        ),
      );
      root.add(
        bar(
          name: 'window-mullion',
          x: 0,
          y: bottomM + heightM / 2,
          width: 0.032,
          height: math.max(0.05, heightM - frameBarM * 2),
          depth: math.max(0.035, depthM * 0.62),
        ),
      );
      final glass = _pbr(
        vm.Vector4(0.72, 0.88, 0.96, 0.28),
        roughness: 0.10,
      )..doubleSided = true;
      root.add(
        bar(
          name: 'window-glass',
          x: 0,
          y: bottomM + heightM / 2,
          width: math.max(0.08, widthM - frameBarM * 2.2),
          height: math.max(0.08, heightM - frameBarM * 2.2),
          depth: 0.008,
          material: glass,
        ),
      );
    } else {
      final leftHinge = opening.doorSwing == DoorSwing.leftIn ||
          opening.doorSwing == DoorSwing.leftOut;
      final opensIn = opening.doorSwing == DoorSwing.leftIn ||
          opening.doorSwing == DoorSwing.rightIn;
      final hingeSign = leftHinge ? -1.0 : 1.0;
      final swingSign = (opensIn ? 1.0 : -1.0) * hingeSign;
      final leafWidth = math.max(0.12, widthM - frameBarM * 1.5);
      final leafHeight = math.max(0.18, heightM - frameBarM);
      final hinge = Node(name: 'door-hinge')
        ..position = vm.Vector3(
          hingeSign * (widthM / 2 - frameBarM),
          0,
          0,
        )
        ..rotation = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          swingSign * 32 * math.pi / 180,
        );
      final leafMaterial = _pbr(
        vm.Vector4(0.68, 0.52, 0.36, 1),
        roughness: 0.62,
      );
      hinge.add(
        Node(
          name: 'door-leaf',
          mesh: Mesh(
            CuboidGeometry(vm.Vector3(leafWidth, leafHeight, 0.038)),
            leafMaterial,
          ),
        )
          ..position = vm.Vector3(-hingeSign * leafWidth / 2, leafHeight / 2, 0)
          ..shadowStatic = true,
      );
      root.add(hinge);
    }
    _markStatic(root);
    return root;
  }

  Node _buildElectricalNode(
    ZamerElectricalPlacement point,
    ZamerSceneBounds bounds,
  ) {
    final isCeiling = point.type == ElectricalPointType.ceilingLight;
    final isPanel = point.type == ElectricalPointType.panel;
    final isJunction = point.type == ElectricalPointType.junctionBox;
    final isWallLight = point.type == ElectricalPointType.wallLight;
    final moduleCount = math.max(1, point.modules.length);

    double widthM = 0.086;
    double heightM = 0.086;
    if (point.type == ElectricalPointType.frame) {
      if (point.frameVertical) {
        heightM = 0.086 * moduleCount + 0.012 * (moduleCount - 1);
      } else {
        widthM = 0.086 * moduleCount + 0.012 * (moduleCount - 1);
      }
    } else if (isPanel) {
      widthM = 0.34;
      heightM = 0.48;
    } else if (isWallLight) {
      widthM = 0.14;
      heightM = 0.18;
    } else if (isJunction) {
      widthM = heightM = 0.10;
    }

    final accent = switch (point.type) {
      ElectricalPointType.switchPoint => vm.Vector4(0.93, 0.93, 0.91, 1),
      ElectricalPointType.socket => vm.Vector4(0.90, 0.91, 0.92, 1),
      ElectricalPointType.tvSocket => vm.Vector4(0.78, 0.83, 0.88, 1),
      ElectricalPointType.dataSocket => vm.Vector4(0.72, 0.82, 0.91, 1),
      ElectricalPointType.panel => vm.Vector4(0.72, 0.75, 0.77, 1),
      ElectricalPointType.appliance => vm.Vector4(0.91, 0.77, 0.39, 1),
      _ => vm.Vector4(0.94, 0.94, 0.93, 1),
    };
    final material = _pbr(accent, roughness: 0.46);

    if (isCeiling) {
      return Node(
        name: 'electrical:${point.id}:${point.type.name}',
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(0.16, 0.025, 0.16)),
          _pbr(vm.Vector4(1.0, 0.94, 0.72, 1), roughness: 0.35),
        ),
      )
        ..position = vm.Vector3(
          _mx(point.xMm, bounds),
          point.heightMm / 1000,
          _mz(point.yMm, bounds),
        )
        ..shadowStatic = true;
    }

    final nx = -math.sin(point.rotationRad);
    final ny = math.cos(point.rotationRad);
    final offsetMm = point.wallThicknessMm / 2 + 9;
    final x = point.xMm + nx * offsetMm * point.wallSide;
    final y = point.yMm + ny * offsetMm * point.wallSide;
    final depthM = isPanel ? 0.055 : (isWallLight ? 0.075 : 0.018);
    return Node(
      name: 'electrical:${point.id}:${point.type.name}',
      mesh: Mesh(
        CuboidGeometry(vm.Vector3(widthM, heightM, depthM)),
        material,
      ),
    )
      ..position = vm.Vector3(
        _mx(x, bounds),
        math.max(heightM / 2, point.heightMm / 1000),
        _mz(y, bounds),
      )
      ..rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        -point.rotationRad,
      )
      ..shadowStatic = true;
  }

  Future<Node> _buildObjectNode(
    ZamerObjectPlacement object,
    ZamerSceneBounds bounds,
  ) async {
    final asset = ZamerModelAssetCatalog.byId(object.catalogId);
    final root = Node(name: 'object:${object.id}:${object.catalogId}');
    var importedModel = false;

    if (asset == null) {
      root.add(_fallbackObject(object));
    } else {
      try {
        final template = _modelTemplates[asset.assetPath] ??=
            await Node.fromGlbAsset(asset.assetPath);
        final model = template.clone(recursive: true);
        importedModel = true;

        final sx = _safeRatio(object.widthMm, asset.nativeWidthMm);
        final sy = _safeRatio(object.heightMm, asset.nativeHeightMm);
        final sz = _safeRatio(object.depthMm, asset.nativeDepthMm);
        final localBounds = model.combinedLocalBounds;
        model.scale = vm.Vector3(sx, sy, sz);
        if (localBounds != null) {
          // Every plan object uses its footprint centre as the X/Y anchor.
          // Imported GLBs are not all authored around that same origin (wall
          // lights in particular start at the wall plane). Rebase the model to
          // its actual bounds so plan and 3D positions are mathematically the
          // same instead of merely looking close for centred assets.
          model.position = vm.Vector3(
            -localBounds.center.x * sx,
            -localBounds.min.y * sy,
            -localBounds.center.z * sz,
          );
        }
        root.add(model);
      } catch (_) {
        // A single bad optional model must never take the complete room down.
        root.add(_fallbackObject(object));
      }
    }

    root
      ..position = vm.Vector3(
        _mx(object.xMm, bounds),
        object.elevationMm / 1000,
        _mz(object.yMm, bounds),
      )
      ..rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        -object.rotationRad,
      );
    if (object.type == PlanObjectType.lighting) {
      _attachLightEmitter(root, object, importedModel: importedModel);
    }
    _markStatic(root);
    return root;
  }

  void _attachLightEmitter(
    Node objectNode,
    ZamerObjectPlacement object, {
    required bool importedModel,
  }) {
    final id = object.catalogId.toLowerCase();
    final isWall = id.startsWith('wall-sconce');
    final isFloor = id.startsWith('floor-lamp');
    final isTable = id.startsWith('table-lamp');
    final isTrack = id.startsWith('track-');
    final isPendant = id.startsWith('pendant-') || id.startsWith('chandelier-');
    final isCeiling = isTrack || isPendant || id.startsWith('ceiling-');

    final localY = importedModel
        ? (isFloor
            ? math.max(0.15, object.heightMm / 1000 * 0.82)
            : isWall
                ? math.max(0.05, object.heightMm / 1000 * 0.50)
                : math.max(0.035, object.heightMm / 1000 * 0.20))
        : (isTable
            ? math.max(0.10, object.heightMm / 1000 * 0.72)
            : math.max(0.02, object.heightMm / 1000 * 0.45));

    final lightNode = Node(name: 'light:${object.id}')
      ..position = vm.Vector3(0, localY, 0);
    final intensity = isWall
        ? 9.0
        : isFloor
            ? 7.0
            : isTable
                ? 7.5
                : isTrack
                    ? 22.0
                    : isPendant
                        ? 28.0
                        : isCeiling
                            ? 20.0
                            : 8.0;
    final range = isWall
        ? 5.0
        : isFloor
            ? 5.5
            : isTable
                ? 4.5
                : 9.5;
    lightNode.addComponent(
      PointLightComponent(
        PointLight(
          color: vm.Vector3(1.0, 0.80, 0.58),
          intensity: intensity,
          range: range,
          falloffExponent: 2.0,
        ),
      ),
    );

    // A soft downward spot gives interior fixtures real contact shadows in
    // Quality/Photo. Performance keeps only the cheap point contribution.
    if (isTable || isCeiling || isPendant) {
      final spot = SpotLight(
        color: vm.Vector3(1.0, 0.78, 0.54),
        intensity: isTable ? 9.0 : 13.0,
        range: isTable ? 4.5 : 7.5,
        falloffExponent: 2.0,
        direction: vm.Vector3(0, -1, 0),
        innerConeAngle: isTable ? 0.42 : 0.50,
        outerConeAngle: isTable ? 1.05 : 1.18,
        castsShadow: widget.quality != ZamerRenderQuality.performance,
        shadowMapResolution:
            widget.quality == ZamerRenderQuality.photo4k ? 1024 : 512,
        shadowNear: 0.055,
        shadowNormalBias: 0.025,
        shadowDepthBias: 0.00015,
        shadowSoftness:
            widget.quality == ZamerRenderQuality.photo4k ? 2.4 : 1.6,
      );
      _shadowSpots.add(spot);
      lightNode.addComponent(SpotLightComponent(spot));
    }

    // Make the light source itself visibly luminous. A point light can brighten
    // nearby surfaces while the chandelier mesh still looks "off", which is
    // exactly what users were seeing with the ceiling fixtures.
    final glowMaterial = _pbr(
      vm.Vector4(1.0, 0.88, 0.62, 1),
      roughness: 0.18,
    )
      ..emissiveFactor = vm.Vector4(1.0, 0.62, 0.28, 1)
      ..emissiveStrength = isWall ? 2.8 : 4.8;
    final glowRadius = isWall
        ? 0.035
        : isTable
            ? 0.028
            : (isTrack ? 0.045 : 0.055);
    final glow = Node(
      name: 'glow:${object.id}',
      mesh: Mesh(
        SphereGeometry(radius: glowRadius, segments: 16, rings: 10),
        glowMaterial,
      ),
    );
    lightNode.add(glow);
    objectNode.add(lightNode);
  }

  Node _fallbackObject(ZamerObjectPlacement object) {
    switch (object.catalogId) {
      case 'rug-textile-2300':
        return _proceduralRug(object);
      case 'curtain-pair-1800':
        return _proceduralCurtain(object);
      case 'table-lamp-soft':
        return _proceduralTableLamp(object);
    }

    final height = math.max(0.05, object.heightMm / 1000);
    final material = _pbr(
      vm.Vector4(0.31, 0.38, 0.45, 1),
      roughness: 0.72,
    );
    return Node(
      name: 'fallback:${object.id}',
      mesh: Mesh(
        CuboidGeometry(
          vm.Vector3(
            math.max(0.05, object.widthMm / 1000),
            height,
            math.max(0.05, object.depthMm / 1000),
          ),
        ),
        material,
      ),
    )..position = vm.Vector3(0, height / 2, 0);
  }

  Node _proceduralRug(ZamerObjectPlacement object) {
    final width = math.max(0.25, object.widthMm / 1000);
    final depth = math.max(0.25, object.depthMm / 1000);
    final height = math.max(0.008, object.heightMm / 1000);
    final material = _pbr(
      vm.Vector4(0.57, 0.52, 0.45, 1),
      roughness: 0.97,
    );
    return Node(
      name: 'procedural-rug:${object.id}',
      mesh: Mesh(
        CuboidGeometry(vm.Vector3(width, height, depth)),
        material,
      ),
    )
      ..position = vm.Vector3(0, height / 2 + 0.002, 0)
      ..castsShadows = false
      ..shadowStatic = true;
  }

  Node _proceduralCurtain(ZamerObjectPlacement object) {
    final width = math.max(0.40, object.widthMm / 1000);
    final depth = math.max(0.05, object.depthMm / 1000);
    final height = math.max(0.50, object.heightMm / 1000);
    const folds = 18;
    final spacing = width / folds;
    final foldWidth = spacing * 1.10;
    final root = Node(name: 'procedural-curtain:${object.id}');
    final materialA = _pbr(
      vm.Vector4(0.34, 0.32, 0.30, 1),
      roughness: 0.95,
    );
    final materialB = _pbr(
      vm.Vector4(0.29, 0.28, 0.27, 1),
      roughness: 0.97,
    );

    for (var i = 0; i < folds; i++) {
      final x = -width / 2 + spacing * (i + 0.5);
      final wave = math.sin(i * math.pi / 2) * depth * 0.18 +
          (i.isEven ? -depth * 0.12 : depth * 0.12);
      root.add(
        Node(
          name: 'curtain-fold:${object.id}:$i',
          mesh: Mesh(
            CuboidGeometry(
              vm.Vector3(foldWidth, height, math.max(0.025, depth * 0.45)),
            ),
            i.isEven ? materialA : materialB,
          ),
        )
          ..position = vm.Vector3(x, height / 2, wave)
          ..shadowStatic = true,
      );
    }
    return root;
  }

  Node _proceduralTableLamp(ZamerObjectPlacement object) {
    final scale = math.max(0.55, object.heightMm / 520);
    final root = Node(name: 'procedural-table-lamp:${object.id}');
    final metal = _pbr(
      vm.Vector4(0.35, 0.24, 0.14, 1),
      roughness: 0.28,
    )..metallicFactor = 0.72;
    final shade = _pbr(
      vm.Vector4(0.075, 0.07, 0.065, 1),
      roughness: 0.78,
    );
    final warm = _pbr(
      vm.Vector4(1.0, 0.83, 0.58, 1),
      roughness: 0.20,
    )
      ..emissiveFactor = vm.Vector4(1.0, 0.56, 0.24, 1)
      ..emissiveStrength = 2.2;

    root.add(
      Node(
        name: 'lamp-base:${object.id}',
        mesh: Mesh(
          CylinderGeometry(
            bottomRadius: 0.085 * scale,
            topRadius: 0.075 * scale,
            height: 0.026 * scale,
            radialSegments: 24,
          ),
          metal,
        ),
      )..position = vm.Vector3(0, 0.013 * scale, 0),
    );
    root.add(
      Node(
        name: 'lamp-stem:${object.id}',
        mesh: Mesh(
          CylinderGeometry(
            bottomRadius: 0.012 * scale,
            topRadius: 0.012 * scale,
            height: 0.24 * scale,
            radialSegments: 16,
          ),
          metal,
        ),
      )..position = vm.Vector3(0, 0.145 * scale, 0),
    );
    root.add(
      Node(
        name: 'lamp-shade:${object.id}',
        mesh: Mesh(
          CylinderGeometry(
            bottomRadius: 0.16 * scale,
            topRadius: 0.105 * scale,
            height: 0.20 * scale,
            radialSegments: 32,
          ),
          shade,
        ),
      )..position = vm.Vector3(0, 0.39 * scale, 0),
    );
    root.add(
      Node(
        name: 'lamp-bulb:${object.id}',
        mesh: Mesh(
          SphereGeometry(radius: 0.034 * scale, segments: 18, rings: 12),
          warm,
        ),
      )..position = vm.Vector3(0, 0.35 * scale, 0),
    );
    return root;
  }

  static void _markStatic(Node root) {
    for (final node in <Node>[root, ...root.children.expand(_walkNodes)]) {
      if (node.mesh != null) node.shadowStatic = true;
    }
  }

  static Iterable<Node> _walkNodes(Node node) sync* {
    yield node;
    for (final child in node.children) {
      yield* _walkNodes(child);
    }
  }

  static double _safeRatio(double wanted, double nativeSize) {
    if (nativeSize.abs() < 0.01) return 1;
    return wanted / nativeSize;
  }

  PhysicallyBasedMaterial _pbr(
    vm.Vector4 color, {
    required double roughness,
    TextureSource? texture,
    TextureSource? normalTexture,
    TextureSource? metallicRoughnessTexture,
    TextureSource? occlusionTexture,
    double normalScale = 1.0,
    double occlusionStrength = 1.0,
  }) {
    final material = PhysicallyBasedMaterial(
      baseColorTexture: texture,
      normalTexture: normalTexture,
      metallicRoughnessTexture: metallicRoughnessTexture,
      occlusionTexture: occlusionTexture,
    )
      ..baseColorFactor = color
      ..metallicFactor = 0
      ..roughnessFactor = roughness
      ..normalScale = normalScale
      ..occlusionStrength = occlusionStrength
      ..doubleSided = false;
    return material;
  }

  double _mx(double xMm, ZamerSceneBounds b) => (xMm - b.centerX) / 1000;
  double _mz(double yMm, ZamerSceneBounds b) => (yMm - b.centerY) / 1000;

  PerspectiveCamera _camera() {
    final g = _geometry;
    if (g == null) return PerspectiveCamera();
    final bounds = g.bounds;

    if (widget.walkMode) {
      final eye = vm.Vector3(
        _mx(widget.walkX, bounds),
        1.65,
        _mz(widget.walkY, bounds),
      );
      final pitch = widget.tilt.clamp(-1.35, 1.20).toDouble();
      final cp = math.cos(pitch);
      final forward = vm.Vector3(
        math.cos(widget.rotation) * cp,
        math.sin(pitch),
        math.sin(widget.rotation) * cp,
      );
      return PerspectiveCamera(
        fovRadiansY:
            widget.walkFovDegrees.clamp(55, 100).toDouble() * math.pi / 180,
        position: eye,
        target: eye + forward * 4,
        up: vm.Vector3(0, 1, 0),
        fovNear: 0.035,
        fovFar: 160,
      );
    }

    final maxDimension = math.max(bounds.widthMm, bounds.depthMm) / 1000;
    final zoom = widget.zoom.clamp(0.15, 10.0).toDouble();
    final distance = math.max(1.1, math.max(3.0, maxDimension * 1.52) / zoom);
    final elevation = widget.tilt.clamp(0.12, 1.49).toDouble();
    final horizontal = math.cos(elevation) * distance;

    // Pan is stored in logical pixels in the editor. Convert it to a stable
    // world displacement proportional to the current view distance.
    final panScale = distance / 900;
    final target = vm.Vector3(
      -widget.pan.dx * panScale,
      math.max(0.35, math.min(1.25, maxDimension * 0.08)),
      -widget.pan.dy * panScale,
    );
    final eye = target +
        vm.Vector3(
          math.cos(widget.rotation) * horizontal,
          math.sin(elevation) * distance,
          math.sin(widget.rotation) * horizontal,
        );

    return PerspectiveCamera(
      fovRadiansY: 52 * math.pi / 180,
      position: eye,
      target: target,
      up: vm.Vector3(0, 1, 0),
      fovNear: 0.045,
      fovFar: math.max(120, distance * 16),
    );
  }

  void _applyCutaway(PerspectiveCamera camera) {
    if (!_ready) return;
    for (final ceiling in _ceilingNodes) {
      ceiling.visible = widget.walkMode;
    }
    if (!widget.cutaway || widget.walkMode) {
      for (final wall in _wallVisuals) {
        wall.node.visible = true;
      }
      return;
    }

    final camera2 = vm.Vector2(camera.position.x, camera.position.z);
    if (camera2.length2 < 0.0001) return;
    final cameraDir = camera2.normalized();
    for (final wall in _wallVisuals) {
      final wallPos = vm.Vector2(wall.x, wall.z);
      final radial = wallPos.length;
      if (radial < 0.08) {
        wall.node.visible = true;
        continue;
      }
      // Hide only the near-facing shell. Unlike the old wall-index heuristic,
      // this remains stable for rotated, concave and multi-room plans.
      final towardCamera = wallPos.normalized().dot(cameraDir);
      wall.node.visible = towardCamera < 0.30;
    }
  }

  /// Creates an actual GPU scene render at the requested pixel dimensions.
  /// The Canvas below is only Flutter's final compositor. Geometry, lighting,
  /// shadows and PBR are rendered by Flutter Scene / Flutter GPU at [width] x
  /// [height], so this is not an upscaled screenshot of the on-screen preview.
  Future<Uint8List> renderPng({
    required int width,
    required int height,
    bool photoQuality = false,
  }) async {
    if (width <= 0 || height <= 0) throw ArgumentError('Некорректный размер');

    final scene = _scene;
    if (scene == null || !_ready) {
      return _renderFallbackPng(width: width, height: height);
    }

    final camera = _camera();
    _applyCutaway(camera);
    if (photoQuality) _configurePhotoLighting();
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final background = ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(0, 0),
          ui.Offset(0, height.toDouble()),
          const <Color>[Color(0xFFEAF1F5), Color(0xFFF7F4EE)],
        );
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        background,
      );
      scene.render(
        camera,
        canvas,
        viewport: ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        pixelRatio: 1,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('GPU-кадр не удалось преобразовать в PNG');
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        image.dispose();
      }
    } finally {
      if (photoQuality) _configureScene();
    }
  }

  Future<Uint8List> _renderFallbackPng({
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final size = ui.Size(width.toDouble(), height.toDouble());
    Floor3DPainter(
      floor: widget.floor,
      rotation: widget.rotation,
      tilt: widget.tilt,
      zoom: widget.zoom,
      cutaway: widget.cutaway,
      pan: widget.pan,
      walkMode: widget.walkMode,
      walkX: widget.walkX,
      walkY: widget.walkY,
    ).paint(canvas, size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Совместимый 3D-кадр не удалось сохранить');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  Widget _fallbackViewport(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: Floor3DPainter(
            floor: widget.floor,
            rotation: widget.rotation,
            tilt: widget.tilt,
            zoom: widget.zoom,
            cutaway: widget.cutaway,
            pan: widget.pan,
            walkMode: widget.walkMode,
            walkX: widget.walkX,
            walkY: widget.walkY,
          ),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Совместимый 3D',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: _initializing ? null : retryGpu,
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('GPU'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _buildGeneration++;
    _scene?.removeAll();
    _modelTemplates.clear();
    _wallVisuals.clear();
    _ceilingNodes.clear();
    _shadowSpots.clear();
    _finishTextures.clear();
    _normalTextures.clear();
    _dataTextures.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) return _fallbackViewport(context);
    if (!_ready) {
      return const ColoredBox(
        color: Color(0xFFF3F5F7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Собираем GPU-сцену…'),
            ],
          ),
        ),
      );
    }

    final scene = _scene;
    if (scene == null) return _fallbackViewport(context);
    final camera = _camera();
    _applyCutaway(camera);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFDDE8EE), Color(0xFFF4F1EA)],
        ),
      ),
      child: SceneView(
        scene,
        camera: camera,
        warmUp: true,
      ),
    );
  }
}

class _WallVisual {
  const _WallVisual({required this.node, required this.x, required this.z});
  final Node node;
  final double x;
  final double z;
}

/// Ear-clipping triangulation for simple room polygons, including concave ones.
/// The returned triangle winding is normalized and floor materials are double
/// sided only when needed, so concave rooms do not disappear at oblique views.
List<int> _triangulate(List<math.Point<double>> polygon) {
  if (polygon.length < 3) return const <int>[];
  final vertices = List<int>.generate(polygon.length, (i) => i);
  final result = <int>[];
  final ccw = _signedArea(polygon) > 0;
  var guard = polygon.length * polygon.length;

  while (vertices.length > 3 && guard-- > 0) {
    var clipped = false;
    for (var i = 0; i < vertices.length; i++) {
      final prev = vertices[(i - 1 + vertices.length) % vertices.length];
      final cur = vertices[i];
      final next = vertices[(i + 1) % vertices.length];
      final a = polygon[prev];
      final b = polygon[cur];
      final c = polygon[next];
      final cross = _cross(a, b, c);
      if (ccw ? cross <= 0.000001 : cross >= -0.000001) continue;

      var contains = false;
      for (final candidate in vertices) {
        if (candidate == prev || candidate == cur || candidate == next) continue;
        if (_pointInTriangle(polygon[candidate], a, b, c)) {
          contains = true;
          break;
        }
      }
      if (contains) continue;

      if (ccw) {
        result.addAll(<int>[prev, cur, next]);
      } else {
        result.addAll(<int>[next, cur, prev]);
      }
      vertices.removeAt(i);
      clipped = true;
      break;
    }
    if (!clipped) break;
  }

  if (vertices.length == 3) {
    if (ccw) {
      result.addAll(vertices);
    } else {
      result.addAll(<int>[vertices[2], vertices[1], vertices[0]]);
    }
  }
  return result;
}

List<math.Point<double>> _clipPolygonToConvex(
  List<math.Point<double>> subject,
  List<math.Point<double>> clip,
) {
  if (subject.isEmpty || clip.length < 3) return const <math.Point<double>>[];
  var output = List<math.Point<double>>.of(subject);
  final clipCcw = _signedArea(clip) >= 0;

  bool inside(
    math.Point<double> p,
    math.Point<double> a,
    math.Point<double> b,
  ) {
    final cross =
        (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
    return clipCcw ? cross >= -0.0001 : cross <= 0.0001;
  }

  math.Point<double> intersection(
    math.Point<double> s,
    math.Point<double> e,
    math.Point<double> a,
    math.Point<double> b,
  ) {
    final dx1 = e.x - s.x;
    final dy1 = e.y - s.y;
    final dx2 = b.x - a.x;
    final dy2 = b.y - a.y;
    final denominator = dx1 * dy2 - dy1 * dx2;
    if (denominator.abs() < 0.0000001) return e;
    final t = ((a.x - s.x) * dy2 - (a.y - s.y) * dx2) / denominator;
    return math.Point<double>(s.x + dx1 * t, s.y + dy1 * t);
  }

  for (var edge = 0; edge < clip.length; edge++) {
    if (output.isEmpty) break;
    final input = output;
    output = <math.Point<double>>[];
    final a = clip[edge];
    final b = clip[(edge + 1) % clip.length];
    var s = input.last;
    for (final e in input) {
      final eInside = inside(e, a, b);
      final sInside = inside(s, a, b);
      if (eInside) {
        if (!sInside) output.add(intersection(s, e, a, b));
        output.add(e);
      } else if (sInside) {
        output.add(intersection(s, e, a, b));
      }
      s = e;
    }
  }
  return output;
}

double _signedArea(List<math.Point<double>> p) {
  var area = 0.0;
  for (var i = 0; i < p.length; i++) {
    final a = p[i];
    final b = p[(i + 1) % p.length];
    area += a.x * b.y - b.x * a.y;
  }
  return area / 2;
}

double _cross(
  math.Point<double> a,
  math.Point<double> b,
  math.Point<double> c,
) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);

bool _pointInTriangle(
  math.Point<double> p,
  math.Point<double> a,
  math.Point<double> b,
  math.Point<double> c,
) {
  final c1 = _cross(a, b, p);
  final c2 = _cross(b, c, p);
  final c3 = _cross(c, a, p);
  final hasNeg = c1 < -0.000001 || c2 < -0.000001 || c3 < -0.000001;
  final hasPos = c1 > 0.000001 || c2 > 0.000001 || c3 > 0.000001;
  return !(hasNeg && hasPos);
}
