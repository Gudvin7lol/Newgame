import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/widgets/electrical_wall_elevation_screen.dart';

FloorPlan _floorWithDifferentWalls() {
  final floor = FloorPlan(id: 'f', name: 'Этаж 1',
    defaultHeightMm: 2700,
    nodes: [
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 3000, yMm: 0),
      PlanNode(id: 'c', xMm: 3000, yMm: 2700),
    ],
    walls: [
      PlanWall(id: 'empty', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'with-point', startNodeId: 'b', endNodeId: 'c'),
    ],
    electricalPoints: [
      ElectricalPoint(
        id: 'socket', type: ElectricalPointType.socket,
        xMm: 3000, yMm: 500, wallId: 'with-point',
        wallOffsetMm: 500, heightMm: 300,
        label: 'Розетка'),
    ],
  );
  return floor;
}

void main() {
  test('embedded electrical screen owns one fan and one task switcher',
      () {
    final shell = File('lib/screens/recovered_measure_workspace_screen.dart')
        .readAsStringSync();
    final editor = File('lib/screens/electrical_screen.dart')
        .readAsStringSync();
    expect(shell, contains('if (_layer < 3)\n            _kitTasks()'));
    expect(shell, contains('if (_layer < 3)\n                Positioned('));
    expect(editor, contains('electrical-three-modes'));
    expect(editor, contains('electrical-fan-add'));
    expect(editor, contains('electrical-selection-actions'));
    expect(editor, contains('_showPointActions(selected)'));
    expect(editor, contains('showModalBottomSheet<String>'));
    expect(editor, isNot(contains('_selectionActionsOpen')));
  });

  testWidgets('elevation selects a wall containing the electrical point',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = _floorWithDifferentWalls();
    await tester.pumpWidget(MaterialApp(
      home: ElectricalWallElevationScreen(floor: floor),
    ));
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('wall-elevation-wall-with-point')));
    expect(dropdown.initialValue, 'with-point');
    // Device tiles are intentionally lazy below the drawing; scroll the
    // page before asserting the row, not just the selected wall data.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('wall-elevation-device-socket')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('wall-elevation-device-socket')),
        findsOneWidget);
    expect(find.text('Розетка'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected wall overrides default, chart fits viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = _floorWithDifferentWalls();
    await tester.pumpWidget(MaterialApp(
      home: ElectricalWallElevationScreen(
        floor: floor, initialWallId: 'empty'),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wall-elevation-wall-empty')),
        findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Выбери другую стену'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Выбери другую стену'),
        findsWidgets);
    final drawing = tester.getSize(
        find.byKey(const ValueKey('wall-elevation-drawing')));
    expect(drawing.width, closeTo(362, 1));
    await tester.tap(find.byKey(
        const ValueKey('wall-elevation-zoom-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Вписать'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
