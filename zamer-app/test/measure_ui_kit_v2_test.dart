import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/screens/master_equipment_screen.dart';
import 'package:zamer_app/widgets/zamer_fan_profiles_v2.dart';
import 'package:zamer_app/widgets/zamer_ui_kit_v2.dart';

void main() {
  test('UI Kit 1.2 keeps four top domains and one unified furniture view', () {
    expect(ZamerKitNavigation.domains,
        ['План', 'Пол', 'Объекты', 'Электрика']);
    expect(ZamerKitNavigation.categories(2), ['Мебель']);
    expect(ZamerKitNavigation.categories(2),
        isNot(contains('Кухня')));
    expect(ZamerKitNavigation.categories(2),
        isNot(contains('Декор')));
    expect(ZamerKitNavigation.categories(2),
        isNot(contains('Сантехника')));
    expect(ZamerFanProfilesV2.profileIds.length, 43);
    final idle = ZamerFanProfilesV2.of('plan.idle',
        enabledActions: {'nodes', 'arc'});
    expect(idle.first.label, 'Узлы');
    expect(idle.first.enabled, isTrue);
    expect(idle.second.label, 'Дуга');
    expect(idle.outer.last.enabled, isFalse);
  });

  testWidgets('native radial fan expands, dispatches and collapses',
      (tester) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final picked = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomRight,
          child: ZamerKitFan(
            contextId: 'plan.idle',
            selectedCommand: 'select',
            first: const ZamerKitCommand(
                'wall', 'Стена', Icons.border_outer_rounded),
            second: const ZamerKitCommand(
                'opening', 'Проём', Icons.door_front_door_outlined),
            outer: const [
              ZamerKitCommand('measure','Измерить',Icons.straighten_outlined),
              ZamerKitCommand('frame','Рамка',Icons.crop_free_outlined,
                  enabled:false),
            ],
            onCommand: picked.add,
          ),
        ),
      ),
    ));
    await tester.pump();
    // Default collapsed view leaves drawing canvas usable.
    expect(find.text('Стена'), findsNothing);
    expect(find.byKey(const ValueKey('fan-quick-select')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fan-expand')));
    await tester.pumpAndSettle();
    expect(find.text('Стена'), findsOneWidget);
    final top = tester.getTopLeft(find.byType(ZamerKitFan));
    await tester.tapAt(top + const Offset(134, 134));
    await tester.pump();
    expect(picked, ['wall']);
    await tester.tapAt(top + const Offset(188, 188));
    await tester.pumpAndSettle();
    expect(find.text('Стена'), findsNothing);
    expect(find.byKey(const ValueKey('fan-quick-select')), findsOneWidget);
    expect(find.byKey(const ValueKey('fan-expand')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('furniture catalog has no Kitchen / Decor / Plumbing sidebar',
      (tester) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MasterEquipmentScreen(
          projectTitle: 'Квартира',
          embedded: true,
          singleFurnitureView: true,
          renderModelPreviews: false,
          onAdd: (_) {},
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('Мебель'), findsOneWidget);
    expect(find.text('Кухня'), findsNothing);
    expect(find.text('Декор'), findsNothing);
    expect(find.text('Сантехника'), findsNothing);
    expect(find.text('Мягкая мебель'), findsNothing);
    expect(find.text('Все'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
