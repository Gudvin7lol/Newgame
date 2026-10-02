import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../models/models.dart';
import '../services/generated_pbr_finish_catalog.dart';
import '../services/material_catalog.dart';
import '../widgets/floor_3d_painter.dart';
import 'camera_clip_policy.dart';
import 'ceiling_visibility_policy.dart';
import 'floor_grout_geometry.dart';
import 'cutaway_geometry.dart';
import 'host_wall_visibility.dart';
import 'model_asset_catalog.dart';
import 'model_lod_policy.dart';
import 'photo_render_quality_policy.dart';
import 'photo_export_policy.dart';
import 'photo_render_quality_policy.dart';
import 'scene_fingerprint.dart';
import 'scene_mesh_winding.dart';
import 'zamer_scene_geometry.dart';
import 'wall_device_mount.dart';

enum ZamerPhotoTime { day, sunset, evening, night }

class ZamerPhotoLightingProfile {
  const ZamerPhotoLightingProfile({
    required this.environmentIntensity,
    required this.exposure,
    required this.temperature,
    required this.saturation,
    required this.lightDirection,
    required this.lightColor,
    required this.lightIntensity,
    required this.backgroundTop,
    required this.backgroundBottom,
  });

  final double environmentIntensity;
  final double exposure;
  final double temperature;
  final double saturation;
  final vm.Vector3 lightDirection;
  final vm.Vector3 lightColor;
  final double lightIntensity;
  final Color backgroundTop;
  final Color backgroundBottom;
}

ZamerPhotoLightingProfile zamerPhotoLightingProfile(ZamerPhotoTime time) {
  return switch (time) {
    ZamerPhotoTime.day => ZamerPhotoLightingProfile(
      environmentIntensity: 0.92,
      exposure: 0.94,
      temperature: 0.025,
      saturation: 1.025,
      lightDirection: vm.Vector3(-0.38, -1.0, -0.28),
      lightColor: vm.Vector3(1.0, 0.965, 0.90),
      lightIntensity: 2.15,
      backgroundTop: const Color(0xFFEAF1F5),
      backgroundBottom: const Color(0xFFF7F4EE),
    ),
    ZamerPhotoTime.sunset => ZamerPhotoLightingProfile(
      environmentIntensity: 0.66,
      exposure: 0.90,
      temperature: 0.18,
      saturation: 1.08,
      lightDirection: vm.Vector3(-0.82, -0.46, -0.18),
      lightColor: vm.Vector3(1.0, 0.66, 0.40),
      lightIntensity: 1.72,
      backgroundTop: const Color(0xFF8FA6C3),
      backgroundBottom: const Color(0xFFF1B27E),
    ),
    ZamerPhotoTime.evening => ZamerPhotoLightingProfile(
      environmentIntensity: 0.38,
      exposure: 0.84,
      temperature: -0.07,
      saturation: 1.04,
      lightDirection: vm.Vector3(-0.34, -0.82, -0.46),
      lightColor: vm.Vector3(0.72, 0.82, 1.0),
      lightIntensity: 0.82,
      backgroundTop: const Color(0xFF52627A),
      backgroundBottom: const Color(0xFF9A887D),
    ),
    ZamerPhotoTime.night => ZamerPhotoLightingProfile(
      environmentIntensity: 0.16,
      exposure: 0.76,
      temperature: -0.16,
      saturation: 0.96,
      lightDirection: vm.Vector3(-0.22, -0.74, -0.58),
      lightColor: vm.Vector3(0.46, 0.60, 1.0),
      lightIntensity: 0.34,
      backgroundTop: const Color(0xFF111827),
      backgroundBottom: const Color(0xFF26354D),
    ),
  };
}

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
    this.performanceMode = false,
    this.photoPreview = false,
    this.photoTime = ZamerPhotoTime.day,
    this.photoHdr = true,
    this.cameraFovDegrees = 46,
    this.photoCameraOriginXMm,
    this.photoCameraOriginYMm,
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
  final bool performanceMode;
  final bool photoPreview;
  final ZamerPhotoTime photoTime;
  final bool photoHdr;
  final double cameraFovDegrees;
  final double? photoCameraOriginXMm;
  final double? photoCameraOriginYMm;

  @override
  State<ZamerGpuViewport> createState() => ZamerGpuViewportState();
}

