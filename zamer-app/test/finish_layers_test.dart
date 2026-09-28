import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/finish_layers_screen.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/material_service.dart';

void main() {
  testWidgets('finish stack updates clear dimensions and takeoff', (
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
    final face = GeometryService.roomFaces(floor).single;
    final meta = floor.roomMetas.single;
    meta.wallLayers.add(
      FinishLayer(id: 'plaster', name: 'Штукатурка', thicknessMm: 10),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FinishLayersScreen(
          floor: floor,
          face: face,
          meta: meta,
          onChanged: () async {},
        ),
      ),
    );
    expect(find.textContaining('2880 × 2880'), findsOneWidget);
    await tester.tap(find.byTooltip('Добавить слой в Пол снизу вверх'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Стяжка');
    await tester.enterText(find.byType(TextFormField).last, '50');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(meta.floorBuildUpMm, 50);
    expect(find.textContaining('2650.0 мм'), findsOneWidget);
    expect(
      MaterialService.roomEstimates(
        floor,
        face,
        meta,
      ).any((e) => e.name == 'Пирог пола: Стяжка'),
      true,
    );
  });
}
