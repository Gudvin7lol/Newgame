import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/electrical_mounting.dart';
import 'package:zamer_app/widgets/electrical_mounting_editor.dart';

import 'electrical_mounting_test.dart' show mountingFixture;

void main() {
  testWidgets(
    'mobile mounting editor preserves position on datum reversal and returns a draft',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = mountingFixture();
      ElectricalMounting? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Открыть'),
                onPressed: () async {
                  result = await Navigator.push<ElectricalMounting>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ElectricalMountingEditor(
                        floor: f,
                        point: f.electricalPoints.single,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(find.text('От плиты: нет данных'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mount-datum-w')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('От узла B к A').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('mount-distance')))
            .controller!
            .text,
        '2600',
      );
      await tester.ensureVisible(find.text('Монтажная база и отметка плиты'));
      await tester.tap(find.text('Монтажная база и отметка плиты'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('mount-floor')));
      await tester.enterText(find.byKey(const ValueKey('mount-floor')), '80');
      await tester.pump();
      expect(find.text('Центр над плитой: 380 мм'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('mount-apply')));
      await tester.tap(find.byKey(const ValueKey('mount-apply')));
      await tester.pumpAndSettle();
      expect(result!.distanceMm, 2600);
      expect(result!.heightAboveSlabMm, 380);
      expect(
        f.electricalPoints.single.mounting,
        isNull,
      ); // parent save owns mutation
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'invalid input stays in editor; cancellation does not change project',
    (tester) async {
      final f = mountingFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: ElectricalMountingEditor(
            floor: f,
            point: f.electricalPoints.single,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('mount-distance')),
        '5000',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('mount-apply')));
      await tester.tap(find.byKey(const ValueKey('mount-apply')));
      await tester.pump();
      expect(
        find.text('Центр выходит за конец стены. Размер не сохранён.'),
        findsOneWidget,
      );
      expect(f.electricalPoints.single.xMm, 700);
      expect(f.electricalPoints.single.mounting, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'save stays above keyboard on a narrow phone; invalid input cannot save',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final f = mountingFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: ElectricalMountingEditor(
            floor: f,
            point: f.electricalPoints.single,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mount-wall')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('mount-distance')),
        '700.25',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('mount-apply'));
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(480));
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.enterText(
        find.byKey(const ValueKey('mount-distance')),
        '-1',
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(f.electricalPoints.single.mounting, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
