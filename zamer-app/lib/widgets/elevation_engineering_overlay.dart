import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';

/// Projects plan-based engineering vertices onto the selected wall elevation.
///
/// Route XY remains the source of truth. Until service vertices get their own
/// Z coordinate, standard installation levels are used per system.
class ElevationEngineeringOverlayPainter extends CustomPainter {
  const ElevationEngineeringOverlayPainter({
    required this.floor,
    required this.face,
    required this.run,
    required this.heightMm,
  });

  final FloorPlan floor;
  final RoomFace face;
  final ElevationRun run;
  final double heightMm;

  double _level(ServiceRunType type) => switch (type) {
        ServiceRunType.drain => 180,
        ServiceRunType.coldWater => 350,
        ServiceRunType.hotWater => 450,
        ServiceRunType.heating => 550,
      };

  Color _color(ServiceRunType type) => switch (type) {
        ServiceRunType.coldWater => Colors.lightBlueAccent,
        ServiceRunType.hotWater => Colors.redAccent,
        ServiceRunType.drain => Colors.brown.shade300,
        ServiceRunType.heating => Colors.orangeAccent,
      };

  String _short(ServiceRunType type) => switch (type) {
        ServiceRunType.coldWater => 'ХВС',
        ServiceRunType.hotWater => 'ГВС',
        ServiceRunType.drain => 'КАН',
        ServiceRunType.heating => 'ОТ',
      };

  _ProjectedServicePoint? _project(ServiceVertex vertex, Size size) {
    if (run.lengthMm <= 0 || heightMm <= 0) return null;
    final hit = GeometryService.nearestWallProjection(
      floor,
      math.Point<double>(vertex.xMm, vertex.yMm),
      thresholdMm: 320,
    );
    if (hit == null) return null;

    FaceEdge? edge;
    var accumulated = 0.0;
    for (final candidate in run.edges) {
      if (candidate.wallId == hit.wall.id) {
        edge = candidate;
        break;
      }
      accumulated += GeometryService.wallFaceLengthMm(face, candidate);
    }
    if (edge == null) return null;

    final wall = floor.wallById(edge.wallId);
    if (wall == null) return null;
    final a = floor.nodeById(wall.startNodeId);
    final b = floor.nodeById(wall.endNodeId);
    if (a == null || b == null) return null;
    final dx = b.xMm - a.xMm;
    final dy = b.yMm - a.yMm;
    final wallLength = math.sqrt(dx * dx + dy * dy);
    if (wallLength < 1) return null;

    final t = (((hit.point.x - a.xMm) * dx +
                (hit.point.y - a.yMm) * dy) /
            (wallLength * wallLength))
        .clamp(0.0, 1.0)
        .toDouble();
    var offset = t * wallLength;
    if (edge.fromNodeId != wall.startNodeId) offset = wallLength - offset;
    offset -= GeometryService.wallFaceStartShiftMm(floor, face, edge);
    final totalOffset = accumulated + offset;
    if (totalOffset < -20 || totalOffset > run.lengthMm + 20) return null;

    final horizontalMargin = math.min(38.0, size.width * .09);
    final verticalMargin = math.min(34.0, size.height * .12);
    final scale = math.min(
      (size.width - horizontalMargin * 2) / run.lengthMm,
      (size.height - verticalMargin * 2) / heightMm,
    );
    if (!scale.isFinite || scale <= 0) return null;
    final drawW = run.lengthMm * scale;
    final drawH = heightMm * scale;
    final rect = Rect.fromLTWH(
      (size.width - drawW) / 2,
      (size.height - drawH) / 2,
      drawW,
      drawH,
    );
    return _ProjectedServicePoint(
      x: rect.left + totalOffset * scale,
      offsetMm: totalOffset.clamp(0.0, run.lengthMm).toDouble(),
      rect: rect,
      scale: scale,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final service in floor.serviceRuns) {
      final level = _level(service.type).clamp(0, heightMm).toDouble();
      final color = _color(service.type);
      _ProjectedServicePoint? previous;
      for (final vertex in service.points) {
        final projected = _project(vertex, size);
        if (projected == null) {
          previous = null;
          continue;
        }
        final y = projected.rect.bottom - level * projected.scale;
        final center = Offset(projected.x, y);
        if (previous != null) {
          final previousY = previous.rect.bottom - level * previous.scale;
          canvas.drawLine(
            Offset(previous.x, previousY),
            center,
            Paint()
              ..color = color.withValues(alpha: .72)
              ..strokeWidth = 2.4,
          );
        }
        canvas.drawLine(
          Offset(center.dx, projected.rect.bottom),
          center,
          Paint()
            ..color = color.withValues(alpha: .26)
            ..strokeWidth = 1,
        );
        canvas.drawCircle(center, 6, Paint()..color = ZamerColors.surfaceLow);
        canvas.drawCircle(
          center,
          5,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        _badge(
          canvas,
          Offset(center.dx, center.dy - 17),
          '${_short(service.type)} ${projected.offsetMm.round()} / +${level.round()}',
          color,
        );
        previous = projected;
      }
    }
  }

  void _badge(Canvas canvas, Offset center, String text, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: center,
      width: painter.width + 8,
      height: painter.height + 5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = ZamerColors.surfaceLow.withValues(alpha: .94),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = color.withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant ElevationEngineeringOverlayPainter oldDelegate) =>
      true;
}

class _ProjectedServicePoint {
  const _ProjectedServicePoint({
    required this.x,
    required this.offsetMm,
    required this.rect,
    required this.scale,
  });

  final double x;
  final double offsetMm;
  final Rect rect;
  final double scale;
}
