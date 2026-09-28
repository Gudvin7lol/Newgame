import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/geometry_service.dart';
import 'package:zamer_app/services/report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'PDF includes engineering and estimate sheets without sharing',
    () async {
      final floor = FloorPlan(id: 'f', name: 'Этаж 1');
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
      floor.roomMetas.single.heating.enabled = true;
      floor.serviceRuns.add(
        ServiceRun(
          id: 'r',
          type: ServiceRunType.drain,
          points: [ServiceVertex(0, 0), ServiceVertex(3000, 0)],
        ),
      );
      final project = MeasureProject(
        id: 'p',
        name: 'Квартира',
        floors: [floor],
      );
      final pdf = await ReportService.buildFloorPdf(project, floor);
      expect(pdf.length, greaterThan(15000));
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    },
  );
}
