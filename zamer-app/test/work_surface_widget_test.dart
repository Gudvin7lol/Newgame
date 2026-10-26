import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/screens/works_screen.dart';

void main() {
  testWidgets('wall finish editor selects modeled room wall and saves band',
      (tester) async {
    final floor = FloorPlan(id: 'f', name: 'Этаж 1',
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
      id: 'p', name: 'Объект', floors: [floor]);
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: WorksScreen(
      project: project, onChanged: () async { saves++; },
    )));
    await tester.pumpAndSettle();
    final open = find.text('Отделка по отдельным стенам');
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.textContaining('Поверхности:'), findsOneWidget);
    final preset = find.text('Плитка до потолка');
    await tester.scrollUntilVisible(preset, 220.0,
      scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(preset);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -130));
    await tester.pumpAndSettle();
    expect(preset.hitTestable(), findsOneWidget);
    await tester.tap(preset.hitTestable());
    await tester.pumpAndSettle();
    final save = find.text('Сохранить распределение');
    await tester.scrollUntilVisible(save, 180.0,
      scrollable: find.byType(Scrollable).last);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(project.workBoard.wallFinishes.length, 4);
    expect(project.workBoard.wallFinishes.any(
      (finish) => finish.tileHeightMm > 0), true);
  });
}
