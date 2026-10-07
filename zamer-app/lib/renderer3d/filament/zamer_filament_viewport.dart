import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../render_quality.dart';
import '../zamer_gpu_viewport.dart';
import '../zamer_scene_geometry.dart';
import 'zamer_glb_scene_builder.dart';

/// Realtime Zamer viewport backed by Google's Filament on Android.
///
/// The old flutter_scene renderer remains a temporary non-Android fallback
/// while the migration is verified on device.
class ZamerFilamentViewport extends StatefulWidget {
  const ZamerFilamentViewport({
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
    this.walkFovDegrees = 64,
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
  State<ZamerFilamentViewport> createState() => ZamerFilamentViewportState();
}

class ZamerFilamentViewportState extends State<ZamerFilamentViewport> {
  MethodChannel? _channel;
  Uint8List? _pendingGlb;
  bool _buildingGlb = false;
  int _sceneFingerprint = 0;
  int _buildGeneration = 0;
  Object? _error;

  bool get _useFilament =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _sceneFingerprint = _fingerprint();
    if (_useFilament) _rebuildGlb();
  }

  @override
  void didUpdateWidget(covariant ZamerFilamentViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_useFilament) return;
    final fingerprint = _fingerprint();
    if (fingerprint != _sceneFingerprint ||
        oldWidget.walkMode != widget.walkMode) {
      _sceneFingerprint = fingerprint;
      _rebuildGlb();
    }
    if (oldWidget.quality != widget.quality) {
      _channel?.invokeMethod<void>(
        'setQuality',
        {'quality': _qualityName(widget.quality)},
      );
    }
    _pushCamera();
  }

  int _fingerprint() {
    // Full project JSON keeps the bridge deterministic while the Filament
    // backend is being brought online. It can be replaced with dirty flags once
    // the migration is complete.
    return jsonEncode(widget.floor.toJson()).hashCode;
  }

  Future<void> _rebuildGlb() async {
    final generation = ++_buildGeneration;
    if (mounted) setState(() => _buildingGlb = true);
    try {
      // The first Filament prototype used Flutter compute() here. On several
      // real Android devices the isolate handoff never returned, leaving the
      // viewport behind an endless spinner even though the native view was
      // already alive. Scene export is deterministic and small enough for the
      // current room sizes, so build it directly and yield once before loading.
      await Future<void>.delayed(Duration.zero);
      final started = DateTime.now();
      final bytes = const ZamerGlbSceneBuilder().build(
        FloorPlan.fromJson(widget.floor.toJson()),
        includeCeiling: widget.walkMode,
      );
      if (!mounted || generation != _buildGeneration) return;

      if (bytes.isEmpty) {
        throw StateError('GLB builder returned an empty scene.');
      }
      _pendingGlb = bytes;
      _buildingGlb = false;
      _error = null;
      setState(() {});

      final channel = _channel;
      if (channel != null) {
        await channel
            .invokeMethod<void>('loadGlb', {'bytes': bytes})
            .timeout(const Duration(seconds: 12));
        if (!mounted || generation != _buildGeneration) return;
        _pushCamera();
      }

      debugPrint(
        'Filament GLB ready: ${bytes.length} bytes in '
        '${DateTime.now().difference(started).inMilliseconds} ms',
      );
    } on TimeoutException {
      if (mounted && generation == _buildGeneration) {
        setState(() {
          _buildingGlb = false;
          _error = StateError(
            'Filament did not accept the GLB scene within 12 seconds.',
          );
        });
      }
    } catch (error, stack) {
      debugPrint('Filament GLB build/load failed: $error\n$stack');
      if (mounted && generation == _buildGeneration) {
        setState(() {
          _buildingGlb = false;
          _error = error;
        });
      }
    }
  }

  String _qualityName(ZamerRenderQuality quality) => switch (quality) {
        ZamerRenderQuality.performance => 'performance',
        ZamerRenderQuality.quality => 'quality',
        ZamerRenderQuality.photo4k => 'photo',
      };

