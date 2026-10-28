import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/screens/electrical_screen.dart';
import 'package:zamer_app/widgets/electrical_plan_painter.dart';
import 'electrical_mounting_test.dart' show mountingFixture;

void main() {
  testWidgets('dimensions save directly once and existing undo restores them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = mountingFixture();
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ElectricalScreen(
            floor: floor,
            requestedMode: ElectricalMode.select,
            onChanged: () async {
              changes++;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final plan = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is ElectricalPlanPainter,
    );
    final painter =
        tester.widget<CustomPaint>(plan).painter! as ElectricalPlanPainter;
    await tester.tapAt(tester.getTopLeft(plan) + painter.p(700, 200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-mounting')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('mount-distance')),
      '800.125',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('mount-apply')));
    await tester.tap(find.byKey(const ValueKey('mount-apply')));
    await tester.pumpAndSettle();
    expect(floor.electricalPoints.single.xMm, 900.125);
    expect(floor.electricalPoints.single.mounting!.distanceMm, 800.125);
    expect(changes, 1);
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(floor.electricalPoints.single.xMm, 700);
    expect(floor.electricalPoints.single.mounting, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'cancel leaves geometry intact; group picker preserves geometry and supports unassigned',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final floor = mountingFixture();
      floor.electricalPoints.single.circuit = 'Кухня';
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElectricalScreen(
              floor: floor,
              requestedMode: ElectricalMode.select,
              onChanged: () async {
                changes++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> open() async {
        final plan = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is ElectricalPlanPainter,
        );
        final painter =
            tester.widget<CustomPaint>(plan).painter! as ElectricalPlanPainter;
        await tester.tapAt(tester.getTopLeft(plan) + painter.p(700, 200));
        await tester.pumpAndSettle();
      }

      await open();
      await tester.tap(find.byKey(const ValueKey('edit-mounting')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('mount-distance')),
        '820',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(changes, 0);
      expect(floor.electricalPoints.single.xMm, 700);
      await open();
      await tester.tap(find.byKey(const ValueKey('edit-point-properties')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('point-circuit')),
        'Черновик',
      );
      await tester.tap(find.byTooltip('Закрыть без сохранения'));
      await tester.pumpAndSettle();
      expect(changes, 0);
      expect(floor.electricalPoints.single.circuit, 'Кухня');
      await open();
      await tester.tap(find.byKey(const ValueKey('edit-point-properties')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('point-circuit')),
        'Черновик',
      );
      await tester.tap(find.byTooltip('Выбрать существующую группу'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Кухня').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('point-circuit')))
            .controller!
            .text,
        'Кухня',
      );
      await tester.enterText(find.byKey(const ValueKey('point-circuit')), '');
      await tester.tap(find.byKey(const ValueKey('point-save')));
      await tester.pumpAndSettle();
      expect(changes, 1);
      expect(floor.electricalPoints.single.circuit, isEmpty);
      expect(floor.electricalPoints.single.xMm, 700);
      expect(floor.electricalPoints.single.mounting, isNull);
      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
      expect(floor.electricalPoints.single.circuit, 'Кухня');
      expect(tester.takeException(), isNull);
    },
  );
}
