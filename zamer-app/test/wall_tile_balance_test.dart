import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/layout_service.dart';

void main() {
  test('wall tile layout avoids a 10 mm strip when a balanced cut fits', () {
    final result = LayoutService.balanceWallTiles(
      3010, 0, 2400, 600, 300,
    );
    expect(result.minimumCutMm, greaterThan(250));
  });

  test('staggered wall rows take both phases into account', () {
    final result = LayoutService.balanceWallTiles(
      2850, 0, 2400, 600, 300, staggered: true,
    );
    expect(result.minimumCutMm, greaterThan(0));
    expect(result.xMm, inInclusiveRange(0, 600));
  });
}
