import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/electrical_load_service.dart';

void main() {
  test('electrical load service sums group wattages and estimates current', () {
    final floor = FloorPlan(id: 'f', name: 'Electrical', electricalPoints: [
      ElectricalPoint(id: 'a', type: ElectricalPointType.appliance,
        xMm: 0, yMm: 0, circuit: 'Кухня', powerW: 2000),
      ElectricalPoint(id: 'b', type: ElectricalPointType.socket,
        xMm: 10, yMm: 10, circuit: 'Кухня', powerW: 300),
      ElectricalPoint(id: 'c', type: ElectricalPointType.ceilingLight,
        xMm: 20, yMm: 20, circuit: 'Освещение', powerW: 100),
      ElectricalPoint(id: 'd', type: ElectricalPointType.switchPoint,
        xMm: 30, yMm: 30, circuit: 'Освещение', powerW: 0),
    ]);
    final results = ElectricalLoadService.summarize(floor);
    expect(results.length, 2);
    final kitchen = results.firstWhere((c) => c.name == 'Кухня');
    expect(kitchen.connectedWatts, 2300);
    expect(kitchen.estimatedAmps, closeTo(10, .001));
    expect(kitchen.unratedCount, 0);
    final light = results.firstWhere((c) => c.name == 'Освещение');
    expect(light.connectedWatts, 100);
    expect(light.unratedCount, 0,
        reason: 'A switch is a controller, not an unknown load');
  });

  test('unrated socket is unknown, not an assumed zero-load circuit', () {
    final floor = FloorPlan(id: 'f', name: 'Unknown', electricalPoints: [
      ElectricalPoint(id: 'socket', type: ElectricalPointType.socket,
        xMm: 0, yMm: 0, powerW: 0),
    ]);
    final group = ElectricalLoadService.summarize(floor).single;
    expect(group.connectedWatts, 0);
    expect(group.unratedCount, 1);
  });

  test('reject invalid supply voltage and power factor', () {
    final floor = FloorPlan(id: 'f', name: 'Empty');
    expect(() => ElectricalLoadService.summarize(floor, voltageV: 0),
      throwsArgumentError);
    expect(() => ElectricalLoadService.summarize(floor, powerFactor: 1.2),
      throwsArgumentError);
  });

  test('electrical uses the same shared camera as Plan Floor and Objects', () {
    final workspace = File('lib/screens/recovered_measure_workspace_screen.dart')
        .readAsStringSync();
    final electrical = File('lib/screens/electrical_screen.dart')
        .readAsStringSync();
    expect(workspace, contains('sharedViewport: _sharedViewport'));
    expect(workspace, contains('viewportActive: _layer == 3'));
    expect(electrical, contains('PlanViewportSnapshot('));
    expect(electrical, contains('linked.centerXMm * scale'));
    expect(electrical, contains('linked.centerYMm * scale'));
    expect(electrical, contains('_touchDown'));
    expect(electrical, contains('_touchMove'));
    expect(electrical, contains('_publishCamera'));
    expect(electrical, contains("ValueKey('electrical-load-inventory')"));
  });

  test('floor shades use world-anchored row and column, not pixel bounds', () {
    final src = File('lib/widgets/cad_plan_painter_v2.dart')
        .readAsStringSync();
    expect(src, contains('origin.dx + settings.laminateOffsetXMm'));
    expect(src, contains('origin.dy + settings.laminateOffsetYMm'));
    expect(src, contains('origin.dx + settings.tileOffsetXMm'));
    expect(src, contains('origin.dy + settings.tileOffsetYMm'));
    expect(src, contains('column * 73856093'));
    expect(src, contains('row * 19349663'));
    expect(src, isNot(contains('((x * .017 + y * .031)')));
    expect(src, isNot(contains('((x * .01 + y * .017)')));
  });

  test('objects canvas is clipped beneath fixed mode task toolbar', () {
    final src = File('lib/screens/planning_objects_screen.dart')
        .readAsStringSync();
    expect(src, contains('Positioned.fill(child: ClipRect('));
  });
}
