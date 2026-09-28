import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/layout_service.dart';

void main() {
  test('new radius wall keeps one curve group and can be smoothed for 3D', () {
    final f = FloorPlan(id: 'f', name: 'F');
    f.nodes.add(PlanNode(id: 'a', xMm: 0, yMm: 0));
    GeometryService.addArcWallFromNode(
      f,
      startNodeId: 'a',
      endPoint: const math.Point<double>(4000, 0),
      sagittaMm: 1000,
      type: WallType.exterior,
      thicknessMm: 300,
      material: WallMaterial.gasBlock,
    );
    final ids = f.walls.map((w) => w.curveGroupId).whereType<String>().toSet();
    expect(ids.length, 1);
    expect(f.walls.every((w) => w.curveGroupId == ids.first), isTrue);
    final smooth = GeometryService.smoothCurvePoints(f, ids.first, stepMm: 55);
    expect(smooth.length, greaterThan(f.walls.length));
  });

  test('curve segments appear as one elevation run', () {
    final f = FloorPlan(id: 'f', name: 'F');
    f.nodes.add(PlanNode(id: 'a', xMm: 0, yMm: 0));
    GeometryService.addArcWallFromNode(
      f,
      startNodeId: 'a',
      endPoint: const math.Point<double>(3000, 0),
      sagittaMm: 700,
      type: WallType.exterior,
      thicknessMm: 300,
      material: WallMaterial.gasBlock,
    );
    final edges = <FaceEdge>[];
    String current = 'a';
    final remaining = [...f.walls];
    while (remaining.isNotEmpty) {
      final i = remaining.indexWhere((w) => w.startNodeId == current || w.endNodeId == current);
      if (i < 0) break;
      final w = remaining.removeAt(i);
      final next = w.startNodeId == current ? w.endNodeId : w.startNodeId;
      edges.add(FaceEdge(wallId: w.id, fromNodeId: current, toNodeId: next));
      current = next;
    }
    final face = RoomFace(
      key: 'fake',
      nodeIds: edges.map((e) => e.fromNodeId).toList(),
      edges: edges,
      innerPolygon: const [math.Point<double>(0, 0), math.Point<double>(1, 0), math.Point<double>(1, 1)],
      signedAreaMm2: 1,
    );
    final runs = GeometryService.elevationRuns(f, face);
    expect(runs.length, 1);
    expect(runs.first.isCurved, isTrue);
    expect(runs.first.lengthMm, greaterThan(3000));
  });

  test('tile auto balance avoids a thin 50 mm edge strip in a 3100 mm room', () {
    final face = RoomFace(
      key: 'r',
      nodeIds: const ['a', 'b', 'c', 'd'],
      edges: const [],
      innerPolygon: const [
        math.Point<double>(0, 0),
        math.Point<double>(3100, 0),
        math.Point<double>(3100, 3100),
        math.Point<double>(0, 3100),
      ],
      signedAreaMm2: 9610000,
    );
    final settings = RoomMaterialSettings(tileWidthMm: 600, tileHeightMm: 600);
    final best = LayoutService.balancedTileOffset(face, settings);
    final nonZeroCuts = [best.cuts.leftMm, best.cuts.rightMm, best.cuts.topMm, best.cuts.bottomMm].where((v) => v > 0.5).toList();
    expect(nonZeroCuts.reduce((a, b) => math.min(a, b).toDouble()), greaterThan(250));
  });

  test('layout offsets and curve metadata survive json round trip', () {
    final s = RoomMaterialSettings(tileOffsetXMm: 123, tileOffsetYMm: -45, tileMinCutMm: 150);
    final copy = RoomMaterialSettings.fromJson(s.toJson());
    expect(copy.tileOffsetXMm, 123);
    expect(copy.tileOffsetYMm, -45);
    expect(copy.tileMinCutMm, 150);

    final w = PlanWall(
      id: 'w',
      startNodeId: 'a',
      endNodeId: 'b',
      curveGroupId: 'arc-1',
      curveRadiusMm: 2500,
      curveSagittaMm: 600,
      curveArcLengthMm: 3300,
    );
    final wc = PlanWall.fromJson(w.toJson());
    expect(wc.curveGroupId, 'arc-1');
    expect(wc.curveRadiusMm, 2500);
  });
}