  Map<String, double> _cameraPayload() {
    final bounds = ZamerSceneBounds.fromFloor(widget.floor);
    double mx(double x) => (x - bounds.centerX) / 1000;
    double mz(double y) => (y - bounds.centerY) / 1000;

    if (widget.walkMode) {
      final eyeX = mx(widget.walkX);
      final eyeY = 1.65;
      final eyeZ = mz(widget.walkY);
      final pitch = widget.tilt.clamp(-1.20, 1.10).toDouble();
      final cp = math.cos(pitch);
      final fx = math.cos(widget.rotation) * cp;
      final fy = math.sin(pitch);
      final fz = math.sin(widget.rotation) * cp;
      return <String, double>{
        'eyeX': eyeX,
        'eyeY': eyeY,
        'eyeZ': eyeZ,
        'targetX': eyeX + fx * 4,
        'targetY': eyeY + fy * 4,
        'targetZ': eyeZ + fz * 4,
        'fov': widget.walkFovDegrees.clamp(50, 82).toDouble(),
        'near': 0.045,
        'far': 180,
      };
    }

    final maxDimension = math.max(bounds.widthMm, bounds.depthMm) / 1000;
    final zoom = widget.zoom.clamp(0.15, 10.0).toDouble();
    final distance = math.max(1.15, math.max(3.2, maxDimension * 1.52) / zoom);
    final elevation = widget.tilt.clamp(0.18, 1.46).toDouble();
    final horizontal = math.cos(elevation) * distance;
    final panScale = distance / 900;
    final targetX = -widget.pan.dx * panScale;
    final targetY = math.max(0.40, math.min(1.35, maxDimension * 0.09));
    final targetZ = -widget.pan.dy * panScale;
    return <String, double>{
      'eyeX': targetX + math.cos(widget.rotation) * horizontal,
      'eyeY': targetY + math.sin(elevation) * distance,
      'eyeZ': targetZ + math.sin(widget.rotation) * horizontal,
      'targetX': targetX,
      'targetY': targetY,
      'targetZ': targetZ,
      'fov': 48,
      'near': 0.05,
      'far': math.max(120, distance * 16),
    };
  }

  Future<void> _pushCamera() async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('setCamera', _cameraPayload());
    } catch (_) {
      // A platform view can disappear during tab/page transitions.
    }
  }

  Future<Uint8List> renderPng({
    required int width,
    required int height,
    bool photoQuality = false,
  }) async {
    if (!_useFilament) {
      throw UnsupportedError('Filament capture is Android-only.');
    }
    final channel = _channel;
    if (channel == null) {
      throw StateError('Filament viewport is not ready.');
    }
    if (photoQuality) {
      await channel.invokeMethod<void>(
        'setQuality',
        {'quality': 'photo'},
      );
    }
    final png = await channel.invokeMethod<Uint8List>('capture');
    if (png == null || png.isEmpty) {
      throw StateError('Filament returned an empty frame.');
    }
    if (photoQuality) {
      await channel.invokeMethod<void>(
        'setQuality',
        {'quality': _qualityName(widget.quality)},
      );
    }
    return png;
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('ru.zamer.zamer_app/filament/$id');
    final bytes = _pendingGlb;
    if (bytes != null) {
      _channel!.invokeMethod<void>('loadGlb', {'bytes': bytes}).then((_) {
        _pushCamera();
      });
    } else {
      _pushCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_useFilament) {
      return ZamerGpuViewport(
        floor: widget.floor,
        rotation: widget.rotation,
        tilt: widget.tilt,
        zoom: widget.zoom,
        cutaway: widget.cutaway,
        pan: widget.pan,
        walkMode: widget.walkMode,
        walkX: widget.walkX,
        walkY: widget.walkY,
        walkFovDegrees: widget.walkFovDegrees,
        quality: widget.quality,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        AndroidView(
          viewType: 'ru.zamer.zamer_app/filament',
          creationParams: <String, dynamic>{
            'quality': _qualityName(widget.quality),
            'camera': _cameraPayload(),
          },
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
        if (_buildingGlb && _pendingGlb == null)
          const ColoredBox(
            color: Color(0xFF1C1F22),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null)
          ColoredBox(
            color: const Color(0xFF1C1F22),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Filament: не удалось собрать сцену.\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
