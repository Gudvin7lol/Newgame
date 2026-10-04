import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/equipment_placement_service.dart';
import '../services/geometry_service.dart';

/// Draws a second, working dimension chain for live wall devices.
///
/// Openings are dimensioned by [ElevationPainter]. This overlay dimensions
/// electrical points, wall-bound objects/radiators and engineering vertices
/// using the exact same project geometry. Hidden layers disappear because the
/// production elevation passes a filtered FloorPlan copy into this painter.
class ElevationDimensionOverlayPainter extends CustomPainter {
  const ElevationDimensionOverlayPainter({
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
    final layout = _layout(size);
    if (layout == null) return;

    final anchors = <_DimensionAnchor>[];
    _collectElectrical(anchors);
    _collectObjects(anchors);
    _collectEngineering(anchors);
    if (anchors.isEmpty) return;

    anchors.sort((a, b) => a.offsetMm.compareTo(b.offsetMm));
    final compact = _compact(anchors);
    final chainY = math.min(size.height - 7, layout.rect.bottom + 31);

    final positions = <double>[0, ...compact.map((e) => e.offsetMm), run.lengthMm]
      ..sort();
    final unique = <double>[];
    for (final value in positions) {
      if (unique.isEmpty || (unique.last - value).abs() > 8) unique.add(value);
    }

    for (var i = 1; i < unique.length; i++) {
      final a = unique[i - 1];
      final b = unique[i];
      if (b - a < 1) continue;
      final x1 = layout.rect.left + a * layout.scale;
      final x2 = layout.rect.left + b * layout.scale;
      _segment(canvas, x1, x2, chainY, '${(b - a).round()}');
    }

    for (final anchor in compact) {
      final x = layout.rect.left + anchor.offsetMm * layout.scale;
      final pointY = layout.rect.bottom -
          anchor.heightMm.clamp(0, heightMm).toDouble() * layout.scale;
      canvas.drawLine(
        Offset(x, pointY),
        Offset(x, chainY - 5),
        Paint()
          ..color = anchor.color.withValues(alpha: .34)
          ..strokeWidth = .9,
      );
      canvas.drawCircle(
        Offset(x, chainY),
        2.6,
        Paint()..color = anchor.color,
      );
      _tag(
        canvas,
        Offset(x, chainY - 13),
        '${anchor.label} ${anchor.offsetMm.round()} / +${anchor.heightMm.round()}',
        anchor.color,
      );
    }
  }

  _ElevationLayout? _layout(Size size) {
    final horizontalMargin = math.min(38.0, size.width * .09);
    final verticalMargin = math.min(34.0, size.height * .12);
    final scale = math.min(
      (size.width - horizontalMargin * 2) / run.lengthMm,
      (size.height - verticalMargin * 2) / heightMm,
    );
    if (!scale.isFinite || scale <= 0) return null;
    final drawW = run.lengthMm * scale;
    final drawH = heightMm * scale;
    return _ElevationLayout(
      rect: Rect.fromLTWH(
        (size.width - drawW) / 2,
        (size.height - drawH) / 2,
        drawW,
        drawH,
      ),
      scale: scale,
    );
  }

  void _collectElectrical(List<_DimensionAnchor> result) {
    for (final point in floor.electricalPoints) {
      if (!point.isWallDevice || point.wallId == null) continue;
      final offset = _offsetOnRun(
        wallId: point.wallId!,
        wallOffsetMm: point.wallOffsetMm ?? 0,
        wallSide: point.wallSide,
        requireInsideSide: true,
      );
      if (offset == null) continue;
      result.add(
        _DimensionAnchor(
          offsetMm: offset,
          heightMm: point.heightMm,
          label: _electricalLabel(point),
          color: ZamerColors.warning,
        ),
      );
    }
  }

  void _collectObjects(List<_DimensionAnchor> result) {
    for (final object in floor.planObjects) {
      if (object.layer == ProjectLayer.demolition) continue;
      final mount = EquipmentPlacementService.wallMountForObject(
        floor: floor,
        object: object,
      );
      if (mount == null) continue;
      final offset = _offsetOnRun(
        wallId: mount.wallId,
        wallOffsetMm: mount.wallOffsetMm,
        wallSide: mount.wallSide,
        requireInsideSide: true,
      );
      if (offset == null) continue;
      result.add(
        _DimensionAnchor(
          offsetMm: offset,
          heightMm: object.elevationMm,
          label: object.type == PlanObjectType.radiator
              ? 'РАД'
              : object.type == PlanObjectType.lighting
                  ? 'СВЕТ'
                  : 'ОБ',
          color: object.type == PlanObjectType.radiator
              ? ZamerColors.info
              : ZamerColors.textPrimary,
        ),
      );
    }
  }

  void _collectEngineering(List<_DimensionAnchor> result) {
    for (final service in floor.serviceRuns) {
      for (final vertex in service.points) {
        final hit = GeometryService.nearestWallProjection(
          floor,
          math.Point<double>(vertex.xMm, vertex.yMm),
          thresholdMm: 320,
        );
        if (hit == null) continue;
        final offset = _offsetOnRun(
          wallId: hit.wall.id,
          wallOffsetMm: floor.wallLengthMm(hit.wall) * hit.t,
          wallSide: 1,
          requireInsideSide: false,
        );
        if (offset == null) continue;
        result.add(
          _DimensionAnchor(
            offsetMm: offset,
            heightMm: _engineeringLevel(service.type),
            label: _engineeringLabel(service.type),
            color: _engineeringColor(service.type),
          ),
        );
      }
    }
  }

  double? _offsetOnRun({
    required String wallId,
    required double wallOffsetMm,
    required int wallSide,
    required bool requireInsideSide,
  }) {
    var accumulated = 0.0;
    for (final edge in run.edges) {
      final segmentLength = GeometryService.wallFaceLengthMm(face, edge);
      if (edge.wallId != wallId) {
        accumulated += segmentLength;
        continue;
      }
      final wall = floor.wallById(edge.wallId);
      if (wall == null) return null;
      final insideSide = edge.fromNodeId == wall.startNodeId ? 1 : -1;
      if (requireInsideSide && wallSide != insideSide) return null;
      var offset = wallOffsetMm;
      if (edge.fromNodeId != wall.startNodeId) {
        offset = floor.wallLengthMm(wall) - offset;
      }
      offset -= GeometryService.wallFaceStartShiftMm(floor, face, edge);
      final total = accumulated + offset;
      if (total < -20 || total > run.lengthMm + 20) return null;
      return total.clamp(0.0, run.lengthMm).toDouble();
    }
    return null;
  }

  List<_DimensionAnchor> _compact(List<_DimensionAnchor> source) {
    final result = <_DimensionAnchor>[];
    for (final anchor in source) {
      if (result.isNotEmpty &&
          (result.last.offsetMm - anchor.offsetMm).abs() <= 18) {
        final previous = result.removeLast();
        result.add(
          _DimensionAnchor(
            offsetMm: (previous.offsetMm + anchor.offsetMm) / 2,
            heightMm: math.max(previous.heightMm, anchor.heightMm),
            label: '${previous.label}/${anchor.label}',
            color: previous.color,
          ),
        );
      } else {
        result.add(anchor);
      }
    }
    return result;
  }

  void _segment(
    Canvas canvas,
    double x1,
    double x2,
    double y,
    String text,
  ) {
    final paint = Paint()
      ..color = ZamerColors.textMuted
      ..strokeWidth = .9;
    canvas.drawLine(Offset(x1, y), Offset(x2, y), paint);
    canvas.drawLine(Offset(x1, y - 3), Offset(x1, y + 3), paint);
    canvas.drawLine(Offset(x2, y - 3), Offset(x2, y + 3), paint);
    final width = (x2 - x1).abs();
    if (width < 25) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: ZamerColors.textSecondary,
          fontSize: 7,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((x1 + x2 - painter.width) / 2, y + 2),
    );
  }

