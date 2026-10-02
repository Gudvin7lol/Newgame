import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('3D cutaway follows panned camera target with segment-aware occlusion', () {
    final source =
        File('lib/renderer3d/zamer_gpu_viewport.dart').readAsStringSync();

    // Top view must never remove walls.
    expect(source, contains('widget.tilt >= 1.32'));

    // The orbit target must follow pan instead of falling back to world origin.
    expect(source, contains('final target2 = vm.Vector2('));
    expect(source, contains('-widget.pan.dx * panScale'));
    expect(source, contains('-widget.pan.dy * panScale'));
    expect(source, contains('final cameraFromTarget = camera2 - target2;'));
    expect(
      source,
      contains('final targetPoint = math.Point<double>(target2.x, target2.y);'),
    );
    expect(
      source,
      contains('final cameraPoint = math.Point<double>(camera2.x, camera2.y);'),
    );

    // Current cutaway is segment-aware: it evaluates the real wall piece,
    // including thickness, rather than classifying only the wall centre.
    expect(source, contains('zamerWallSegmentOccludesCutaway('));
    expect(source, contains('start: math.Point<double>(wall.startX, wall.startZ)'));
    expect(source, contains('end: math.Point<double>(wall.endX, wall.endZ)'));
    expect(source, contains('target: targetPoint'));
    expect(source, contains('camera: cameraPoint'));
    expect(source, contains('wallHalfThickness: wall.halfThickness'));
    expect(source, contains('wall.node.visible = !occludesTarget;'));

    // Guard against both obsolete implementations regressing back in.
    expect(source, isNot(contains('final relative = wallPos - target2;')));
    expect(source, isNot(contains('final cameraDir = camera2.normalized();')));
    expect(source, isNot(contains('final radial = wallPos.length;')));
  });
}
