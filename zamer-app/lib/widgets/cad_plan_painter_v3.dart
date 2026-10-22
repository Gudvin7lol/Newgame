import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/plan_visibility_service.dart';
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
    this.zoom = 1.0,
    this.showOpeningDimensions = false,
    this.showDepth = true,
    Set<ProjectLayer>? visibleLayers,
    Set<PlanDisplayLayer>? visibleCategories,
    Set<PlanCollisionKind>? collisionKinds,
  }) : visibleLayers = visibleLayers ?? ProjectLayer.values.toSet(),
       visibleCategories = visibleCategories ?? (PlanDisplayLayer.values.toSet()
         ..remove(PlanDisplayLayer.axisDimensions)),
       collisionKinds = collisionKinds ?? <PlanCollisionKind>{},
       super(repaint: ImportedTopViewAssets.instance) {
    unawaited(ImportedTopViewAssets.instance.ensureLoaded());
  }

  final FloorPlan floor;
  final double mmToPx;
  final Offset origin;
  final String? selectedWallId;
  final bool showGrid;
  final bool showDimensions;
  final double zoom;
  final bool showOpeningDimensions;
  final bool showDepth;
  final Set<ProjectLayer> visibleLayers;
  final Set<PlanDisplayLayer> visibleCategories;
  final Set<PlanCollisionKind> collisionKinds;

  @override
  void paint(Canvas canvas, Size size) {
    CadPlanPainterV2(
      floor: floor,
      mmToPx: mmToPx,
      origin: origin,
      selectedWallId: selectedWallId,
      showGrid: showGrid,
      showDimensions: showDimensions,
      zoom: zoom,
      showOpeningDimensions: showOpeningDimensions,
      showDepth: showDepth,
      visibleLayers: visibleLayers,
      visibleCategories: visibleCategories,
      collisionKinds: collisionKinds,
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
    final assets = ImportedTopViewAssets.instance;
    final raster = assets.planRasterForCatalog(object.catalogId);
    if (raster == null) return false;
    final width = object.widthMm * mmToPx;
    final depth = object.depthMm * mmToPx;
    if (width < 8 || depth < 8) return false;
    final destination = Rect.fromCenter(
      center: Offset.zero,
      width: raster.quarterTurn ? depth : width,
      height: raster.quarterTurn ? width : depth,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(
      (object.rotationDeg + (raster.quarterTurn ? 90 : 0)) *
          3.141592653589793 / 180,
    );
    if (showDepth && object.elevationMm <= 10) {
      assets.contactShadowForCatalog(object.catalogId)?.paint(canvas, destination);
    }
    canvas.drawImageRect(
      raster.image, raster.sourceRect, destination,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
    return true;
  }

  @override
  bool shouldRepaint(covariant CadPlanPainterV3 oldDelegate) => true;
}
