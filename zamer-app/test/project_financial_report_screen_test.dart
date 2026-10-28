import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/budget_screen.dart';
import 'package:zamer_app/services/report_service.dart';

void main() {
  testWidgets('budget opens project report and shows CSV and PDF export',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final project = MeasureProject(id: 'p', name: 'Студия');
    await tester.pumpWidget(MaterialApp(
      home: BudgetScreen(
        project: project,
        onChanged: () async {},
      ),
    ));
    await tester.tap(find.byTooltip('Отчёт по объекту'));
    await tester.pumpAndSettle();
    expect(find.text('Отчёт по объекту'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.textContaining('План неполный'), findsOneWidget);
    expect(find.textContaining('Закупки'), findsOneWidget);
  });

  testWidgets('PDF financial export returns actual PDF bytes for an empty site',
      (tester) async {
    final project = MeasureProject(id: 'pdf', name: 'Тестовый объект');
    final bytes = await ReportService.buildFinancialPdf(
      project, at: DateTime(2026, 10, 28, 12));
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
