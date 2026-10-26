import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/screens/works_screen.dart';

void main() {
  testWidgets('draw multiple floor-zone vertices and save allocation',
      (tester) async {
    final floor = FloorPlan(id: 'f1', name: 'Этаж',
      nodes: [
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 4000, yMm: 0),
        PlanNode(id: 'c', xMm: 4000, yMm: 3000),
        PlanNode(id: 'd', xMm: 0, yMm: 3000),
      ],
      walls: [
        PlanWall(id: 'w1', startNodeId: 'a', endNodeId: 'b'),
        PlanWall(id: 'w2', startNodeId: 'b', endNodeId: 'c'),
        PlanWall(id: 'w3', startNodeId: 'c', endNodeId: 'd'),
        PlanWall(id: 'w4', startNodeId: 'd', endNodeId: 'a'),
      ],
    );
    GeometryService.syncRoomMetadata(floor);
    final project = MeasureProject(
      id: 'p', name: 'Тестовый объект', floors: [floor]);
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: WorksScreen(
      project: project, onChanged: () async { saves++; },
    )));
    await tester.pumpAndSettle();
    final entry = find.text('Нарисовать зоны пола');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.textContaining('Контуры пола:'), findsOneWidget);

    final canvas = find.byType(AspectRatio).last;
    final rect = tester.getRect(canvas);
    for (final relative in const <Offset>[
      Offset(.36, .36), Offset(.56, .36),
      Offset(.56, .58), Offset(.36, .58),
    ]) {
      await tester.tapAt(Offset(rect.left + rect.width * relative.dx,
        rect.top + rect.height * relative.dy));
      await tester.pump();
    }
    final complete = find.text('Завершить зону');
    expect(complete, findsOneWidget);
    await tester.tap(complete);
    await tester.pumpAndSettle();

    final save = find.text('Сохранить зоны');
    expect(save, findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(project.workBoard.floorZones, hasLength(1));
    expect(project.workBoard.floorZones.single.polygon, hasLength(4));
    expect(project.workBoard.floorZones.single.material, 'tile');

    // Reopen the persisted polygon and drag an existing vertex, rather than
    // drawing a new zone. Its original ID and other vertices stay intact.
    final original = List.of(project.workBoard.floorZones.single.polygon);
    final zoneId = project.workBoard.floorZones.single.id;
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Править вершины'));
    await tester.pumpAndSettle();
    // Mobile users may also choose the zone and its numbered point from
    // short chips instead of aiming at a tiny vertex on a phone.
    final selectedZone = find.textContaining('Зона 1');
    await tester.scrollUntilVisible(selectedZone, 130.0,
      scrollable: find.byType(Scrollable).last);
    await tester.tap(selectedZone);
    await tester.pumpAndSettle();
    final firstVertex = find.text('Точка 1');
    await tester.scrollUntilVisible(firstVertex, 120.0,
      scrollable: find.byType(Scrollable).last);
    await tester.tap(firstVertex);
    await tester.pumpAndSettle();
    final coordinates = find.text('Ввести X/Y');
    await tester.scrollUntilVisible(coordinates, 130.0,
      scrollable: find.byType(Scrollable).last);
    await tester.tap(coordinates);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first,
      (original.first.x + 100).round().toString());
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить зоны'));
    await tester.pumpAndSettle();
    expect(saves, 2);
    expect(project.workBoard.floorZones, hasLength(1));
    expect(project.workBoard.floorZones.single.id, zoneId);
    expect(project.workBoard.floorZones.single.polygon.first,
      isNot(original.first));
    expect(project.workBoard.floorZones.single.polygon[2], original[2]);
  });
}
