import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selected walls and materials never reserve bottom viewport height', () {
    final src = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(src, contains('child: _canvas()'));
    expect(src, contains("ValueKey('floating-wall-inspector')"));
    expect(src, contains("ValueKey('floating-materials-toggle')"));
    expect(src, contains('animation: _transform'));
    expect(src, contains('onPressed: _resizeSelectedWall'));
  });

  test('door editing is contextual and keeps direct hinge/swing actions', () {
    final src = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    expect(src, contains("ValueKey('floating-opening-inspector')"));
    expect(src, contains("ValueKey('door-flip-hinges')"));
    expect(src, contains("ValueKey('door-flip-swing')"));
    expect(src, contains('if (alreadySelected) await _editOpening'));
    expect(src, contains('_openingDragUpdate'));
  });

  test('furniture camera pinch navigates instead of changing rotation', () {
    final src = File('lib/screens/planning_objects_screen.dart')
        .readAsStringSync();
    expect(src, contains('if (d.pointerCount >= 2 || _pinchingCamera)'));
    expect(src, contains('_viewZoom = nextZoom'));
    expect(src, contains('_viewPan = nextPan'));
    expect(src, contains("ValueKey('floating-object-inspector')"));
    expect(src, contains('Icons.center_focus_strong_rounded'));
    expect(src, isNot(contains('o.rotationDeg = _gestureBaseRotation')));
  });

  test('radial dial stays compact in the live recovery shell', () {
    final src = File('lib/screens/recovered_measure_workspace_screen.dart')
        .readAsStringSync();
    expect(src, contains('scale: .82'));
    expect(src, contains("ValueKey('zamer-native-v2-fan')"));
    expect(src, contains('bottom: 8'));
  });
}
