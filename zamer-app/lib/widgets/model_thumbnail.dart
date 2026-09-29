import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../renderer3d/model_asset_catalog.dart';

/// Cached still preview rendered from the same bundled GLB used by the room.
///
/// A live SceneView in every catalogue cell is needlessly expensive on a phone.
/// Instead each LOD2 model is rendered once to a small PNG and reused while the
/// app is alive. Failed/legacy assets fall back to the existing 2D preview.
class ZamerModelThumbnail extends StatelessWidget {
  const ZamerModelThumbnail({
    super.key,
    required this.catalogId,
    required this.size,
    required this.fallback,
  });

  final String catalogId;
  final double size;
  final Widget fallback;

  static final Map<String, Future<Uint8List?>> _cache =
      <String, Future<Uint8List?>>{};
  static Future<void> _renderQueue = Future<void>.value();

  static Future<Uint8List?> _enqueueRender(String catalogId) {
    final result = Completer<Uint8List?>();
    _renderQueue = _renderQueue.then((_) async {
      result.complete(await _render(catalogId));
    });
    return result.future;
  }

  static Future<Uint8List?> _render(String catalogId) async {
    final asset = ZamerModelAssetCatalog.byId(catalogId);
    if (asset == null) return null;
    try {
      await Scene.initializeStaticResources();
      final scene = Scene();
      scene.environmentSettings = EnvironmentSettings(
        toneMapping: ToneMappingMode.pbrNeutral,
        environmentIntensity: 0.92,
        exposure: 1.0,
        ambientOcclusionEnabled: false,
        screenSpaceReflectionsEnabled: false,
        bloomEnabled: false,
        vignetteEnabled: false,
        autoExposureEnabled: false,
      );
      scene.antiAliasingMode = AntiAliasingMode.auto;
      scene.environmentIntensity = 0.92;
      scene.directionalLight = DirectionalLight(
        direction: vm.Vector3(-0.45, -1.0, -0.35)..normalize(),
        color: vm.Vector3(1.0, 0.97, 0.92),
        intensity: 2.35,
        castsShadow: false,
        cacheStaticShadows: false,
        shadowMapResolution: 256,
        shadowMaxDistance: 10,
        shadowSoftness: 0.16,
      );
      final model = await Node.fromGlbAsset(
        asset.pathForLod(ZamerModelLod.lod2),
      );
      final bounds = model.combinedLocalBounds;
      if (bounds == null) return null;

      final width = (bounds.max.x - bounds.min.x).abs();
      final height = (bounds.max.y - bounds.min.y).abs();
      final depth = (bounds.max.z - bounds.min.z).abs();
      final maxDimension = [width, height, depth]
          .where((value) => value.isFinite && value > 0.0001)
          .fold<double>(0, (a, b) => a > b ? a : b);
      if (maxDimension <= 0) return null;

      final scale = 1.35 / maxDimension;
      model
        ..scale = vm.Vector3.all(scale)
        ..position = vm.Vector3(
          -bounds.center.x * scale,
          -bounds.min.y * scale,
          -bounds.center.z * scale,
        )
        ..rotation = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          asset.yawCorrectionRad + 0.55,
        );
      scene.add(model);

      final camera = PerspectiveCamera(
        fovRadiansY: 38 * 3.141592653589793 / 180,
        position: vm.Vector3(2.2, 1.55, 2.65),
        target: vm.Vector3(0, 0.58, 0),
        up: vm.Vector3(0, 1, 0),
        fovNear: 0.01,
        fovFar: 25,
      );
      const pixels = 256;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final rect = ui.Rect.fromLTWH(0, 0, pixels.toDouble(), pixels.toDouble());
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(28)),
        ui.Paint()
          ..shader = ui.Gradient.linear(
            const ui.Offset(0, 0),
            ui.Offset(pixels.toDouble(), pixels.toDouble()),
            const <Color>[Color(0xFF253236), Color(0xFF12191C)],
          ),
      );
      scene.render(camera, canvas, viewport: rect, pixelRatio: 1);
      final picture = recorder.endRecording();
      final image = await picture.toImage(pixels, pixels);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final future = _cache.putIfAbsent(
      catalogId,
      () => _enqueueRender(catalogId),
    );
    return SizedBox.square(
      dimension: size,
      child: FutureBuilder<Uint8List?>(
        future: future,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) return fallback;
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          );
        },
      ),
    );
  }
}
