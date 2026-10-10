import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/imported_top_view_assets.dart';
import 'cad_plan_painter_v2.dart';

/// CAD renderer that paints either imported top-view art or the shared V2
/// fallback for each object, while keeping room labels and dimensions on top.
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
      drawTopView: _drawImportedObject,
    ).paint(canvas, size);
  }

  /// Draw the imported top view in the *normal* object pass. Previously the
  /// raster was drawn as a second pass over labels and dimensions, leaving
  /// duplicate line art under the image. Missing assets use V2 vector symbols.
  bool _drawImportedObject(
    Canvas canvas,
    PlanObject object,
    Offset center,
    double mmToPx,
  ) {
    final image = ImportedTopViewAssets.instance.imageForCatalog(object.catalogId);
    if (image == null) return false;
    final width = object.widthMm * mmToPx;
    final depth = object.depthMm * mmToPx;
    if (width < 8 || depth < 8) return false;

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
    );
    canvas.restore();
    return true;
  }

  @override
  bool shouldRepaint(covariant CadPlanPainterV3 oldDelegate) => true;
}
