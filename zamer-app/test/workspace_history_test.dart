import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/floor_workspace_screen.dart';
import 'package:zamer_app/services/geometry_service.dart';

void main() {
  testWidgets('workspace undo restores an edit made in another tab', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = FloorPlan(id: 'f', name: 'Этаж');
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
    final project = MeasureProject(id: 'p', name: 'Квартира', floors: [floor]);
    await tester.pumpWidget(
      MaterialApp(
        home: FloorWorkspaceScreen(
          project: project,
          floor: floor,
          onChanged: () async {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Комнаты'));
    await tester.pumpAndSettle();

    expect(find.text('Комнаты'), findsWidgets);
    await tester.tap(find.text('Помещение 1').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переименовать'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Кабинет');
    await tester.tap(find.text('Сохранить').last);
    await tester.pumpAndSettle();
    expect(floor.roomMetas.single.name, 'Кабинет');
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Отменить изменение на этаже'));
    await tester.pumpAndSettle();
    expect(floor.roomMetas.single.name, 'Помещение 1');
  });
}
