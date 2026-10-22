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
    final width = object.widthMm * mmToPx;
    final depth = object.depthMm * mmToPx;
    if (width < 8 || depth < 8) return false;

    final neutral = assets.neutralForCatalog(object.catalogId);
    if (neutral != null) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(object.rotationDeg * 3.141592653589793 / 180);
      canvas.drawImageRect(
        neutral.image,
        neutral.sourceRect,
        Rect.fromCenter(center: Offset.zero, width: width, height: depth),
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();
      return true;
    }

    // +131 curated top views take precedence over the legacy +130 set.
    // A single atlas is used in Plan, Equipment, and Catalog.
    final curatedAtlas = assets.curated131Atlas;
    final curatedRect = assets.curated131RectForCatalog(object.catalogId);
    if (curatedAtlas != null && curatedRect != null) {
      final rotateBath = object.catalogId == 'bath' ||
          object.catalogId == 'bathtub-freestanding';
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(
        (object.rotationDeg + (rotateBath ? 90 : 0)) *
            3.141592653589793 / 180,
      );
      // Baths are photographed along their long axis, which is rotated
      // relative to the legacy bath width/depth catalog convention.
      canvas.drawImageRect(
        curatedAtlas,
        curatedRect,
        Rect.fromCenter(
          center: Offset.zero,
          width: rotateBath ? depth : width,
          height: rotateBath ? width : depth,
        ),
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();
      return true;
    }

    // Use the approved top-down photograph before production-model previews.
    // A fixed catalog ID keeps Plan / Equipment / Catalog visually identical.
    final atlas = assets.approvedAtlas;
    final sprite = assets.approvedRectForCatalog(object.catalogId);
    if (atlas != null && sprite != null) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(object.rotationDeg * 3.141592653589793 / 180);
      canvas.drawImageRect(
        atlas,
        sprite,
        Rect.fromCenter(
          center: Offset.zero,
          width: width,
          height: depth,
        ),
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();
      return true;
    }

    final image = assets.imageForCatalog(object.catalogId);
    if (image == null) return false;
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
