import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Photo Studio stabilization smooths look input and resets across gestures',
    () {
      final source = File('lib/screens/photo_studio_screen.dart')
          .readAsStringSync();

      expect(
        source.contains('Offset _stabilizedLookDelta = Offset.zero;'),
        isTrue,
      );
      expect(source.contains('final lookDelta = _stabilization'), isTrue);
      expect(
        source.contains('_stabilizedLookDelta.dx * .68 + rawLook.dx * .32'),
        isTrue,
      );
      expect(
        source.contains('_stabilizedLookDelta.dy * .68 + rawLook.dy * .32'),
        isTrue,
      );
      expect(
        source.contains('CameraGesturePolicy.applyHorizontalSwipe('),
        isTrue,
      );
      expect(source.contains('deltaX: lookDelta.dx'), isTrue);
      expect(source.contains('sensitivity: .008'), isTrue);
      expect(source.contains('_tilt - lookDelta.dy * .005'), isTrue);
      expect(source.contains("label: 'Стабилизация движения'"), isTrue);

      final resets = RegExp(r'_stabilizedLookDelta = Offset\.zero;')
          .allMatches(source)
          .length;
      expect(
        resets,
        greaterThanOrEqualTo(3),
        reason: 'Stabilization must reset at declaration, gesture start and pointer-count transitions.',
      );
    },
  );
}
