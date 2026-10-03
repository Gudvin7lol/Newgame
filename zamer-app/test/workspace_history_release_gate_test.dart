import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/rooms_screen.dart';
import 'package:zamer_app/services/geometry_service.dart';

void main() {
  test('release gate: Measure workspace exposes the real Rooms route', () {
    final source =
        File('lib/screens/floor_workspace_screen.dart').readAsStringSync();
    expect(source.contains('Future<void> _openRooms()'), isTrue);
    expect(source.contains("title: 'Помещения'"), isTrue);
    expect(source.contains('_openRooms();'), isTrue);
    expect(
      source.contains('RoomsScreen(floor: widget.floor, onChanged: _changed)'),
      isTrue,
    );
  });

  testWidgets('release gate: Rooms edits and persists room properties', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final floor = FloorPlan(id: 'f', name: 'Этаж');
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
    var saves = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomsScreen(
            floor: floor,
            onChanged: () async {
              saves++;
            },
          ),
        ),
      ),
    );

    expect(find.text('Помещение 1'), findsOneWidget);
    await tester.tap(find.text('Помещение 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Название'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Кабинет');
    await tester.tap(find.text('Сохранить').last);
    await tester.pumpAndSettle();

    expect(floor.roomMetas.single.name, 'Кабинет');
    expect(saves, greaterThan(0));
    expect(find.text('Кабинет'), findsWidgets);
  });
}
