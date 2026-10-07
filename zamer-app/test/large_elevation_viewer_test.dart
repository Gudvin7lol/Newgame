import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/widgets/large_elevation_viewer.dart';

void main() {
  testWidgets('large elevation separates navigation from tile drag', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final floor = FloorPlan(id: 'f', name: 'F');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 3000, yMm: 0),
      PlanNode(id: 'c', xMm: 3000, yMm: 3000),
      PlanNode(id: 'd', xMm: 0, yMm: 3000),
    ]);
    floor.walls.addAll([
      PlanWall(id: 'ab', startNodeId: 'a', endNodeId: 'b'),
      PlanWall(id: 'bc', startNodeId: 'b', endNodeId: 'c'),
      PlanWall(id: 'cd', startNodeId: 'c', endNodeId: 'd'),
      PlanWall(id: 'da', startNodeId: 'd', endNodeId: 'a'),
    ]);
    GeometryService.syncRoomMetadata(floor);
    final face = GeometryService.roomFaces(floor).single;
    final run = GeometryService.elevationRuns(floor, face).first;
    final settings = floor.roomMetas.first.materials..wallTile = true;
    final height = GeometryService.roomHeightMm(floor, face);
    var changed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LargeElevationViewer(
          floor: floor,
          face: face,
          run: run,
          heightMm: height,
          settings: settings,
          onChanged: () async => changed++,
        ),
      ),
    );

    expect(find.textContaining('Навигация:'), findsOneWidget);
    expect(find.byTooltip('Приблизить'), findsOneWidget);
    expect(find.byTooltip('Вписать в экран'), findsOneWidget);

    final before = settings.wallTileXFor(run.id);
    await tester.tap(find.byKey(const ValueKey('large-elevation-edit-mode')));
    await tester.pump();
    expect(find.textContaining('Плитка:'), findsOneWidget);

    final canvas = find.byKey(ValueKey('large-elevation-canvas-${run.id}'));
    expect(canvas, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(canvas));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect((settings.wallTileXFor(run.id) - before).abs(), greaterThan(1));
    expect(changed, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey('large-elevation-edit-mode')));
    await tester.pump();
    expect(find.textContaining('Навигация:'), findsOneWidget);
  });
}
