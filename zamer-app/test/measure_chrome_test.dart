import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/design_system/zamer_measure_chrome.dart';
import 'package:zamer_app/design_system/zamer_theme.dart';

void main() {
  testWidgets('Measure view tabs expose 2D 3D AR and Photo modes', (tester) async {
    var mode = ZMeasureViewMode.twoD;

    await tester.pumpWidget(
      MaterialApp(
        theme: ZamerTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 360,
              child: ZMeasureViewTabs(
                value: mode,
                onChanged: (value) => setState(() => mode = value),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('2D'), findsOneWidget);
    expect(find.text('3D'), findsOneWidget);
    expect(find.text('AR'), findsOneWidget);
    expect(find.text('Фото'), findsOneWidget);

    await tester.tap(find.text('AR'));
    await tester.pump();
    expect(mode, ZMeasureViewMode.ar);
  });

  testWidgets('Measure tool rail matches the approved six tool groups', (
    tester,
  ) async {
    var tool = ZMeasureTool.walls;

    await tester.pumpWidget(
      MaterialApp(
        theme: ZamerTheme.dark,
        home: Scaffold(
          body: Center(
            child: ZMeasureToolRail(
              value: tool,
              onChanged: (value) => tool = value,
            ),
          ),
        ),
      ),
    );

    for (final label in const [
      'Стены',
      'Проёмы',
      'Объекты',
      'Размеры',
      'Текст',
      'Слои',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Размеры'));
    expect(tool, ZMeasureTool.dimensions);
  });
}
