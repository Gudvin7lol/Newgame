import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/widgets/floor_layout_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'old invalid formats normalize before painting instead of hanging',
    () async {
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
      final json = floor.toJson();
      final materials = (json['roomMetas'] as List).first['materials'] as Map;
      materials['laminatePlankLengthMm'] = 0;
      materials['laminatePlankWidthMm'] = 1;
      materials['tileWidthMm'] = 0;
      materials['wallTileHeightMm'] = 0;
      materials['underlaySheetWidthMm'] = 0;
      final restored = FloorPlan.fromJson(json);
      final face = GeometryService.roomFaces(restored).single;
      final settings = restored.roomMetas.first.materials;
      expect(settings.laminatePlankLengthMm, 1380);
      expect(settings.laminatePlankWidthMm, 193);
      expect(settings.wallTileHeightMm, 300);
      for (final kind in FloorLayoutKind.values) {
        final recorder = ui.PictureRecorder();
        FloorLayoutPainter(
          face: face,
          settings: settings,
          kind: kind,
        ).paint(Canvas(recorder), const Size(500, 500));
        final picture = recorder.endRecording();
        final image = await picture.toImage(500, 500);
        image.dispose();
        picture.dispose();
      }
    },
  );
}
