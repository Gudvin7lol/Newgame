import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/widgets/zamer_ui_kit_v2.dart';
import 'package:zamer_app/widgets/zamer_fan_profiles_v2.dart';

void main() {
  test('UI Kit v2 keeps its 43 contexts and one unsegmented Furniture task', () {
    expect(ZamerFanProfilesV2.profileIds.length, 43);
    expect(ZamerKitNavigation.categories(0),
      ['Стены', 'Перегородки', 'Проёмы', 'Демонтаж', 'Размеры']);
    expect(ZamerKitNavigation.categories(2), ['Мебель']);
    final profile = ZamerFanProfilesV2.of(
      'plan.opening.create',
      enabledActions: {'select', 'door', 'window', 'measure'},
    );
    expect(profile.first.id, 'door');
    expect(profile.second.id, 'window');
    expect(profile.outer.first.enabled, isFalse,
      reason: 'Arch is present in the specification but not yet an editor.');
  });

  test('production route uses native kit and disables furniture subcategory bars',
      () {
    final app = File('lib/screens/recovered_measure_workspace_screen.dart')
      .readAsStringSync();
    final catalog = File('lib/screens/master_equipment_screen.dart')
      .readAsStringSync();
    expect(app, contains("ZamerKitFan("));
    expect(app, contains("ZamerKitNavigation.categories("));
    expect(app, contains("singleFurnitureView: true"));
    expect(app, contains("planTool: _planTool"));
    expect(app, contains("preferredOpeningType: _preferredOpeningType"));
    expect(catalog, contains("if (!widget.singleFurnitureView) SizedBox("));
    expect(catalog, contains("if (!widget.singleFurnitureView)"));
  });

  testWidgets('fan keeps select at the same touch position after closing',
      (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selected = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(
        child: ZamerKitFan(
          contextId: 'plan.idle',
          first: const ZamerKitCommand('wall','Стена',
            Icons.border_outer_rounded),
          second: const ZamerKitCommand('opening','Проём',
            Icons.door_front_door_outlined),
          outer: const [
            ZamerKitCommand('measure','Измерить',Icons.straighten_outlined),
          ],
          onCommand: selected.add,
        ),
      )),
    ));
    await tester.pump();
    final topLeft = tester.getTopLeft(find.byType(ZamerKitFan));
    // Right-hand geometry is specified in kit dp, not physical screen px.
    await tester.tapAt(topLeft + const Offset(188, 188));
    await tester.pumpAndSettle();
    await tester.tapAt(topLeft + const Offset(119, 188));
    await tester.pumpAndSettle();
    expect(selected, ['select']);
    expect(tester.takeException(), isNull);
  });
}
