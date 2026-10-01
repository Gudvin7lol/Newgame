import 'package:flutter/material.dart';

import '../models/models.dart';
import 'cad_plan_painter_v2.dart';

/// Compatibility entry point for the Measure workspace.
///
/// +78 moved the actual rendering into [CadPlanPainterV2] so the screen can
/// keep its stable public contract while 2D objects and material rendering are
/// upgraded independently.
class CadPlanPainter extends CadPlanPainterV2 {
  CadPlanPainter({
    required super.floor,
    required super.mmToPx,
    required super.origin,
    super.selectedWallId,
    super.showGrid = true,
    super.showDimensions = true,
    Set<ProjectLayer>? visibleLayers,
  }) : super(visibleLayers: visibleLayers);
}
