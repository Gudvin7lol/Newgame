import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/elevations_screen.dart';
import 'package:zamer_app/services/geometry_service.dart';

void main() {
  testWidgets('wall tile drag does not turn the wall page', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
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
    floor.roomMetas.first.materials.wallTile = true;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ElevationsScreen(
      floor: floor, onChanged: () async {},
    ))));
    final run = GeometryService.elevationRuns(floor,
      GeometryService.roomFaces(floor).single).first;
    final dragSurface = find.byKey(ValueKey('elevation-preview-${run.id}'));
    expect(dragSurface, findsOneWidget);
    // The richer v1.5.4 elevation header can place the preview below the first
    // viewport on a phone-sized test surface. Scroll the actual opaque gesture
    // surface into view, then drag that surface rather than the passive paint
    // child. This matches how a finger hits the preview on a real device.
    await tester.ensureVisible(dragSurface);
    await tester.pumpAndSettle();
    final before = floor.roomMetas.first.materials.wallTileXFor(run.id);
    final gesture = await tester.startGesture(tester.getCenter(dragSurface));
    // First movement crosses the horizontal drag slop; the second one must be
    // delivered as a real horizontal-drag update to the preview.
    await gesture.moveBy(const Offset(64, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(64, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    final after = floor.roomMetas.first.materials.wallTileXFor(run.id);
    expect((after - before).abs(), greaterThan(1));
    expect(find.text('Стена 1 из 4'), findsOneWidget);
    await tester.tap(find.byTooltip('Следующая стена'));
    await tester.pumpAndSettle();
    expect(find.text('Стена 2 из 4'), findsOneWidget);
  });
}
