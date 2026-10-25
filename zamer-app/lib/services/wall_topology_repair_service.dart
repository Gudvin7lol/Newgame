import '../models/models.dart';
import 'geometry_service.dart';
import 'node_move_constraint_service.dart';
import 'wall_topology_diagnostics.dart';

/// Atomic repair for one diagnostic wall gap. The service deliberately uses
/// the same constrained node move as manual editing, then lets GeometryService
/// perform the real node merge or host-wall split.
class WallTopologyRepairResult {
  const WallTopologyRepairResult._({
    required this.isValid,
    this.message = '',
    this.nodeId,
  });

  final bool isValid;
  final String message;
  final String? nodeId;

  static const success = WallTopologyRepairResult._(isValid: true);

  static WallTopologyRepairResult reject(String message) =>
      WallTopologyRepairResult._(isValid: false, message: message);
}

class WallTopologyRepairService {
  const WallTopologyRepairService._();

  static WallTopologyRepairResult repair(
    FloorPlan floor,
    WallTopologyGap gap,
  ) {
    final source = floor.nodeById(gap.sourceNodeId);
    if (source == null) return WallTopologyRepairResult.reject(
      'Исходный узел разрыва не найден.',
    );

    final snap = switch (gap.kind) {
      WallTopologyGapKind.detachedNodes => _nodeSnap(floor, gap),
      WallTopologyGapKind.detachedWallEnd => _wallSnap(floor, gap),
    };
    if (snap == null) return WallTopologyRepairResult.reject(
      'Цель стыка больше не существует.',
    );
    if (snap.targetWallId case final hostId?) {
      final host = floor.wallById(hostId);
      if (host == null) return WallTopologyRepairResult.reject(
        'Принимающая стена не найдена.',
      );
      if (host.isCurved) return WallTopologyRepairResult.reject(
        'Для стыка с дуговой стеной нужен инструмент дуг.',
      );
    }

    final before = FloorPlan.fromJson(floor.toJson());
    final preview = NodeMoveConstraintService.evaluate(
      floor,
      nodeId: source.id,
      destination: snap.point,
    );
    if (!preview.isValid) {
      return WallTopologyRepairResult.reject(
        preview.message ?? 'Недопустимая геометрия стыка.',
      );
    }

    NodeMoveConstraintService.apply(floor, preview);
    try {
      final moved = GeometryService.finalizeNodeMove(
        floor,
        movingNodeId: source.id,
        snap: snap,
      );
      if (moved == null) {
        floor.restoreFrom(before);
        return WallTopologyRepairResult.reject(
          'Не удалось создать общий узел.',
        );
      }
      return WallTopologyRepairResult._(isValid: true, nodeId: moved.id);
    } on StateError catch (error) {
      floor.restoreFrom(before);
      return WallTopologyRepairResult.reject(error.message);
    } catch (_) {
      floor.restoreFrom(before);
      return WallTopologyRepairResult.reject('Стык не создан. Геометрия восстановлена.');
    }
  }

  static NodeSnapResult? _nodeSnap(FloorPlan floor, WallTopologyGap gap) {
    final targetId = gap.targetNodeId;
    if (targetId == null || floor.nodeById(targetId) == null) return null;
    return NodeSnapResult(
      point: gap.target,
      kind: NodeSnapKind.node,
      targetNodeId: targetId,
      distanceMm: gap.distanceMm,
    );
  }

  static NodeSnapResult? _wallSnap(FloorPlan floor, WallTopologyGap gap) {
    final targetId = gap.targetWallId;
    if (targetId == null || floor.wallById(targetId) == null) return null;
    return NodeSnapResult(
      point: gap.target,
      kind: NodeSnapKind.wall,
      targetWallId: targetId,
      distanceMm: gap.distanceMm,
    );
  }
}
