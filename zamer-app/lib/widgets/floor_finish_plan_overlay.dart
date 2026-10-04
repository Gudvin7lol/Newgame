import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';

/// Highlights the active room on top of the measured CAD plan.
///
/// The base CAD painter already renders the actual floor finish from the same
/// RoomMaterialSettings used by 3D. This overlay only adds selection feedback,
/// material identity and installation direction so editing stays readable.
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
    RoomFace? selected;
    for (final face in GeometryService.roomFaces(floor)) {
      if (face.key == selectedFaceKey) {
        selected = face;
        break;
      }
    }
    if (selected == null) return;

    final meta = floor.roomMetaByKey(selected.key);
    if (meta == null) return;
    final settings = meta.materials;
    final path = _roomPath(selected);
    final bounds = path.getBounds();
    if (bounds.isEmpty) return;

    final preset = MaterialCatalog.byId(settings.floorMaterialId);
    canvas.drawPath(
      path,
      Paint()..color = ZamerColors.accent.withValues(alpha: .055),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = ZamerColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    final angle = settings.floorDirectionDeg * math.pi / 180;
    final center = bounds.center;
    final radius = math.min(64.0, math.max(34.0, bounds.shortestSide * .24));
    final direction = Offset(math.cos(angle), math.sin(angle));
    final start = center - direction * radius;
    final end = center + direction * radius;
    final guide = Paint()
      ..color = ZamerColors.accent
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, guide);

    final normal = Offset(-direction.dy, direction.dx);
    const arrow = 9.0;
    canvas.drawLine(
      end,
      end - direction * arrow + normal * arrow * .55,
      guide,
    );
    canvas.drawLine(
      end,
      end - direction * arrow - normal * arrow * .55,
      guide,
    );

    final mode = settings.floorMode == 'tile'
        ? 'ПЛИТКА'
        : settings.laminatePattern == 'herringbone'
            ? 'ЁЛОЧКА'
            : 'ЛАМИНАТ';
    final label = '$mode • ${settings.floorDirectionDeg.round()}°';
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: ZamerColors.textPrimary,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final chip = Rect.fromCenter(
      center: Offset(center.dx, center.dy + radius + 18),
      width: text.width + 28,
      height: text.height + 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chip, const Radius.circular(7)),
      Paint()..color = ZamerColors.surfaceLow.withValues(alpha: .96),
    );
    canvas.drawCircle(
      Offset(chip.left + 11, chip.center.dy),
      4,
      Paint()..color = preset.color,
    );
    text.paint(
      canvas,
      Offset(chip.left + 20, chip.center.dy - text.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant FloorFinishPlanOverlayPainter oldDelegate) => true;
}
