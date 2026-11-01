import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/design_system/zamer_master_theme.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/electrical_screen.dart';
import 'package:zamer_app/services/electrical_datum_assignment_service.dart';
import 'package:zamer_app/services/electrical_dimension_edit.dart';
import 'package:zamer_app/services/electrical_mounting_service.dart';
import 'package:zamer_app/services/electrical_plan_dimension.dart';
import 'package:zamer_app/widgets/electrical_plan_painter.dart';
import 'electrical_mounting_test.dart' show mountingFixture, dimension;
import 'electrical_assigned_datums_p10_test.dart' show assignmentFixture, finishStart;

void main() {
  test('finished reference takes precedence over axis; stale data is explicit', () {
    final f = assignmentFixture();
    final point = f.electricalPoints.first;
    ElectricalDatumAssignmentService.apply(f, point.id,
      ElectricalDatumAssignmentService.prepare(f, point.id, 'w', 1, finishStart));
    final d = ElectricalPlanDimension.resolve(f, point)!;
    expect(d.finished, isTrue);
    expect(d.distanceMm, 572);
    expect(d.base, const Offset(1922, 262));
    expect(d.center, const Offset(1350, 262));
    expect(d.heightMm, 300);
    point.xMm += 10;
    expect(ElectricalPlanDimension.resolve(f, point)!.problem, isNotNull);
  });

  test('editing a finished size preserves base and validates without mutating', () {
    final f = assignmentFixture();
    final point = f.electricalPoints.first;
    ElectricalDatumAssignmentService.apply(f, point.id,
      ElectricalDatumAssignmentService.prepare(f, point.id, 'w', 1, finishStart));
    final before = jsonEncode(f.toJson());
    final next = ElectricalDimensionEdit.propose(f, point, finishStart, -600);
    expect(next.xMm, 1322);
    expect(next.datumAssignment!.fromDatumMm, -600);
    expect(next.heightMm, 300);
    expect(jsonEncode(f.toJson()), before);
    expect(() => ElectricalDimensionEdit.propose(f, point, finishStart, 100), throwsFormatException);
    expect(jsonEncode(f.toJson()), before);
  });

  test('axis references A/B and zoom retain exact millimetres and frame centre', () {
    final f = mountingFixture();
    final point = f.electricalPoints.first;
    point.type = ElectricalPointType.frame;
    point.modules..clear()..addAll([ElectricalModuleType.socket220, ElectricalModuleType.socket220]);
    for (final node in ['a', 'b']) {
      ElectricalMountingService.apply(f, point, dimension(f, node: node));
      final d = ElectricalPlanDimension.resolve(f, point)!;
      expect(d.distanceMm, 600);
      expect((d.base - d.center).distance, 600);
      for (final scale in [.05, .2, .6]) {
        final painter = ElectricalPlanPainter(floor: f, scale: scale,
          origin: Offset.zero, selectedPointId: point.id);
        final layout = painter.dimensionLayouts(const Size(390, 540)).single;
        expect(layout.distanceText, '600 мм');
        expect(layout.baseText, contains('центр рамки'));
        expect((layout.a - layout.b).distance, closeTo(600 * scale, .001));
        expect(layout.distanceRect.overlaps(layout.heightRect), isFalse);
        for (final rect in [layout.distanceRect, layout.heightRect, layout.baseRect]) {
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(390));
        }
      }
    }
  });

  testWidgets('390 dp fan and installation layer render without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = mountingFixture();
    ElectricalMountingService.apply(f, f.electricalPoints.first, dimension(f));
    await tester.pumpWidget(MaterialApp(theme: ZamerMasterTheme.dark,
      home: Scaffold(body: RepaintBoundary(key: const ValueKey('kit-preview'),
        child: ElectricalScreen(floor: f, onChanged: () async {})))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('electrical-plan-layers')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Монтажные размеры'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('electrical-fan-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('electrical-add-appliance')), findsOneWidget);
    expect(find.byKey(const ValueKey('electrical-fan-add')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('kit-preview')));
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/ui-kit-v5/electrical-390.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      } finally { image.dispose(); }
    });
  });
}
