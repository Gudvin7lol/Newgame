import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/floor_3d_screen.dart';
import 'package:zamer_app/screens/layouts_screen.dart';
import 'package:zamer_app/screens/planning_objects_screen.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/widgets/floor_layout_painter.dart';

FloorPlan squareRoom() {
  final floor = FloorPlan(id: 'test-floor', name: 'Этаж');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 3000, yMm: 0),
    PlanNode(id: 'c', xMm: 3000, yMm: 3000),
    PlanNode(id: 'd', xMm: 0, yMm: 3000),
  ]);
  floor.walls.addAll([
    PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b', thicknessMm: 100),
    PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c', thicknessMm: 100),
    PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd', thicknessMm: 100),
    PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a', thicknessMm: 100),
  ]);
  GeometryService.syncRoomMetadata(floor);
  return floor;
}

void main() {
  testWidgets('floor layout moves by touch and center alignment is reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = squareRoom();
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutsScreen(
            floor: floor,
            onChanged: () async {
              saves++;
            },
          ),
        ),
      ),
    );
    final s = floor.roomMetas.first.materials;
    final preview = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is FloorLayoutPainter,
    );
    expect(preview, findsOneWidget);
    expect(find.textContaining('1380×193'), findsOneWidget);
    final center = tester.getCenter(preview);
    await tester.dragFrom(center, const Offset(65, 30));
    await tester.pump();
    expect(
      s.laminateOffsetXMm.abs() + s.laminateOffsetYMm.abs(),
      greaterThan(0),
    );
    expect(s.laminateOffsetXMm.abs(), lessThan(s.laminatePlankLengthMm));
    expect(s.laminateOffsetYMm.abs(), lessThan(s.laminatePlankWidthMm));
    expect(saves, greaterThan(0));
    final align = find.text('От центра');
    await tester.ensureVisible(align);
    await tester.tap(align);
    await tester.pump();
    await tester.tap(find.text('Подложка'));
    await tester.pump();
    await tester.dragFrom(tester.getCenter(preview), const Offset(-50, 20));
    await tester.pump();
    expect(s.underlayOffsetXMm.abs(), lessThan(s.underlayRollWidthMm));
    await tester.tap(find.text('Плитка'));
    await tester.pump();
    s.tileOffsetXMm = -9745;
    s.tileOffsetYMm = 13659;
    await tester.dragFrom(tester.getCenter(preview), const Offset(40, -30));
    await tester.pump();
    expect(s.tileOffsetXMm.abs(), lessThan(s.tileWidthMm));
    expect(s.tileOffsetYMm.abs(), lessThan(s.tileHeightMm));
    final balance = find.text('Без узких подрезок');
    await tester.ensureVisible(balance);
    await tester.tap(balance);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'one objects screen adds then moves an object without camera drift',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final floor = squareRoom();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanningObjectsScreen(floor: floor, onChanged: () async {}),
          ),
        ),
      );
      expect(find.text('Объекты: добавление и перемещение'), findsOneWidget);
      final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter != null,
      );
      final point = tester.getCenter(canvas.last);
      await tester.tapAt(point);
      await tester.pump();
      expect(floor.planObjects, hasLength(1));
      final firstX = floor.planObjects.first.xMm;
      await tester.dragFrom(point, const Offset(45, 0));
      await tester.pump();
      expect(floor.planObjects.first.xMm, greaterThan(firstX + 100));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('3D scene survives one- and two-pointer camera gestures', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Floor3DScreen(floor: squareRoom())),
      ),
    );
    final scene = find.byType(Floor3DScreen);
    final point = tester.getCenter(scene) - const Offset(0, 100);
    final one = await tester.startGesture(point);
    await one.moveBy(const Offset(20, 10));
    final two = await tester.startGesture(point + const Offset(50, 0));
    await one.moveBy(const Offset(-15, 5));
    await two.moveBy(const Offset(30, 5));
    await two.up();
    await one.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('small laminate format and herringbone with openings render', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final floor = squareRoom();
    final settings = floor.roomMetas.first.materials
      ..laminatePlankLengthMm = 100
      ..laminatePlankWidthMm = 40;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutsScreen(floor: floor, onChanged: () async {}),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    settings.laminatePattern = 'herringbone';
    floor.walls.first.openings.add(
      WallOpening(
        id: 'door',
        type: OpeningType.door,
        widthMm: 800,
        heightMm: 2100,
        offsetFromStartMm: 400,
      ),
    );
    floor.walls[1].openings.add(
      WallOpening(
        id: 'window',
        type: OpeningType.window,
        widthMm: 1200,
        heightMm: 1300,
        offsetFromStartMm: 500,
        sillHeightMm: 850,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Floor3DScreen(floor: floor)),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
