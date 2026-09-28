import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/estimate_screen.dart';
import 'package:zamer_app/services/geometry_service.dart';

void main() {
  testWidgets('estimate accepts a project price and recalculates total', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = FloorPlan(id: 'f', name: 'F');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 3000, yMm: 0),
      PlanNode(id: 'c', xMm: 3000, yMm: 3000),
      PlanNode(id: 'd', xMm: 0, yMm: 3000),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a'),
    ]);
    GeometryService.syncRoomMetadata(floor);
    final project = MeasureProject(id: 'p', name: 'P', floors: [floor]);
    await tester.pumpWidget(
      MaterialApp(
        home: EstimateScreen(project: project, onChanged: () async {}),
      ),
    );
    await tester.ensureVisible(find.text('Краска потолка'));
    await tester.tap(find.text('Краска потолка'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '500');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(project.unitPrices['Краска потолка|л'], 500);
    expect(
      find.textContaining('841'),
      findsWidgets,
    ); // 8.41 м² × 2 / 10 × 500 ₽
  });
}