class ZamerGpuViewportState extends State<ZamerGpuViewport>
    with WidgetsBindingObserver {
  Scene? _scene;
  final Map<String, Node> _modelTemplates = <String, Node>{};
  final List<_WallVisual> _wallVisuals = <_WallVisual>[];
  final List<_HostedWallVisual> _hostedWallVisuals = <_HostedWallVisual>[];
  final List<Node> _ceilingNodes = <Node>[];
  final Map<String, Texture2D> _finishTextures = <String, Texture2D>{};
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
  bool _liveRebuildInProgress = false;
  bool _liveRebuildPending = false;

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
    final fingerprint = _floorFingerprint();
    final performanceChanged =
        oldWidget.performanceMode != widget.performanceMode;
    final photoLightingChanged =
        oldWidget.photoPreview != widget.photoPreview ||
        oldWidget.photoTime != widget.photoTime ||
        oldWidget.photoHdr != widget.photoHdr;
    if (performanceChanged || photoLightingChanged) _configureScene();
    if (!identical(oldWidget.floor, widget.floor) ||
        fingerprint != _lastFloorFingerprint ||
        performanceChanged) {
      _lastFloorFingerprint = fingerprint;
      _rebuildSceneAfterUpdate();
    }
  }

  void _scheduleLiveRebuildRetry() {
    if (!mounted) return;
    _retryTimer?.cancel();
    _retryAttempt++;
    final delay = Duration(
      milliseconds: math.min(2500, 250 + _retryAttempt * 250),
    );
    _retryTimer = Timer(delay, () {
      if (!mounted) return;
      _rebuildSceneAfterUpdate();
    });
  }

  Future<void> _rebuildSceneAfterUpdate() async {
    if (_liveRebuildInProgress) {
      _liveRebuildPending = true;
      return;
    }
    _liveRebuildInProgress = true;
    try {
      do {
        _liveRebuildPending = false;
        try {
          await _rebuildScene();
          if (!mounted) return;
          _retryTimer?.cancel();
          _retryAttempt = 0;
          if (!_ready && _loadError != null) {
            _scheduleRetry(immediate: true);
          }
        } catch (error) {
          if (!mounted) return;

          // A staged rebuild never touches the active scene until the new graph
          // is complete. If that preparation fails, keep the last good frame
          // visible and retry the latest floor state with backoff. Falling back
          // to a blank/error viewport here would throw away the very stability
          // benefit of staged scene replacement.
          if (_ready && _scene != null) {
            _liveRebuildPending = false;
            _scheduleLiveRebuildRetry();
            break;
          }

          setState(() {
            _loadError = error;
            _ready = false;
          });
          // There is no usable scene yet, so a full GPU initialization retry is
          // appropriate for first-load/context failures.
          _scheduleRetry(immediate: true);
        }
      } while (mounted && _liveRebuildPending);
    } finally {
      _liveRebuildInProgress = false;
    }
  }

  int _floorFingerprint() => ZamerSceneFingerprint.of(widget.floor);

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
    if (widget.photoPreview) {
      _configurePhotoLighting(exportQuality: false);
      return;
    }
    final performance = widget.performanceMode;
    scene.environmentSettings = EnvironmentSettings(
      toneMapping: ToneMappingMode.pbrNeutral,
      environmentIntensity: performance ? 0.74 : 0.82,
      exposure: 0.94,
      ambientOcclusionEnabled: !performance,
      screenSpaceReflectionsEnabled: false,
      bloomEnabled: false,
      vignetteEnabled: false,
      autoExposureEnabled: false,
    );
    scene.antiAliasingMode = AntiAliasingMode.auto;
    scene.environmentIntensity = performance ? 0.74 : 0.82;
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-0.45, -1.0, -0.32)..normalize(),
      color: vm.Vector3(1.0, 0.97, 0.92),
      intensity: performance ? 1.72 : 1.95,
      castsShadow: !performance,
      cacheStaticShadows: false,
      shadowMapResolution: performance ? 256 : 512,
      shadowMaxDistance: 35,
      shadowSoftness: 0.12,
    );
    // The first GPU version used a fairly expensive mobile AO profile. A
    // lighter half-resolution profile is much more stable on mid-range Android
    // GPUs while keeping enough depth to read the room shape.
    scene.ambientOcclusion
      ..enabled = !performance
      ..halfResolution = true
      ..sampleCount = performance ? 2 : 4
      ..radius = performance ? 0.18 : 0.22
      ..intensity = performance ? 0.42 : 0.62
      ..bias = 0.04;
  }

  void _configurePhotoLighting({required bool exportQuality}) {
    final scene = _scene;
    if (scene == null) return;
    final profile = zamerPhotoLightingProfile(widget.photoTime);
    final hdr = widget.photoHdr;
    final nightBoost = widget.photoTime == ZamerPhotoTime.night ? 0.16 : 0.0;
    scene.environmentSettings = EnvironmentSettings(
      toneMapping: ToneMappingMode.pbrNeutral,
      environmentIntensity: profile.environmentIntensity,
      exposure: profile.exposure,
      colorGradingEnabled: true,
      brightness: 1.0,
      contrast: hdr ? 1.04 : 1.015,
      saturation: profile.saturation,
      temperature: profile.temperature,
      ambientOcclusionEnabled: true,
      ambientOcclusionRadius: exportQuality ? 0.28 : 0.22,
      ambientOcclusionIntensity: exportQuality ? 0.72 : 0.56,
      ambientOcclusionBias: 0.035,
      ambientOcclusionSampleCount: exportQuality ? 12 : 4,
      ambientOcclusionHalfResolution: !exportQuality,
      screenSpaceReflectionsEnabled: hdr,
      screenSpaceReflectionsIntensity: hdr ? 0.38 : 0.20,
      screenSpaceReflectionsMaxDistance: 18,
      screenSpaceReflectionsThickness: 0.42,
      screenSpaceReflectionsStride: 3,
      screenSpaceReflectionsMaxSteps: exportQuality ? 96 : 48,
      screenSpaceReflectionsBlur: 0.18,
      screenSpaceReflectionsResolutionScale: exportQuality ? 1.0 : 0.5,
      bloomEnabled: hdr || widget.photoTime != ZamerPhotoTime.day,
      bloomThreshold: widget.photoTime == ZamerPhotoTime.night ? 0.82 : 1.08,
      bloomIntensity: widget.photoTime == ZamerPhotoTime.night ? 0.10 : 0.05,
      bloomScatter: 0.62,
      vignetteEnabled: true,
      vignetteIntensity: widget.photoTime == ZamerPhotoTime.night ? 0.13 : 0.08,
      vignetteRadius: 0.86,
      vignetteSmoothness: 0.55,
      autoExposureEnabled: hdr,
      autoExposureStrength: hdr ? 0.30 : 0.0,
      autoExposureCompensation: -0.20 + nightBoost,
      autoExposureMinEv: widget.photoTime == ZamerPhotoTime.night ? -2.0 : -1.2,
      autoExposureMaxEv: widget.photoTime == ZamerPhotoTime.night ? 2.2 : 1.2,
    );
    scene.antiAliasingMode = AntiAliasingMode.auto;
    scene.environmentIntensity = profile.environmentIntensity;
    final direction = profile.lightDirection.clone()..normalize();
    scene.directionalLight = DirectionalLight(
      direction: direction,
      color: profile.lightColor,
      intensity: profile.lightIntensity,
      castsShadow: true,
      cacheStaticShadows: false,
      shadowMapResolution: exportQuality ? 2048 : 1024,
      shadowMaxDistance: 45,
      shadowSoftness: widget.photoTime == ZamerPhotoTime.sunset ? 0.42 : 0.30,
    );
    scene.ambientOcclusion
      ..enabled = true
      ..halfResolution = !exportQuality
      ..sampleCount = exportQuality ? 8 : 4
      ..radius = exportQuality ? 0.30 : 0.22
      ..intensity = exportQuality ? 0.82 : 0.62
      ..bias = 0.035;
  }

  Future<void> _loadFinishTextures() async {
    for (final preset in MaterialCatalog.presets) {
      final asset = preset.textureAsset;
      final generatedPbr = GeneratedPbrFinishCatalog.byId(preset.id);
      final candidates = <String>{
        if (asset != null) asset,
        if (generatedPbr != null) generatedPbr.normalAsset,
        if (generatedPbr != null) generatedPbr.metallicRoughnessAsset,
        if (asset != null && preset.pattern == 'wood' && asset.endsWith('.png'))
          asset.replaceFirst('.png', '_half.png'),
        if (asset != null && preset.pattern == 'wood' && asset.endsWith('.png'))
          asset.replaceFirst('.png', '_third.png'),
      };
      for (final candidate in candidates) {
        if (_finishTextures.containsKey(candidate)) continue;
        try {
          _finishTextures[candidate] = await Texture2D.fromAsset(candidate);
        } catch (_) {
          // Decorative textures are optional; a single missing asset must not
          // make the complete 3D room fail to initialise.
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

  Future<void> _rebuildScene({bool photoQuality = false}) async {
    final generation = ++_buildGeneration;
    final keepCurrentScene = _ready && _loadError == null;
    if (mounted && !keepCurrentScene) {
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
    final nextNodes = <Node>[];
    final nextWallVisuals = <_WallVisual>[];
    final nextHostedWallVisuals = <_HostedWallVisual>[];
    final nextCeilingNodes = <Node>[];
    final floorMaterialCache = <String, PhysicallyBasedMaterial>{};
    final activeModelPaths = <String>{};

    for (final surface in geometry.floors) {
      final node = _buildFloorNode(
        surface,
        geometry.bounds,
        floorMaterialCache,
      );
      if (node != null) nextNodes.add(node);
      final ceiling = _buildCeilingNode(surface, geometry.bounds);
      if (ceiling != null) {
        nextCeilingNodes.add(ceiling);
        nextNodes.add(ceiling);
      }
    }

    for (final wall in geometry.walls) {
      final node = _buildWallNode(wall, geometry.bounds);
      nextNodes.add(node);
      final centerX = _mx(wall.centerXMm, geometry.bounds);
      final centerZ = _mz(wall.centerYMm, geometry.bounds);
      final halfLengthM = wall.lengthMm / 2000;
      final segmentDx = math.cos(wall.angleRad) * halfLengthM;
      final segmentDz = math.sin(wall.angleRad) * halfLengthM;
      nextWallVisuals.add(
        _WallVisual(
          node: node,
          wallId: wall.wallId,
          startX: centerX - segmentDx,
          startZ: centerZ - segmentDz,
          endX: centerX + segmentDx,
          endZ: centerZ + segmentDz,
          halfThickness: wall.thicknessMm / 2000,
        ),
      );
    }

    for (final opening in geometry.openings) {
      final node = _buildOpeningNode(opening, geometry.bounds);
      nextNodes.add(node);
      nextHostedWallVisuals.add(
        _HostedWallVisual(
          node: node,
          wallId: opening.wallId,
          x: _mx(opening.xMm, geometry.bounds),
          z: _mz(opening.yMm, geometry.bounds),
        ),
      );
    }
    for (final point in geometry.electrical) {
      final node = _buildElectricalNode(point, geometry.bounds);
      nextNodes.add(node);
      nextHostedWallVisuals.add(
        _HostedWallVisual(
          node: node,
          wallId: point.wallId,
          x: _mx(point.xMm, geometry.bounds),
          z: _mz(point.yMm, geometry.bounds),
        ),
      );
    }

    for (final object in geometry.objects) {
      if (generation != _buildGeneration) return;
      final node = await _buildObjectNode(
        object,
        geometry.bounds,
        visibleObjectCount: geometry.objects.length,
        photoQuality: photoQuality,
        activeModelPaths: activeModelPaths,
      );
      if (generation != _buildGeneration) return;
      nextNodes.add(node);
    }

    if (!mounted || generation != _buildGeneration) return;

    // Keep the last valid frame visible while GLBs and materials are prepared.
    // Only touch the active Scene after the replacement graph is complete, so
    // editing a plan never produces an empty or half-populated 3D viewport.
    scene.removeAll();
    for (final node in nextNodes) {
      scene.add(node);
    }
    _geometry = geometry;
    _wallVisuals
      ..clear()
      ..addAll(nextWallVisuals);
    _hostedWallVisuals
      ..clear()
      ..addAll(nextHostedWallVisuals);
    _ceilingNodes
      ..clear()
      ..addAll(nextCeilingNodes);

    _modelTemplates.removeWhere((path, _) => !activeModelPaths.contains(path));
    setState(() {
      _loadError = null;
      _ready = true;
    });
  }

  Node? _buildFloorNode(
    ZamerFloorSurface surface,
    ZamerSceneBounds bounds,
    Map<String, PhysicallyBasedMaterial> materialCache,
  ) {
    if (surface.polygonMm.length < 3) return null;
    final indices = _triangulate(surface.polygonMm);
    if (indices.isEmpty) return null;

    final uvScale = _floorUvScaleMm(surface);
    final isTile =
        surface.materialMode.toLowerCase().contains('tile') ||
        MaterialCatalog.byId(surface.materialId).pattern == 'tile';
    final effectiveDirection = isTile
        ? surface.directionDeg + (surface.tilePattern == 'diagonal' ? 45 : 0)
        : surface.directionDeg;
    final angle = effectiveDirection * math.pi / 180;
    final ca = math.cos(angle), sa = math.sin(angle);
    final offX = isTile ? surface.tileOffsetXMm : surface.laminateOffsetXMm;
    final offY = isTile ? surface.tileOffsetYMm : surface.laminateOffsetYMm;
    final builder = GeometryBuilder(deduplicate: false)
      ..normal(vm.Vector3(0, 1, 0));
    for (final point in surface.polygonMm) {
      final dx = point.x - surface.anchorXMm;
      final dy = point.y - surface.anchorYMm;
      // 2D places a seam at n*module + offset. Therefore the texture-space
      // coordinate must subtract that offset. The old +offset made the GPU
      // layout move in the opposite direction from the 2D editor.
      final rx = dx * ca + dy * sa - offX;
      final ry = -dx * sa + dy * ca - offY;
      builder
        ..texCoord(vm.Vector2(rx / uvScale.$1, ry / uvScale.$2))
        ..addVertex(
          vm.Vector3(
            _mx(point.x, bounds),
            zamerFloorSurfaceYM,
            _mz(point.y, bounds),
          ),
        );
    }
    final floorIndices = floorFacingTriangleIndices(indices);
    for (var i = 0; i < floorIndices.length; i += 3) {
      builder.addTriangle(
        floorIndices[i],
        floorIndices[i + 1],
        floorIndices[i + 2],
      );
    }

    final key =
        '${surface.materialMode}:${surface.materialId}:${surface.laminatePattern}:${surface.laminateOffsetMode}:${surface.tilePattern}';
    final material = materialCache.putIfAbsent(
      key,
      () => _floorMaterial(surface),
    );
    final root = Node(name: 'floor-root:${surface.roomKey}');
    root.add(
      Node(
          name: 'floor:${surface.roomKey}',
          mesh: Mesh(builder.build(), material),
        )
        ..castsShadows = false
        ..shadowStatic = true,
    );
    if (isTile && surface.groutMm > 0) {
      final grout = _buildFloorGroutNode(surface, bounds, effectiveDirection);
      if (grout != null) root.add(grout);
    }
    return root;
  }

  Node? _buildFloorGroutNode(
    ZamerFloorSurface surface,
    ZamerSceneBounds bounds,
    double effectiveDirection,
  ) {
    final quads = buildFloorTileGroutQuads(
      polygonMm: surface.polygonMm,
      anchorXMm: surface.anchorXMm,
      anchorYMm: surface.anchorYMm,
      directionDeg: effectiveDirection,
      tileWidthMm: surface.tileWidthMm,
      tileHeightMm: surface.tileHeightMm,
      offsetXMm: surface.tileOffsetXMm,
      offsetYMm: surface.tileOffsetYMm,
      groutMm: surface.groutMm,
      pattern: surface.tilePattern,
    );
    if (quads.isEmpty) return null;

    final builder = GeometryBuilder(deduplicate: false)
      ..normal(vm.Vector3(0, 1, 0));
    var vertex = 0;
    for (final quad in quads) {
      if (quad.pointsMm.length != 4) continue;
      for (final point in quad.pointsMm) {
        builder
          ..texCoord(vm.Vector2.zero())
          ..addVertex(
            vm.Vector3(
              _mx(point.x, bounds),
              zamerFloorGroutYM,
              _mz(point.y, bounds),
            ),
          );
      }
      // XY plan -> XZ scene flips handedness, so reverse the triangle order
      // to keep the physical grout face pointing upward.
      builder
        ..addTriangle(vertex, vertex + 2, vertex + 1)
        ..addTriangle(vertex, vertex + 3, vertex + 2);
      vertex += 4;
    }
    if (vertex == 0) return null;
    final material = _pbr(vm.Vector4(0.68, 0.69, 0.68, 1), roughness: 0.94)
      ..doubleSided = false;
    return Node(
        name: 'floor-grout:${surface.roomKey}',
        mesh: Mesh(builder.build(), material),
      )
      ..castsShadows = false
      ..shadowStatic = true;
  }

  PhysicallyBasedMaterial _floorMaterial(ZamerFloorSurface surface) {
    final preset = MaterialCatalog.byId(surface.materialId);
    final mode = surface.materialMode.toLowerCase();
    final texture = _textureForFloorSurface(surface, preset);
    final roughness =
        preset.roughness ??
        (preset.pattern == 'tile'
            ? 0.40
            : preset.pattern == 'wood'
            ? 0.54
            : preset.pattern == 'concrete'
            ? 0.86
            : 0.70);
    final source = _vectorColor(preset.color);
    final tint = texture == null
        ? source
        : vm.Vector4(
            0.52 + source.x * 0.48,
            0.52 + source.y * 0.48,
            0.52 + source.z * 0.48,
            1,
          );
    final material = _pbr(tint, roughness: roughness, texture: texture)
      ..doubleSided = false;
    _applyGeneratedPbr(material, preset);
    return material;
  }

  TextureSource? _textureForFloorSurface(
    ZamerFloorSurface surface,
    VisualMaterialPreset preset,
  ) {
    final asset = preset.textureAsset;
    if (asset != null &&
        preset.pattern == 'wood' &&
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
    return _textureForPreset(
      preset,
      fallbackMode: surface.materialMode.toLowerCase(),
    );
  }

  (double, double) _floorUvScaleMm(ZamerFloorSurface surface) {
    final preset = MaterialCatalog.byId(surface.materialId);
    final mode = surface.materialMode.toLowerCase();
    final generatedPbr = GeneratedPbrFinishCatalog.byId(preset.id);
    if (preset.pattern == 'tile' ||
        mode.contains('tile') ||
        mode.contains('плит')) {
      return (
        math.max(60.0, surface.tileWidthMm),
        math.max(60.0, surface.tileHeightMm),
      );
    }
    if (preset.pattern == 'concrete' || mode.contains('бетон')) {
      return const (1000.0, 1000.0);
    }
    if (preset.pattern != 'wood' && generatedPbr != null) {
      final repeatMm = math.max(50.0, generatedPbr.realWorldTileMm);
      return (repeatMm, repeatMm);
    }
    if (surface.laminatePattern == 'herringbone') {
      return (
        math.max(240.0, surface.plankLengthMm),
        math.max(80.0, surface.plankWidthMm),
      );
    }
    final repeatX = surface.laminateOffsetMode == 'third'
        ? 3.0
        : surface.laminateOffsetMode == 'half'
        ? 2.0
        : 1.0;
    final repeatY = surface.laminateOffsetMode == 'third'
        ? 3.0
        : surface.laminateOffsetMode == 'half'
        ? 2.0
        : 1.0;
    return (
      math.max(240.0, surface.plankLengthMm) * repeatX,
      math.max(80.0, surface.plankWidthMm) * repeatY,
    );
  }

  PhysicallyBasedMaterial _wallCoreMaterial() =>
      _pbr(vm.Vector4(0.78, 0.79, 0.79, 1), roughness: 0.92)
        ..doubleSided = true;

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
      roughness:
          preset.roughness ??
          (finish.tileEnabled
              ? 0.40
              : (preset.pattern == 'concrete' ? 0.90 : 0.82)),
      texture: texture,
    )..doubleSided = false;
    TextureTransform? textureTransform;
    if (finish.tileEnabled && texture != null) {
      final sourceTileW = math.max(20.0, finish.tileWidthMm);
      final sourceTileH = math.max(20.0, finish.tileHeightMm);
      final tileW = finish.tileRotated ? sourceTileH : sourceTileW;
      final tileH = finish.tileRotated ? sourceTileW : sourceTileH;
      final repeatX = math.max(0.001, wall.lengthMm / tileW);
      final repeatY = math.max(0.001, wall.heightMm / tileH);
      final wallU = (wall.textureStartMm + finish.tileOffsetXMm) / tileW;
      final wallV = (wall.bottomMm - finish.tileOffsetYMm) / tileH;
      textureTransform = TextureTransform(
        scale: vm.Vector2(
          (finish.tileMirrored ? -1.0 : 1.0) * repeatX,
          repeatY,
        ),
        offset: vm.Vector2(finish.tileMirrored ? 1.0 - wallU : wallU, wallV),
        rotation: finish.tileRotated ? math.pi / 2 : 0,
      );
    } else if (texture != null) {
      final generatedPbr = GeneratedPbrFinishCatalog.byId(preset.id);
      if (generatedPbr != null) {
        final repeatMm = math.max(50.0, generatedPbr.realWorldTileMm);
        textureTransform = TextureTransform(
          scale: vm.Vector2(
            math.max(0.001, wall.lengthMm / repeatMm),
            math.max(0.001, wall.heightMm / repeatMm),
          ),
          offset: vm.Vector2(
            wall.textureStartMm / repeatMm,
            wall.bottomMm / repeatMm,
          ),
        );
      }
    }
    _applyGeneratedPbr(material, preset, transform: textureTransform);
    return material;
  }

  void _applyGeneratedPbr(
    PhysicallyBasedMaterial material,
    VisualMaterialPreset preset, {
    TextureTransform? transform,
  }) {
    if (transform != null) {
      material.baseColorTextureTransform = transform;
    }
    final generatedPbr = GeneratedPbrFinishCatalog.byId(preset.id);
    if (generatedPbr == null) return;

    final normal = _finishTextures[generatedPbr.normalAsset];
    if (normal != null) {
      material
        ..normalTexture = normal
        ..normalScale = generatedPbr.normalScale;
      if (transform != null) material.normalTextureTransform = transform;
    }

    final metallicRoughness =
        _finishTextures[generatedPbr.metallicRoughnessAsset];
    if (metallicRoughness != null) {
      material.metallicRoughnessTexture = metallicRoughness;
      if (transform != null) {
        material.metallicRoughnessTextureTransform = transform;
      }
    }
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

  vm.Vector4 _vectorColor(Color color) =>
      vm.Vector4(color.r, color.g, color.b, color.a);

  Node? _buildCeilingNode(ZamerFloorSurface surface, ZamerSceneBounds bounds) {
    if (surface.polygonMm.length < 3) return null;
    final indices = _triangulate(surface.polygonMm);
    if (indices.isEmpty) return null;
    final builder = GeometryBuilder(deduplicate: false)
      ..normal(vm.Vector3(0, -1, 0));
    for (final point in surface.polygonMm) {
      builder
        ..texCoord(vm.Vector2(point.x / 1000, point.y / 1000))
        ..addVertex(
          vm.Vector3(
            _mx(point.x, bounds),
            surface.ceilingHeightMm / 1000,
            _mz(point.y, bounds),
          ),
        );
    }
    // The original plan winding maps to -Y in XZ, which is exactly the
    // visible underside of the ceiling in Walk Mode. Do not reverse it.
    for (var i = 0; i < indices.length; i += 3) {
      builder.addTriangle(indices[i], indices[i + 1], indices[i + 2]);
    }
    final material = _pbr(vm.Vector4(0.94, 0.94, 0.92, 1), roughness: 0.88)
      ..doubleSided = false;
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
    final key =
        '${nearest.materialMode}:${nearest.materialId}:${nearest.laminatePattern}:${nearest.laminateOffsetMode}:${nearest.tilePattern}:under-wall';
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
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), -wall.angleRad)
      ..castsShadows = false
      ..shadowStatic = true;
    return node;
  }

  Node _buildWallNode(ZamerWallPiece wall, ZamerSceneBounds bounds) {
    final root = Node(name: 'wall:${wall.wallId}')
      ..position = vm.Vector3(
        _mx(wall.centerXMm, bounds),
        0,
        _mz(wall.centerYMm, bounds),
      )
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), -wall.angleRad);

    final core =
        Node(
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
      final layer =
          Node(
              name:
                  'wall-finish:${wall.wallId}:${finish.roomKey}:${finish.sideSign}',
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
      bool castsShadows = true,
    }) {
      final node =
          Node(
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
            ..castsShadows = castsShadows
            ..shadowStatic = castsShadows;
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
      final glass = _pbr(vm.Vector4(0.72, 0.88, 0.96, 0.28), roughness: 0.10)
        ..alphaMode = AlphaMode.blend
        ..doubleSided = true;
      root.add(
        bar(
          name: 'window-glass',
          x: 0,
          y: bottomM + heightM / 2,
          width: math.max(0.08, widthM - frameBarM * 2.2),
          height: math.max(0.08, heightM - frameBarM * 2.2),
          depth: 0.008,
          material: glass,
          castsShadows: false,
        ),
      );
    } else {
      final leftHinge =
          opening.doorSwing == DoorSwing.leftIn ||
          opening.doorSwing == DoorSwing.leftOut;
      final opensIn =
          opening.doorSwing == DoorSwing.leftIn ||
          opening.doorSwing == DoorSwing.rightIn;
      final hingeSign = leftHinge ? -1.0 : 1.0;
      final swingSign = (opensIn ? 1.0 : -1.0) * hingeSign;
      final leafWidth = math.max(0.12, widthM - frameBarM * 1.5);
      final leafHeight = math.max(0.18, heightM - frameBarM);
      final hinge = Node(name: 'door-hinge')
        ..position = vm.Vector3(hingeSign * (widthM / 2 - frameBarM), 0, 0)
        ..rotation = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          swingSign * 32 * math.pi / 180,
        );
      final leafMaterial = _pbr(
        vm.Vector4(0.63, 0.43, 0.26, 1),
        roughness: 0.52,
      );
      final trimMaterial = _pbr(
        vm.Vector4(0.48, 0.30, 0.17, 1),
        roughness: 0.46,
      );
      final hardwareMaterial = _pbr(
        vm.Vector4(0.56, 0.58, 0.58, 1),
        roughness: 0.22,
      )..metallicFactor = 0.86;
      final leafRoot = Node(name: 'door-leaf-root')
        ..position = vm.Vector3(-hingeSign * leafWidth / 2, leafHeight / 2, 0);
      leafRoot.add(
        Node(
          name: 'door-leaf',
          mesh: Mesh(
            CuboidGeometry(vm.Vector3(leafWidth, leafHeight, 0.042)),
            leafMaterial,
          ),
        )..shadowStatic = true,
      );

      final panelWidth = math.max(0.10, leafWidth - 0.20);
      final upperPanelHeight = math.max(0.20, leafHeight * 0.38);
      final lowerPanelHeight = math.max(0.18, leafHeight * 0.30);
      final upperPanelY = leafHeight * 0.17;
      final lowerPanelY = -leafHeight * 0.23;
      for (final faceSign in const [-1.0, 1.0]) {
        leafRoot
          ..add(
            Node(
              name: faceSign > 0
                  ? 'door-panel-upper-front'
                  : 'door-panel-upper-back',
              mesh: Mesh(
                CuboidGeometry(vm.Vector3(panelWidth, upperPanelHeight, 0.010)),
                trimMaterial,
              ),
            )..position = vm.Vector3(0, upperPanelY, faceSign * 0.025),
          )
          ..add(
            Node(
              name: faceSign > 0
                  ? 'door-panel-lower-front'
                  : 'door-panel-lower-back',
              mesh: Mesh(
                CuboidGeometry(vm.Vector3(panelWidth, lowerPanelHeight, 0.010)),
                trimMaterial,
              ),
            )..position = vm.Vector3(0, lowerPanelY, faceSign * 0.025),
          );
      }

      final latchX = -hingeSign * math.max(0.04, leafWidth / 2 - 0.105);
      final handleY = math.min(0.98, leafHeight * 0.48) - leafHeight / 2;
      for (final faceSign in const [-1.0, 1.0]) {
        leafRoot.add(
          Node(
            name: faceSign > 0 ? 'door-handle-front' : 'door-handle-back',
            mesh: Mesh(
              SphereGeometry(radius: 0.028, segments: 14, rings: 9),
              hardwareMaterial,
            ),
          )..position = vm.Vector3(latchX, handleY, faceSign * 0.052),
        );
        leafRoot.add(
          Node(
              name: faceSign > 0 ? 'door-lever-front' : 'door-lever-back',
              mesh: Mesh(
                CuboidGeometry(vm.Vector3(0.105, 0.018, 0.018)),
                hardwareMaterial,
              ),
            )
            ..position = vm.Vector3(
              latchX - hingeSign * 0.045,
              handleY,
              faceSign * 0.060,
            ),
        );
      }

      final hingePlateX = hingeSign * math.max(0.02, leafWidth / 2 - 0.014);
      for (final hingeY in <double>[-leafHeight * 0.31, leafHeight * 0.31]) {
        leafRoot.add(
          Node(
            name: 'door-hinge-plate',
            mesh: Mesh(
              CuboidGeometry(vm.Vector3(0.026, 0.11, 0.050)),
              hardwareMaterial,
            ),
          )..position = vm.Vector3(hingePlateX, hingeY, 0),
        );
      }

      hinge.add(leafRoot);
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
    final depthM = isPanel ? 0.055 : (isWallLight ? 0.075 : 0.018);
    final offsetMm = zamerWallDeviceCenterOffsetMm(
      wallThicknessMm: point.wallThicknessMm,
      deviceDepthM: depthM,
    );
    final x = point.xMm + nx * offsetMm * point.wallSide;
    final y = point.yMm + ny * offsetMm * point.wallSide;
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
    ZamerSceneBounds bounds, {
    required int visibleObjectCount,
    bool photoQuality = false,
    required Set<String> activeModelPaths,
  }) async {
    final asset = ZamerModelAssetCatalog.byId(object.catalogId);
    final root = Node(name: 'object:${object.id}:${object.catalogId}');
    var importedModel = false;

    if (asset == null) {
      root.add(_fallbackObject(object));
    } else {
      try {
        final modelPath = ZamerModelLodPolicy.pathFor(
          asset: asset,
          visibleObjectCount: visibleObjectCount,
          photoQuality: photoQuality,
          walkMode: widget.walkMode,
          performanceMode: widget.performanceMode,
        );
        activeModelPaths.add(modelPath);
        final template = _modelTemplates[modelPath] ??= await Node.fromGlbAsset(
          modelPath,
        );
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
        -object.rotationRad + (asset?.yawCorrectionRad ?? 0),
      );
    if (object.type == PlanObjectType.lighting) {
      _attachLightEmitter(
        root,
        object,
        importedModel: importedModel,
        photoQuality: photoQuality,
      );
    }
    _markStatic(root);
    return root;
  }

  void _attachLightEmitter(
    Node objectNode,
    ZamerObjectPlacement object, {
    required bool importedModel,
    required bool photoQuality,
  }) {
    final id = object.catalogId.toLowerCase();
    final isWall = id.startsWith('wall-sconce');
    final isFloor = id.startsWith('floor-lamp');
    final isTrack = id.startsWith('track-');
    final isPendant = id.startsWith('pendant-') || id.startsWith('chandelier-');
    final isCeiling = isTrack || isPendant || id.startsWith('ceiling-');

    final localY = importedModel
        ? (isFloor
              ? math.max(0.15, object.heightMm / 1000 * 0.82)
              : isWall
              ? math.max(0.05, object.heightMm / 1000 * 0.50)
              : math.max(0.035, object.heightMm / 1000 * 0.20))
        : math.max(0.02, object.heightMm / 1000 * 0.45);

    final lightNode = Node(name: 'light:${object.id}')
      ..position = vm.Vector3(0, localY, 0);
    final intensity = isWall
        ? 5.0
        : isFloor
        ? 4.5
        : isTrack
        ? 10.0
        : isPendant
        ? 12.0
        : isCeiling
        ? 9.0
        : 5.0;
    final range = isWall
        ? 3.8
        : isFloor
        ? 4.5
        : 6.0;
    if (ZamerPhotoRenderQualityPolicy.useLocalLights(
      photoQuality: photoQuality,
      performanceMode: widget.performanceMode,
    )) {
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
    }

    // Make the light source itself visibly luminous. A point light can brighten
    // nearby surfaces while the chandelier mesh still looks "off", which is
    // exactly what users were seeing with the ceiling fixtures.
    final glowMaterial = _pbr(vm.Vector4(1.0, 0.88, 0.62, 1), roughness: 0.18)
      ..emissiveFactor = vm.Vector4(1.0, 0.62, 0.28, 1)
      ..emissiveStrength = isWall ? 1.8 : 2.6;
    final glowRadius = isWall ? 0.035 : (isTrack ? 0.045 : 0.055);
    final glow = Node(
      name: 'glow:${object.id}',
      mesh: Mesh(
        SphereGeometry(
          radius: glowRadius,
          segments: ZamerPhotoRenderQualityPolicy.glowSegments(
            photoQuality: photoQuality,
            performanceMode: widget.performanceMode,
          ),
          rings: ZamerPhotoRenderQualityPolicy.glowRings(
            photoQuality: photoQuality,
            performanceMode: widget.performanceMode,
          ),
        ),
        glowMaterial,
      ),
    );
    lightNode.add(glow);
    objectNode.add(lightNode);
  }

  Node _fallbackObject(ZamerObjectPlacement object) {
    final material = _pbr(vm.Vector4(0.31, 0.38, 0.45, 1), roughness: 0.72);
    final node = Node(
      name: 'fallback:${object.id}',
      mesh: Mesh(
        CuboidGeometry(
          vm.Vector3(
            math.max(0.05, object.widthMm / 1000),
            math.max(0.05, object.heightMm / 1000),
            math.max(0.05, object.depthMm / 1000),
          ),
        ),
        material,
      ),
    );
    return node;
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
  }) {
    final material = PhysicallyBasedMaterial(baseColorTexture: texture)
      ..baseColorFactor = color
      ..metallicFactor = 0
      ..roughnessFactor = roughness
      ..doubleSided = false;
    return material;
  }

  double _mx(double xMm, ZamerSceneBounds b) => (xMm - b.centerX) / 1000;
  double _mz(double yMm, ZamerSceneBounds b) => (yMm - b.centerY) / 1000;

  PerspectiveCamera _camera() {
    final g = _geometry;
    if (g == null) return PerspectiveCamera();
    final bounds = g.bounds;

    final photoOriginXMm = widget.photoCameraOriginXMm;
    final photoOriginYMm = widget.photoCameraOriginYMm;
    if (widget.photoPreview &&
        photoOriginXMm != null &&
        photoOriginYMm != null) {
      final eye = vm.Vector3(
        _mx(photoOriginXMm, bounds),
        1.65,
        _mz(photoOriginYMm, bounds),
      );
      final pitch = widget.tilt.clamp(-0.7, 0.7).toDouble();
      final cp = math.cos(pitch);
      final forward = vm.Vector3(
        math.cos(widget.rotation) * cp,
        math.sin(pitch),
        math.sin(widget.rotation) * cp,
      );
      final fovDegrees = widget.cameraFovDegrees.clamp(18.0, 90.0).toDouble();
      return PerspectiveCamera(
        fovRadiansY: fovDegrees * math.pi / 180,
        position: eye,
        target: eye + forward * 4,
        up: vm.Vector3(0, 1, 0),
        fovNear: ZamerCameraClipPolicy.near(walkMode: true),
        fovFar: ZamerCameraClipPolicy.walkFarM,
      );
    }

    if (widget.walkMode) {
      final eye = vm.Vector3(
        _mx(widget.walkX, bounds),
        1.65,
        _mz(widget.walkY, bounds),
      );
      final pitch = widget.tilt.clamp(-0.7, 0.7).toDouble();
      final cp = math.cos(pitch);
      final forward = vm.Vector3(
        math.cos(widget.rotation) * cp,
        math.sin(pitch),
        math.sin(widget.rotation) * cp,
      );
      return PerspectiveCamera(
        fovRadiansY: 64 * math.pi / 180,
        position: eye,
        target: eye + forward * 4,
        up: vm.Vector3(0, 1, 0),
        fovNear: ZamerCameraClipPolicy.near(walkMode: true),
        fovFar: ZamerCameraClipPolicy.walkFarM,
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
    final eye =
        target +
        vm.Vector3(
          math.cos(widget.rotation) * horizontal,
          math.sin(elevation) * distance,
          math.sin(widget.rotation) * horizontal,
        );

    final fovDegrees = widget.cameraFovDegrees.clamp(18.0, 90.0).toDouble();
    return PerspectiveCamera(
      fovRadiansY: fovDegrees * math.pi / 180,
      position: eye,
      target: target,
      up: vm.Vector3(0, 1, 0),
      fovNear: ZamerCameraClipPolicy.near(walkMode: false),
      fovFar: math.max(120, distance * 16),
    );
  }

  void _applyCutaway(PerspectiveCamera camera) {
    if (!_ready) return;
    for (final ceiling in _ceilingNodes) {
      ceiling.visible = ZamerCeilingVisibilityPolicy.visible(
        walkMode: widget.walkMode,
        photoPreview: widget.photoPreview,
      );
    }
    if (!widget.cutaway || widget.walkMode || widget.tilt >= 1.32) {
      for (final wall in _wallVisuals) {
        wall.node.visible = true;
      }
      for (final hosted in _hostedWallVisuals) {
        hosted.node.visible = true;
      }
      return;
    }

    final bounds = _geometry?.bounds;
    if (bounds == null) return;
    final camera2 = vm.Vector2(camera.position.x, camera.position.z);

    // Cutaway must use the same panned orbit target as the camera. The old
    // implementation compared every wall with world origin (0, 0), so after
    // panning or in multi-room plans it could hide an unrelated wall on the
    // opposite side of the project.
    final maxDimension = math.max(bounds.widthMm, bounds.depthMm) / 1000;
    final zoom = widget.zoom.clamp(0.15, 10.0).toDouble();
    final distance = math.max(1.1, math.max(3.0, maxDimension * 1.52) / zoom);
    final panScale = distance / 900;
    final target2 = vm.Vector2(
      -widget.pan.dx * panScale,
      -widget.pan.dy * panScale,
    );
    final cameraFromTarget = camera2 - target2;
    if (cameraFromTarget.length2 < 0.0001) return;

    final cameraDistance = cameraFromTarget.length;
    final halfFov =
        widget.cameraFovDegrees.clamp(18.0, 90.0).toDouble() * math.pi / 360;
    final corridorHalfWidth = math.max(
      0.75,
      math.tan(halfFov) * cameraDistance * 1.15,
    );

    final targetPoint = math.Point<double>(target2.x, target2.y);
    final cameraPoint = math.Point<double>(camera2.x, camera2.y);
    for (final wall in _wallVisuals) {
      final occludesTarget = zamerWallSegmentOccludesCutaway(
        start: math.Point<double>(wall.startX, wall.startZ),
        end: math.Point<double>(wall.endX, wall.endZ),
        target: targetPoint,
        camera: cameraPoint,
        corridorHalfWidth: corridorHalfWidth,
        wallHalfThickness: wall.halfThickness,
      );
      wall.node.visible = !occludesTarget;
    }

    final hostSegments = _wallVisuals
        .map(
          (wall) => ZamerHostWallSegment(
            wallId: wall.wallId,
            startX: wall.startX,
            startZ: wall.startZ,
            endX: wall.endX,
            endZ: wall.endZ,
            visible: wall.node.visible,
          ),
        )
        .toList(growable: false);
    for (final hosted in _hostedWallVisuals) {
      hosted.node.visible = zamerHostedWallVisualVisible(
        wallId: hosted.wallId,
        x: hosted.x,
        z: hosted.z,
        segments: hostSegments,
      );
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

    Scene? scene = _scene;
    if (scene == null || !_ready) {
      if (ZamerPhotoExportPolicy.requiresGpu(photoQuality: photoQuality)) {
        throw StateError(ZamerPhotoExportPolicy.gpuUnavailableMessage);
      }
      return _renderFallbackPng(width: width, height: height);
    }

    var photoSceneAttempted = false;
    try {
      if (photoQuality) {
        // Photo export is allowed to rebuild to production LOD0, but it must
        // never silently fall back to a raster compatibility view. The whole
        // preparation lives inside this try/finally so an interrupted GLB/GPU
        // rebuild still restores the interactive scene.
        photoSceneAttempted = true;
        await _rebuildScene(photoQuality: true);
        if (!mounted || !_ready || _scene == null) {
          throw StateError(ZamerPhotoExportPolicy.gpuUnavailableMessage);
        }
      }

      // Re-acquire the active scene after the Photo LOD rebuild. Today the
      // renderer mutates one Scene instance, but keeping this reference fresh
      // makes export safe if staged rebuild later swaps Scene objects.
      scene = _scene;
      if (scene == null || !_ready) {
        if (ZamerPhotoExportPolicy.requiresGpu(photoQuality: photoQuality)) {
          throw StateError(ZamerPhotoExportPolicy.gpuUnavailableMessage);
        }
        return _renderFallbackPng(width: width, height: height);
      }

      final camera = _camera();
      _applyCutaway(camera);
      if (photoQuality) _configurePhotoLighting(exportQuality: true);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final profile = zamerPhotoLightingProfile(widget.photoTime);
      final background = ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(0, 0),
          ui.Offset(0, height.toDouble()),
          <Color>[profile.backgroundTop, profile.backgroundBottom],
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
        if (data == null) {
          throw StateError('GPU-кадр не удалось преобразовать в PNG');
        }
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        image.dispose();
      }
    } finally {
      if (photoQuality && photoSceneAttempted && mounted) {
        _configureScene();
        try {
          // Restore adaptive realtime LOD immediately after export. Unlike the
          // old generic initialization retry, live rebuild retry also works
          // while the last valid GPU frame is still marked ready.
          await _rebuildScene();
        } catch (_) {
          _scheduleLiveRebuildRetry();
        }
      }
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
              color: Theme.of(context).colorScheme.surface
                  .withValues(alpha: 0.92),
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
    _hostedWallVisuals.clear();
    _ceilingNodes.clear();
    _finishTextures.clear();
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
      child: SceneView(scene, camera: camera, warmUp: true),
    );
  }
}

class _WallVisual {
  const _WallVisual({
    required this.node,
    required this.wallId,
    required this.startX,
    required this.startZ,
    required this.endX,
    required this.endZ,
    required this.halfThickness,
  });

  final Node node;
  final String wallId;
  final double startX;
  final double startZ;
  final double endX;
  final double endZ;
  final double halfThickness;
}

class _HostedWallVisual {
  const _HostedWallVisual({
    required this.node,
    required this.wallId,
    required this.x,
    required this.z,
  });

  final Node node;
  final String? wallId;
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
        if (candidate == prev || candidate == cur || candidate == next)
          continue;
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
