import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/measure_plan_tool.dart';
import 'package:zamer_app/screens/measure_unified_workspace_screen.dart';
import 'package:zamer_app/widgets/zamer_ui_kit_v2.dart';

void main() {
  test('production Home project route actually hosts native UI Kit 1.2', () {
    final home =
        File('lib/screens/production_home_screen.dart').readAsStringSync();
    final floor =
        File('lib/screens/floor_workspace_screen.dart').readAsStringSync();
    final live =
        File('lib/screens/measure_unified_workspace_screen.dart')
            .readAsStringSync();
    expect(home, contains('builder: (_) => FloorWorkspaceScreen('));
    expect(floor, contains('return MeasureUnifiedWorkspaceScreen('));
    expect(live, contains('ZamerKitFan('));
    expect(live, contains("ValueKey('zamer-live-native-v2-fan')"));
    expect(live, contains('_kitDomains()'));
    expect(live, contains('_kitTasks()'));
    expect(live, isNot(contains('if (_layer == 0) _planToolbar()')));
    expect(live, contains('singleFurnitureView: true'));
    expect(ZamerKitNavigation.categories(2), ['Мебель']);
  });

  testWidgets('actual Measure workspace displays fan and furniture-only task',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final floor = FloorPlan(id: 'f', name: 'Этаж 1');
    final project = MeasureProject(
      id: 'p', name: 'Квартира', floors: [floor]);
    final request = ValueNotifier<MeasurePlanTool>(MeasurePlanTool.overview);
    addTearDown(request.dispose);

    await tester.pumpWidget(MaterialApp(
      home: MeasureUnifiedWorkspaceScreen(
        project: project,
        floor: floor,
        onChanged: () async {},
        onUndo: null,
        onRedo: null,
        canUndo: false,
        canRedo: false,
        onMore: () {},
        onOpen3D: () {},
        onOpenPhoto: () {},
        onOpenReview: () {},
        planToolRequest: request,
        onOpenFloors: () {},
        onOpenRooms: () {},
        onScanPlan: () {},
        onExportPdf: () {},
        onHome: () {},
        onCatalog: () {},
        onProfile: () {},
        onPrimaryMode: (_) {},
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('zamer-live-native-v2-fan')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('kit-v2-tasks')), findsOneWidget);
    expect(find.text('Обзор'), findsNothing);
    expect(find.text('Перегородки'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('kit-v2-domain-2')));
    await tester.pump();
    expect(find.text('Мебель'), findsOneWidget);
    expect(find.text('Кухня'), findsNothing);
    expect(find.text('Сантехника'), findsNothing);
    expect(find.text('Декор'), findsNothing);
    expect(find.byKey(const ValueKey('zamer-live-native-v2-fan')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
