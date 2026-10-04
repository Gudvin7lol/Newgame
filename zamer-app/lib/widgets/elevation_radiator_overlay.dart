import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/equipment_placement_service.dart';
import '../services/geometry_service.dart';

/// Draws wall-bound radiators which historically were catalogued as floor
/// objects. Their XY placement is still the same project geometry used by the
/// plan and 3D scene; this overlay only projects it into the wall elevation.
class ElevationRadiatorOverlayPainter extends CustomPainter {
  const ElevationRadiatorOverlayPainter({
    required this.floor,
    required this.face,
    required this.run,
    required this.heightMm,
  });

  final FloorPlan floor;
  final RoomFace face;
  final ElevationRun run;
  final double heightMm;

  @override
  void paint(Canvas canvas, Size size) {
    if (run.lengthMm <= 0 || heightMm <= 0) return;
    final horizontalMargin = math.min(38.0, size.width * .09);
    final verticalMargin = math.min(34.0, size.height * .12);
    final scale = math.min(
      (size.width - horizontalMargin * 2) / run.lengthMm,
      (size.height - verticalMargin * 2) / heightMm,
    );
    if (!scale.isFinite || scale <= 0) return;
    final drawW = run.lengthMm * scale;
    final drawH = heightMm * scale;
    final rect = Rect.fromLTWH(
      (size.width - drawW) / 2,
      (size.height - drawH) / 2,
      drawW,
      drawH,
    );

    for (final object in floor.planObjects) {
      if (object.type != PlanObjectType.radiator ||
          object.layer == ProjectLayer.demolition) {
        continue;
      }
      final mount = EquipmentPlacementService.wallMountForObject(
        floor: floor,
        object: object,
      );
      if (mount == null) continue;

      var accumulated = 0.0;
      FaceEdge? activeEdge;
      for (final edge in run.edges) {
        if (edge.wallId == mount.wallId) {
          activeEdge = edge;
          break;
        }
        accumulated += GeometryService.wallFaceLengthMm(face, edge);
      }
      if (activeEdge == null) continue;
      final wall = floor.wallById(activeEdge.wallId);
      if (wall == null) continue;
      final insideSide = activeEdge.fromNodeId == wall.startNodeId ? 1 : -1;
      if (mount.wallSide != insideSide) continue;

      var wallOffset = mount.wallOffsetMm;
      if (activeEdge.fromNodeId != wall.startNodeId) {
        wallOffset = floor.wallLengthMm(wall) - wallOffset;
      }
      wallOffset -= GeometryService.wallFaceStartShiftMm(
        floor,
        face,
        activeEdge,
      );
      final totalOffset = accumulated + wallOffset;
      if (totalOffset < 0 || totalOffset > run.lengthMm) continue;

      final x = rect.left + totalOffset * scale;
      final w = math.max(10.0, object.widthMm * scale);
      final h = math.max(10.0, object.heightMm * scale);
      final top = rect.bottom - (object.elevationMm + object.heightMm) * scale;
      final radiatorRect = Rect.fromLTWH(x - w / 2, top, w, h);
      final stroke = Paint()
        ..color = ZamerColors.info
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(radiatorRect, const Radius.circular(3)),
        Paint()..color = ZamerColors.info.withValues(alpha: .10),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(radiatorRect, const Radius.circular(3)),
        stroke,
      );
      final sections = math.max(3, (object.widthMm / 110).round());
      for (var i = 1; i < sections; i++) {
        final sx = radiatorRect.left + radiatorRect.width * i / sections;
        canvas.drawLine(
          Offset(sx, radiatorRect.top + 2),
          Offset(sx, radiatorRect.bottom - 2),
          Paint()
            ..color = ZamerColors.info.withValues(alpha: .55)
            ..strokeWidth = .8,
        );
      }
      _label(
        canvas,
        object.label.isEmpty ? 'Радиатор' : object.label,
        Offset(radiatorRect.center.dx, radiatorRect.top - 8),
      );
      _label(
        canvas,
        '+${object.elevationMm.round()} мм',
        Offset(radiatorRect.right + 24, radiatorRect.bottom),
      );
    }
  }

  void _label(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: ZamerColors.textPrimary,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    final box = Rect.fromCenter(
      center: center,
      width: painter.width + 7,
      height: painter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(3)),
      Paint()..color = ZamerColors.surfaceLow.withValues(alpha: .92),
    );
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant ElevationRadiatorOverlayPainter oldDelegate) =>
      true;
}
