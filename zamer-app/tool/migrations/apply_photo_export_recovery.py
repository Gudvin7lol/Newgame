from pathlib import Path

path = Path('zamer-app/lib/renderer3d/zamer_gpu_viewport.dart')
text = path.read_text(encoding='utf-8')

import_anchor = "import 'photo_render_quality_policy.dart';\n"
import_line = "import 'photo_export_policy.dart';\n"
if import_line not in text:
    if import_anchor not in text:
        raise SystemExit('Missing photo render quality import anchor')
    text = text.replace(import_anchor, import_line + import_anchor, 1)

start_marker = '  Future<Uint8List> renderPng({'
end_marker = '\n  Future<Uint8List> _renderFallbackPng({'
start = text.find(start_marker)
if start < 0:
    raise SystemExit('Missing renderPng function')
end = text.find(end_marker, start)
if end < 0:
    raise SystemExit('Missing render fallback function anchor')

replacement = r'''  Future<Uint8List> renderPng({
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
'''

text = text[:start] + replacement + text[end:]
path.write_text(text, encoding='utf-8')
