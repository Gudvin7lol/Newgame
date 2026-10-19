import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/plan_view_layers.dart';
import '../services/plan_collision_service.dart';
import 'cad_plan_painter_v3.dart';

/// Compatibility entry point for the Measure workspace.
///
/// +105 keeps the stable public contract while the V3 renderer layers the
/// approved imported top-view artwork over the deterministic V2 symbols.
class CadPlanPainter extends CadPlanPainterV3 {
  CadPlanPainter({
    required super.floor,
    required super.mmToPx,
    required super.origin,
    super.selectedWallId,
    super.showGrid = true,
    super.showDimensions = true,
    Set<ProjectLayer>? visibleLayers,
    PlanViewLayers? viewSettings,
    List<PlanClashIssue> collisionIssues = const [],
  }) : super(
          visibleLayers: visibleLayers,
          viewSettings: viewSettings,
          collisionIssues: collisionIssues,
        );
}
