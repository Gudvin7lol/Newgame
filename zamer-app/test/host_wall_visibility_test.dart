import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/host_wall_visibility.dart';

void main() {
  test('unhosted visual remains visible', () {
    expect(
      zamerHostedWallVisualVisible(
        wallId: null,
        x: 0,
        z: 0,
        segments: const <ZamerHostWallSegment>[],
      ),
      isTrue,
    );
  });

  test('hosted visual follows nearest segment of its wall', () {
    const segments = <ZamerHostWallSegment>[
      ZamerHostWallSegment(
        wallId: 'w',
        startX: -4,
        startZ: 0,
        endX: -2,
        endZ: 0,
        visible: true,
      ),
      ZamerHostWallSegment(
        wallId: 'w',
        startX: 1,
        startZ: 0,
        endX: 3,
        endZ: 0,
        visible: false,
      ),
      ZamerHostWallSegment(
        wallId: 'other',
        startX: 1.8,
        startZ: 0,
        endX: 2.2,
        endZ: 0,
        visible: true,
      ),
    ];

    expect(
      zamerHostedWallVisualVisible(
        wallId: 'w',
        x: 2,
        z: 0.15,
        segments: segments,
      ),
      isFalse,
    );
  });

  test('unknown host wall stays visible instead of disappearing', () {
    expect(
      zamerHostedWallVisualVisible(
        wallId: 'missing',
        x: 2,
        z: 0,
        segments: const <ZamerHostWallSegment>[
          ZamerHostWallSegment(
            wallId: 'w',
            startX: 0,
            startZ: 0,
            endX: 4,
            endZ: 0,
            visible: false,
          ),
        ],
      ),
      isTrue,
    );
  });
}
