import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/imported_top_view_assets.dart';
import 'cad_plan_painter_v2.dart';

/// CAD renderer that keeps the deterministic vector symbols from V2 and
/// overlays approved raster top-view art when it is available.
class CadPlanPainterV3 extends CustomPainter {
  CadPlanPainterV3({
    required this.floor,
    required this.mmToPx,
    required this.origin,
    this.selectedWallId,
    this.showGrid = true,
    this.showDimensions = true,
    Set<ProjectLayer>? visibleLayers,
  }) : visibleLayers = visibleLayers ?? ProjectLayer.values.toSet(),
       super(repaint: ImportedTopViewAssets.instance) {
    unawaited(ImportedTopViewAssets.instance.ensureLoaded());
  }

  final FloorPlan floor;
  final double mmToPx;
  final Offset origin;
  final String? selectedWallId;
  final bool showGrid;
  final bool showDimensions;
  final Set<ProjectLayer> visibleLayers;

  @override
  void paint(Canvas canvas, Size size) {
    CadPlanPainterV2(
      floor: floor,
      mmToPx: mmToPx,
      origin: origin,
      selectedWallId: selectedWallId,
      showGrid: showGrid,
      showDimensions: showDimensions,
      visibleLayers: visibleLayers,
    ).paint(canvas, size);

    final imported = ImportedTopViewAssets.instance;
    for (final object in floor.planObjects) {
      if (!visibleLayers.contains(object.layer) || object.elevationMm > 2300) {
        continue;
      }
      final image = imported.imageForCatalog(object.catalogId);
      if (image == null) continue;

      final center = origin + Offset(object.xMm * mmToPx, object.yMm * mmToPx);
      final width = object.widthMm * mmToPx;
      final depth = object.depthMm * mmToPx;
      if (width < 8 || depth < 8) continue;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(object.rotationDeg * 3.141592653589793 / 180);
      paintImage(
        canvas: canvas,
        rect: Rect.fromCenter(
          center: Offset.zero,
          width: width,
          height: depth,
        ),
        image: image,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
        opacity: .94,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CadPlanPainterV3 oldDelegate) => true;
}
