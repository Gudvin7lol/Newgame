import 'package:flutter/material.dart';

import '../models/models.dart';

/// Single-row inspector; all edits are delegated to the parent undo/save flow.
class ElectricalCompactInspector extends StatelessWidget {
  const ElectricalCompactInspector({
    super.key,
    required this.floor,
    required this.point,
    required this.onDatum,
    required this.onHeight,
    required this.onLoad,
  });

  final FloorPlan floor;
  final ElectricalPoint point;
  final VoidCallback onDatum, onHeight, onLoad;

  static String millimeters(double value) =>
      value.isFinite ? '${value.round()} мм' : 'не задано';

  // The compact field and the on-plan dimension share the same station
  // measured from the wall start node, not a named finished datum.
  String get datumTitle => point.wallOffsetMm == null
      ? 'Выбрать' : millimeters(point.wallOffsetMm!);

  String get datumLabel => 'От начала стены';

  Widget _field(
      BuildContext context, String label, String value, VoidCallback onTap,
      String key) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        key: ValueKey(key),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall),
              const SizedBox(height: 2),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = point.circuit.trim().isEmpty
        ? 'Без группы'
        : point.circuit.trim();
    final consumer = floor.electricalDesignDraft?.consumers[point.id];
    final watts = consumer?.installedWatts ??
        (point.powerW > 0 ? point.powerW : null);
    final unpowered = <ElectricalPointType>{
      ElectricalPointType.switchPoint,
      ElectricalPointType.tvSocket,
      ElectricalPointType.dataSocket,
      ElectricalPointType.panel,
      ElectricalPointType.junctionBox,
    }.contains(point.type) ||
        (point.type == ElectricalPointType.frame &&
         point.modules.every((m) => m != ElectricalModuleType.socket220));
    final load = watts == null
        ? (unpowered ? 'без нагрузки 230 В' : 'не задана')
        : '${consumer?.catalogId == null ? '' : '≈'}'
          '${(watts / 1000).toStringAsFixed(2)} кВт';
    return Semantics(
      label: 'Быстрые размеры и нагрузка выбранной электроточки',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 9),
        child: Row(
          key: const ValueKey('electrical-compact-inspector'),
          children: [
            _field(context, datumLabel, datumTitle, onDatum,
                'electrical-inspector-datum'),
            const SizedBox(width: 6),
            _field(context, 'Высота H', millimeters(point.heightMm), onHeight,
                'electrical-inspector-height'),
            const SizedBox(width: 6),
            _field(context, 'Линия / нагрузка', '$group · $load', onLoad,
                'electrical-inspector-load'),
          ],
        ),
      ),
    );
  }
}
