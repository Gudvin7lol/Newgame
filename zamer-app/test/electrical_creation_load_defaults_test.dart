import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/electrical_design_draft.dart';
import 'package:zamer_app/screens/electrical_screen.dart';
import 'package:zamer_app/services/electrical_device_catalog.dart';
import 'package:zamer_app/services/electrical_design_engine.dart';
import 'package:zamer_app/widgets/electrical_plan_painter.dart';

ElectricalPoint _point(String id, ElectricalPointType type,
    {List<ElectricalModuleType>? modules}) => ElectricalPoint(
  id: id, type: type, xMm: 1200, yMm: 0,
  wallId: 'wall', wallOffsetMm: 1200, wallSide: 1,
  modules: modules,
);

FloorPlan _floor() {
  final floor = FloorPlan(id: 'f', name: 'Этаж');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 4000, yMm: 0),
    PlanNode(id: 'c', xMm: 4000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
  ]);
  floor.walls.addAll([
    PlanWall(id: 'wall', startNodeId: 'a', endNodeId: 'b'),
    PlanWall(id: 'w2', startNodeId: 'b', endNodeId: 'c'),
    PlanWall(id: 'w3', startNodeId: 'c', endNodeId: 'd'),
    PlanWall(id: 'w4', startNodeId: 'd', endNodeId: 'a'),
  ]);
  return floor;
}

void main() {
  test('new sockets and lights have transparent, editable planning defaults', () {
    final socket = ElectricalDeviceCatalog.defaultForPoint(
        _point('socket', ElectricalPointType.socket))!;
    expect(socket.catalogId, 'socket_std');
    expect(socket.installedWatts, 300);
    expect(socket.demandFactor, 1);
    expect(socket.kind, ElectricalConsumerKind.sockets);
    expect(ElectricalDeviceCatalog.defaultForPoint(
        _point('light', ElectricalPointType.ceilingLight))!.installedWatts, 50);
  });

  test('frame counts only powered posts, never TV, data or switches', () {
    final multi = _point('frame', ElectricalPointType.frame, modules: [
      ElectricalModuleType.socket220,
      ElectricalModuleType.tv,
      ElectricalModuleType.data,
      ElectricalModuleType.socket220,
    ]);
    expect(ElectricalDeviceCatalog.defaultForPoint(multi)!.installedWatts, 600);
    final passive = _point('passive', ElectricalPointType.frame, modules: [
      ElectricalModuleType.tv,
      ElectricalModuleType.data,
    ]);
    expect(ElectricalDeviceCatalog.defaultForPoint(passive), isNull);
    for (final type in [
      ElectricalPointType.tvSocket, ElectricalPointType.dataSocket,
      ElectricalPointType.switchPoint, ElectricalPointType.panel,
      ElectricalPointType.junctionBox, ElectricalPointType.appliance,
    ]) {
      expect(ElectricalDeviceCatalog.defaultForPoint(
        _point('passive-type', type)), isNull);
    }
  });

  test('legacy imports remain unmodified and signal ports are not AC loads', () {
    final floor = _floor();
    floor.electricalPoints.addAll([
      _point('old', ElectricalPointType.socket),
      _point('tv', ElectricalPointType.tvSocket),
      _point('data', ElectricalPointType.dataSocket),
    ]);
    final restored = FloorPlan.fromJson(floor.toJson());
    expect(restored.electricalDesignDraft, isNull);
    final result = ElectricalDesignEngine.calculate(
        restored, ElectricalDesignDraft());
    expect(result.demandWatts, isNull); // Old socket remains unknown.
    expect(result.issues.map((i) => i.code),
        contains('MISSING_LOAD_ASSUMPTIONS'));
    expect(result.issues.where((i) => i.code == 'MISSING_CONSUMER_CLASS'),
        isEmpty);
  });

  testWidgets('tap to create a socket persists a nonzero, provisional load',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = _floor();
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ElectricalScreen(floor: floor, onChanged: () async { saves++; }),
    )));
    await tester.pumpAndSettle();
    final finder = find.byWidgetPredicate((w) =>
      w is CustomPaint && w.painter is ElectricalPlanPainter);
    final paint = tester.widget<CustomPaint>(finder);
    final painter = paint.painter! as ElectricalPlanPainter;
    final local = painter.origin + Offset(
      1200 * painter.scale, 0 * painter.scale);
    final box = tester.renderObject<RenderBox>(finder);
    await tester.tapAt(box.localToGlobal(local));
    await tester.pumpAndSettle();
    expect(floor.electricalPoints, hasLength(1));
    final point = floor.electricalPoints.single;
    expect(point.powerW, 300);
    expect(point.wallId, 'wall');
    final entry = floor.electricalDesignDraft!.consumers[point.id]!;
    expect(entry.catalogId, 'socket_std');
    expect(entry.installedWatts, 300);
    expect(entry.demandFactor, 1);
    expect(saves, greaterThanOrEqualTo(1));
    expect(FloorPlan.fromJson(floor.toJson())
      .electricalDesignDraft!.consumers[point.id]!.installedWatts, 300);
    expect(tester.takeException(), isNull);
  });
}
