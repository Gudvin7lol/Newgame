import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Photo viewport uses the finished-interior ceiling policy', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();

    expect(
      source,
      contains('ZamerCeilingVisibilityPolicy.visible('),
    );
    expect(source, contains('walkMode: widget.walkMode,'));
    expect(source, contains('photoPreview: widget.photoPreview,'));
    expect(
      source,
      isNot(contains('..visible = widget.walkMode;')),
      reason: 'Photo Render must not drop the ceiling just because Walk Mode is off.',
    );
  });

  test('Photo preview background matches the selected lighting profile', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();

    expect(
      source,
      contains(
        'final previewProfile = widget.photoPreview\n'
        '        ? zamerPhotoLightingProfile(widget.photoTime)\n'
        '        : null;',
      ),
    );
    expect(source, contains('previewProfile.backgroundTop'));
    expect(source, contains('previewProfile.backgroundBottom'));
    expect(
      source,
      contains('profile.backgroundTop'),
      reason: 'Final PNG must continue using the same time-of-day profile.',
    );
    expect(source, contains('profile.backgroundBottom'));
  });
}
