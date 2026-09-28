import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/engineering_screen.dart';
import 'package:zamer_app/services/geometry_service.dart';

void main() {
  testWidgets('engineering screen edits ceiling, warm floor and pipe route', (
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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EngineeringScreen(floor: floor, onChanged: () async {}),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Добавить потолочную зону'));
    await tester.tap(find.text('Добавить потолочную зону'));
    await tester.pump();
    expect(floor.roomMetas.first.ceiling.zones, hasLength(1));
    await tester.ensureVisible(find.text('Ш 1200'));
    await tester.tap(find.text('Ш 1200'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1500');
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(floor.roomMetas.first.ceiling.zones.single.widthMm, 1500);
    await tester.tap(find.text('Тёплый пол'));
    await tester.pump();
    await tester.tap(find.text('Водяной тёплый пол'));
    await tester.pump();
    expect(floor.roomMetas.first.heating.enabled, true);
    await tester.tap(find.text('Трубы'));
    await tester.pump();
    final preview = find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_EngineeringPainter',
    );
    final center = tester.getCenter(preview);
    await tester.tapAt(center - const Offset(55, 0));
    await tester.pump();
    await tester.tapAt(center + const Offset(55, 0));
    await tester.pump();
    await tester.tap(find.textContaining('Сохранить трассу'));
    await tester.pump();
    expect(floor.serviceRuns, hasLength(1));
    expect(floor.serviceRuns.single.lengthM, greaterThan(0));
  });
}
