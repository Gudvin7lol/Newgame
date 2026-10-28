import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/estimate_screen.dart';
import 'package:zamer_app/services/budget_service.dart';

void main() {
  testWidgets('estimate opens budget, records payment and reverses it', (
      tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final project = MeasureProject(id: 'p', name: 'Студия');
    var saves = 0;

    await tester.pumpWidget(MaterialApp(
      home: EstimateScreen(
        project: project,
        onChanged: () async { saves++; },
      ),
    ));
    await tester.tap(find.byTooltip('Бюджет и факт'));
    await tester.pumpAndSettle();
    expect(find.text('Бюджет и факт'), findsOneWidget);

    await tester.tap(find.text('Записать расход'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('budget-title')), 'Клей для плитки');
    await tester.enterText(
        find.byKey(const Key('budget-amount')), '1250');
    await tester.tap(find.text('Записать'));
    await tester.pumpAndSettle();

    expect(project.costEntries, hasLength(1));
    expect(BudgetService.review(project).actualMaterials, 1250);
    expect(find.text('Клей для плитки'), findsOneWidget);
    expect(find.textContaining('Факт: 1250'), findsOneWidget);
    expect(saves, 1);

    await tester.tap(find.byTooltip('Отменить расход'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отменить расход').last);
    await tester.pumpAndSettle();

    expect(project.costEntries, hasLength(2));
    expect(BudgetService.review(project).actualTotal, 0);
    expect(saves, 2);
    expect(find.textContaining('Факт: 0'), findsOneWidget);
  });
}
