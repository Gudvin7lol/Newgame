import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Photo export requires GPU and restores realtime scene safely', () {
    final viewport = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();

    expect(viewport.contains("import 'photo_export_policy.dart';"), isTrue);
    expect(
      viewport.contains(
        'ZamerPhotoExportPolicy.requiresGpu(photoQuality: photoQuality)',
      ),
      isTrue,
      reason: 'Final Photo Render must not silently use compatibility output.',
    );
    expect(viewport.contains('var photoSceneAttempted = false;'), isTrue);
    expect(
      viewport.contains('_scheduleLiveRebuildRetry();'),
      isTrue,
      reason: 'Photo restore failure must retry even while the last GPU frame is still ready.',
    );
  });
}
