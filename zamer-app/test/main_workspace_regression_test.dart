import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/plan_editor_master_v4_screen.dart';

FloorPlan _room({bool withObject = false}) {
  final floor = FloorPlan(
    id: 'f1',
    name: 'Этаж 1',
    nodes: [
      PlanNode(id: 'n1', xMm: 0, yMm: 0),
      PlanNode(id: 'n2', xMm: 4000, yMm: 0),
      PlanNode(id: 'n3', xMm: 4000, yMm: 4000),
      PlanNode(id: 'n4', xMm: 0, yMm: 4000),
    ],
    walls: [
      PlanWall(id: 'w1', startNodeId: 'n1', endNodeId: 'n2'),
      PlanWall(id: 'w2', startNodeId: 'n2', endNodeId: 'n3'),
      PlanWall(id: 'w3', startNodeId: 'n3', endNodeId: 'n4'),
      PlanWall(id: 'w4', startNodeId: 'n4', endNodeId: 'n1'),
    ],
  );
  if (withObject) {
    floor.planObjects.add(
      PlanObject(
        id: 'o1',
        type: PlanObjectType.furniture,
        xMm: 2000,
        yMm: 2000,
        widthMm: 600,
        depthMm: 600,
        heightMm: 800,
      ),
    );
  }
  return floor;
}

Widget _editor(FloorPlan floor) => MaterialApp(
      home: Scaffold(
        body: PlanEditorMasterV4Screen(
          floor: floor,
          onChanged: () async {},
          onOpenObjects: () {},
          onOpenReview: () {},
          onOpenGeometry: () {},
          onOpen3D: () {},
          onOpenFloors: () {},
          onOpenSettings: () {},
          onOpenMaterials: () {},
          onUndo: null,
          onRedo: null,
          canUndo: false,
          canRedo: false,
        ),
      ),
    );

void main() {
  test('project cards open workspace directly and master sections stay reachable', () {
    final home = File('lib/screens/home_concept_screen.dart').readAsStringSync();
    final measure = File(
      'lib/screens/measure_concept_workspace_screen.dart',
    ).readAsStringSync();
    expect(home, contains('builder: (_) => FloorWorkspaceScreen('));
    expect(home, isNot(contains('builder: (_) => FloorsScreen(')));
    expect(measure, contains('ZWorkspacePrimaryNav('));
    expect(measure, contains('onPrimaryModeSelected'));
  });

  testWidgets('furniture moves directly on the main measure canvas', (tester) async {
    final floor = _room(withObject: true);
    await tester.pumpWidget(_editor(floor));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final handle = find.byKey(const ValueKey('direct-object:o1'));
    expect(handle, findsOneWidget);
    final before = floor.planObjects.single.xMm;
    await tester.drag(handle, const Offset(48, 0));
    await tester.pumpAndSettle();
    expect(floor.planObjects.single.xMm, greaterThan(before));
  });

  testWidgets('selected floor layout can be dragged on the main measure canvas',
      (tester) async {
    final floor = _room();
    await tester.pumpWidget(_editor(floor));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final viewer = find.byType(InteractiveViewer);
    expect(viewer, findsOneWidget);
    await tester.tapAt(tester.getCenter(viewer));
    await tester.pump();

    expect(floor.roomMetas, isNotEmpty);
    final settings = floor.roomMetas.first.materials;
    final beforeX = settings.laminateOffsetXMm;
    final beforeY = settings.laminateOffsetYMm;
    final handle = find.byKey(
      ValueKey('direct-layout:${floor.roomMetas.first.id}'),
    );
    expect(handle, findsOneWidget);
    await tester.drag(handle, const Offset(36, 24));
    await tester.pumpAndSettle();
    expect(
      settings.laminateOffsetXMm != beforeX ||
          settings.laminateOffsetYMm != beforeY,
      isTrue,
    );
  });
}