  void _tag(Canvas canvas, Offset center, String text, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 7,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    final rect = Rect.fromCenter(
      center: center,
      width: painter.width + 6,
      height: painter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = ZamerColors.surfaceLow.withValues(alpha: .92),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..color = color.withValues(alpha: .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6,
    );
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  String _electricalLabel(ElectricalPoint point) {
    if (point.label.trim().isNotEmpty) {
      final value = point.label.trim().toUpperCase();
      return value.length > 7 ? value.substring(0, 7) : value;
    }
    return switch (point.type) {
      ElectricalPointType.socket => 'РОЗ',
      ElectricalPointType.switchPoint => 'ВЫКЛ',
      ElectricalPointType.wallLight => 'БРА',
      ElectricalPointType.junctionBox => 'КР',
      ElectricalPointType.panel => 'ЩИТ',
      _ => 'ЭЛ',
    };
  }

  double _engineeringLevel(ServiceRunType type) => switch (type) {
        ServiceRunType.drain => 180,
        ServiceRunType.coldWater => 350,
        ServiceRunType.hotWater => 450,
        ServiceRunType.heating => 550,
      };

  String _engineeringLabel(ServiceRunType type) => switch (type) {
        ServiceRunType.coldWater => 'ХВС',
        ServiceRunType.hotWater => 'ГВС',
        ServiceRunType.drain => 'КАН',
        ServiceRunType.heating => 'ОТ',
      };

  Color _engineeringColor(ServiceRunType type) => switch (type) {
        ServiceRunType.coldWater => Colors.lightBlueAccent,
        ServiceRunType.hotWater => Colors.redAccent,
        ServiceRunType.drain => Colors.brown.shade300,
        ServiceRunType.heating => Colors.orangeAccent,
      };

  @override
  bool shouldRepaint(covariant ElevationDimensionOverlayPainter oldDelegate) =>
      true;
}

class _DimensionAnchor {
  const _DimensionAnchor({
    required this.offsetMm,
    required this.heightMm,
    required this.label,
    required this.color,
  });

  final double offsetMm;
  final double heightMm;
  final String label;
  final Color color;
}

class _ElevationLayout {
  const _ElevationLayout({required this.rect, required this.scale});

  final Rect rect;
  final double scale;
}
