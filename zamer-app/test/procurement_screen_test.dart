import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/procurement_screen.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/procurement_service.dart';
import 'package:zamer_app/services/budget_service.dart';

void main() {
  testWidgets('operator can record packs and correct a mistaken receipt', (
      tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = FloorPlan(
      id: 'f1', name: 'Этаж',
      nodes: [
        PlanNode(id: 'a', xMm: 0, yMm: 0),
        PlanNode(id: 'b', xMm: 3000, yMm: 0),
        PlanNode(id: 'c', xMm: 3000, yMm: 3000),
        PlanNode(id: 'd', xMm: 0, yMm: 3000),
      ],
      walls: [
        PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
        PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
        PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
        PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a'),
      ],
    );
    GeometryService.syncRoomMetadata(floor);
    final project = MeasureProject(
      id: 'p', name: 'Квартира', floors: [floor]);
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
      home: ProcurementScreen(
        project: project,
        onChanged: () async { saves++; },
      ),
    ));

    final before = ProcurementService.coverage(project)
        .firstWhere((row) => row.line.name == 'Ламинат / SPC');
    expect(before.remaining, 5);
    await tester.tap(find.byTooltip('Учесть закупку: Ламинат / SPC'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('purchase-quantity')), '2');
    await tester.enterText(
      find.byKey(const Key('purchase-paid')), '1450');
    await tester.tap(find.text('Записать'));
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(project.materialPurchases, hasLength(1));
    expect(project.costEntries, hasLength(1));
    expect(BudgetService.review(project).actualMaterials, 1450);
    expect(ProcurementService.purchasedFor(
        project, before.line.key), 2);
    // The history is below the purchase list and is initially off-screen.
    await tester.scrollUntilVisible(
      find.byTooltip('Отменить закупку'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Отменить закупку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отменить запись').last);
    await tester.pumpAndSettle();

    expect(saves, 2);
    expect(project.materialPurchases, hasLength(2));
    // A cancelled receipt does not imply the shop returned the money.
    expect(BudgetService.review(project).actualMaterials, 1450);
    expect(ProcurementService.purchasedFor(
        project, before.line.key), 0);
  });
}
