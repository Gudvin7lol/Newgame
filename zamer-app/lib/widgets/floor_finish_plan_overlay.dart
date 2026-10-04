import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';

/// Renders the active floor finish directly inside measured room polygons.
/// Geometry remains the source of truth; this is only a visual/editing layer.
class FloorFinishPlanOverlayPainter extends CustomPainter {
  const FloorFinishPlanOverlayPainter({
    required this.floor,
    required this.mmToPx,
    required this.origin,
    this.selectedFaceKey,
  });

  final FloorPlan floor;
  final double mmToPx;
  final Offset origin;
  final String? selectedFaceKey;

  Offset _toCanvas(math.Point<double> p) =>
      origin + Offset(p.x * mmToPx, p.y * mmToPx);

  Path _roomPath(RoomFace face) {
    final path = Path();
    if (face.innerPolygon.isEmpty) return path;
    final first = _toCanvas(face.innerPolygon.first);
    path.moveTo(first.dx, first.dy);
    for (final point in face.innerPolygon.skip(1)) {
      final p = _toCanvas(point);
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final faces = GeometryService.roomFaces(floor);
    for (final face in faces) {
      final meta = floor.roomMetaByKey(face.key);
      if (meta == null) continue;
      final settings = meta.materials;
      final path = _roomPath(face);
      final bounds = path.getBounds();
      if (bounds.isEmpty) continue;

      final preset = MaterialCatalog.byId(settings.floorMaterialId);
      final selected = face.key == selectedFaceKey;
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(
        path,
        Paint()..color = preset.color.withValues(alpha: selected ? .28 : .16),
      );

      final angle = settings.floorDirectionDeg * math.pi / 180;
      final spacingMm = settings.floorMode == 'tile'
          ? math.max(80.0, settings.tileWidthMm)
          : math.max(70.0, settings.laminatePlankWidthMm);
      final spacing = math.max(8.0, spacingMm * mmToPx);
      final linePaint = Paint()
        ..color = ZamerColors.textMuted.withValues(alpha: selected ? .62 : .36)
        ..strokeWidth = selected ? 1.0 : .7;

      canvas.save();
      canvas.translate(bounds.center.dx, bounds.center.dy);
      canvas.rotate(angle);
      canvas.translate(-bounds.center.dx, -bounds.center.dy);

      final extent = math.max(bounds.width, bounds.height) * 2.2;
      if (settings.floorMode == 'tile') {
        final tileH = math.max(8.0, settings.tileHeightMm * mmToPx);
        for (double x = bounds.left - extent; x <= bounds.right + extent; x += spacing) {
          canvas.drawLine(
            Offset(x, bounds.top - extent),
            Offset(x, bounds.bottom + extent),
            linePaint,
          );
        }
        for (double y = bounds.top - extent; y <= bounds.bottom + extent; y += tileH) {
          canvas.drawLine(
            Offset(bounds.left - extent, y),
            Offset(bounds.right + extent, y),
            linePaint,
          );
        }
      } else if (settings.laminatePattern == 'herringbone') {
        final step = math.max(10.0, settings.laminatePlankWidthMm * mmToPx * 1.4);
        for (double d = -extent; d <= extent; d += step) {
          canvas.drawLine(
            Offset(bounds.center.dx - extent, bounds.center.dy + d - extent),
            Offset(bounds.center.dx + extent, bounds.center.dy + d + extent),
            linePaint,
          );
          canvas.drawLine(
            Offset(bounds.center.dx - extent, bounds.center.dy + d + extent),
            Offset(bounds.center.dx + extent, bounds.center.dy + d - extent),
            linePaint,
          );
        }
      } else {
        for (double y = bounds.top - extent; y <= bounds.bottom + extent; y += spacing) {
          canvas.drawLine(
            Offset(bounds.left - extent, y),
            Offset(bounds.right + extent, y),
            linePaint,
          );
        }
        final plank = math.max(24.0, settings.laminatePlankLengthMm * mmToPx);
        var row = 0;
        for (double y = bounds.top - extent; y <= bounds.bottom + extent; y += spacing) {
          final shift = row.isOdd ? plank / 2 : 0.0;
          for (double x = bounds.left - extent + shift; x <= bounds.right + extent; x += plank) {
            canvas.drawLine(
              Offset(x, y - spacing / 2),
              Offset(x, y + spacing / 2),
              linePaint,
            );
          }
          row++;
        }
      }
      canvas.restore();
      canvas.restore();

      canvas.drawPath(
        path,
        Paint()
          ..color = selected ? ZamerColors.accent : ZamerColors.outlineSoft
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.2 : 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FloorFinishPlanOverlayPainter oldDelegate) => true;
}
