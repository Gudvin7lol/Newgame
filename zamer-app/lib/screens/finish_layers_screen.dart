import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';

class FinishLayersScreen extends StatefulWidget {
  const FinishLayersScreen({
    super.key,
    required this.floor,
    required this.face,
    required this.meta,
    required this.onChanged,
  });

  final FloorPlan floor;
  final RoomFace face;
  final RoomMeta meta;
  final Future<void> Function() onChanged;

  @override
  State<FinishLayersScreen> createState() => _FinishLayersScreenState();
}

class _FinishLayersScreenState extends State<FinishLayersScreen> {
  Future<void> _edit(List<FinishLayer> layers, [FinishLayer? layer]) async {
    var name = layer?.name ?? '';
    var thickness = layer == null ? '' : layer.thicknessMm.toStringAsFixed(0);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(layer == null ? 'Добавить слой' : 'Изменить слой'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Материал',
                prefixIcon: Icon(Icons.layers_outlined),
              ),
              onChanged: (value) => name = value,
            ),
            const SizedBox(height: ZamerSpace.sm),
            TextFormField(
              initialValue: thickness,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Толщина',
                suffixText: 'мм',
                prefixIcon: Icon(Icons.height),
              ),
              onChanged: (value) => thickness = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    final value = double.tryParse(thickness.replaceAll(',', '.'));
    if (accepted != true ||
        name.trim().isEmpty ||
        value == null ||
        !value.isFinite ||
        value <= 0 ||
        value > 1000) {
      return;
    }
    if (layer == null) {
      layers.add(
        FinishLayer(
          id: 'layer-${DateTime.now().microsecondsSinceEpoch}',
          name: name.trim(),
          thicknessMm: value,
        ),
      );
    } else {
      layer.name = name.trim();
      layer.thicknessMm = value;
    }
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _moveUp(List<FinishLayer> layers, int index) async {
    if (index <= 0) return;
    final item = layers.removeAt(index);
    layers.insert(index - 1, item);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _remove(List<FinishLayer> layers, int index) async {
    layers.removeAt(index);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<FinishLayer> layers,
  }) {
    final total = layers.fold<double>(
      0,
      (sum, layer) => sum + layer.thicknessMm,
    );
    return ZCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZamerSpace.md,
              ZamerSpace.md,
              ZamerSpace.sm,
              ZamerSpace.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ZamerColors.accent.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(ZamerRadius.sm),
                  ),
                  child: Icon(icon, size: 19, color: ZamerColors.accent),
                ),
                const SizedBox(width: ZamerSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: ZamerTypography.sectionTitle),
                      const SizedBox(height: 2),
                      Text(subtitle, style: ZamerTypography.caption),
                    ],
                  ),
                ),
                if (layers.isNotEmpty)
                  ZMeasureBadge('${total.toStringAsFixed(1)} мм'),
                const SizedBox(width: ZamerSpace.xs),
                IconButton.filledTonal(
                  tooltip: 'Добавить слой',
                  onPressed: () => _edit(layers),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          const Divider(),
          if (layers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(ZamerSpace.lg),
              child: Row(
                children: [
                  const Icon(
                    Icons.layers_clear_outlined,
                    size: 20,
                    color: ZamerColors.textFaint,
                  ),
                  const SizedBox(width: ZamerSpace.sm),
                  const Expanded(
                    child: Text(
                      'Слои пока не заданы',
                      style: ZamerTypography.caption,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _edit(layers),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить'),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < layers.length; i++) ...[
              _LayerRow(
                index: i,
                layer: layers[i],
                canMoveUp: i > 0,
                onTap: () => _edit(layers, layers[i]),
                onMoveUp: () => _moveUp(layers, i),
                onDelete: () => _remove(layers, i),
              ),
              if (i < layers.length - 1)
                const Divider(indent: 58, endIndent: ZamerSpace.sm),
            ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    final roomHeight = GeometryService.roomHeightMm(widget.floor, widget.face);
    final clearHeight = roomHeight - meta.floorBuildUpMm - meta.ceiling.dropMm;
    final points = widget.face.innerPolygon;
    final minX = points.map((p) => p.x).reduce(math.min);
    final maxX = points.map((p) => p.x).reduce(math.max);
    final minY = points.map((p) => p.y).reduce(math.min);
    final maxY = points.map((p) => p.y).reduce(math.max);
    final width = maxX - minX;
    final depth = maxY - minY;
    final isRectangular =
        ((width * depth / 1000000) - widget.face.areaM2).abs() <
        widget.face.areaM2 * .01;
    final clearWidth = math.max(0.0, width - 2 * meta.wallBuildUpMm);
    final clearDepth = math.max(0.0, depth - 2 * meta.wallBuildUpMm);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Пироги отделки'),
            Text(meta.name, style: ZamerTypography.caption),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZamerSpace.md),
        children: [
          ZCard(
            backgroundColor: ZamerColors.surfaceLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ZSectionTitle('Чистовые размеры'),
                const SizedBox(height: ZamerSpace.md),
                Wrap(
                  spacing: ZamerSpace.sm,
                  runSpacing: ZamerSpace.sm,
                  children: [
                    _SummaryChip(
                      icon: Icons.layers_outlined,
                      label: 'Пол',
                      value: '${meta.floorBuildUpMm.toStringAsFixed(1)} мм',
                    ),
                    _SummaryChip(
                      icon: Icons.view_week_outlined,
                      label: 'Стены',
                      value: '${meta.wallBuildUpMm.toStringAsFixed(1)} мм',
                    ),
                    _SummaryChip(
                      icon: Icons.height,
                      label: 'Высота',
                      value: '${clearHeight.toStringAsFixed(1)} мм',
                    ),
                  ],
                ),
                const SizedBox(height: ZamerSpace.md),
                Container(
                  padding: const EdgeInsets.all(ZamerSpace.md),
                  decoration: BoxDecoration(
                    color: ZamerColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(ZamerRadius.md),
                    border: Border.all(color: ZamerColors.outlineSoft),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isRectangular
                            ? Icons.aspect_ratio_outlined
                            : Icons.polyline_outlined,
                        color: ZamerColors.textMuted,
                      ),
                      const SizedBox(width: ZamerSpace.sm),
                      Expanded(
                        child: Text(
                          isRectangular
                              ? 'Чистовые габариты ${clearWidth.round()} × ${clearDepth.round()} мм'
                              : 'Сложная форма: чистовые габариты смотри на плане по каждой стене.',
                          style: const TextStyle(
                            color: ZamerColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZamerSpace.md),
          _section(
            title: 'Пол снизу вверх',
            subtitle: 'Основание → подложка → покрытие',
            icon: Icons.grid_4x4_outlined,
            layers: meta.floorLayers,
          ),
          const SizedBox(height: ZamerSpace.md),
          _section(
            title: 'Стены от основания',
            subtitle: 'Основание → выравнивание → финиш',
            icon: Icons.view_carousel_outlined,
            layers: meta.wallLayers,
          ),
          const SizedBox(height: ZamerSpace.md),
          Container(
            padding: const EdgeInsets.all(ZamerSpace.md),
            decoration: BoxDecoration(
              color: ZamerColors.info.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(ZamerRadius.md),
              border: Border.all(
                color: ZamerColors.info.withValues(alpha: .28),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 19, color: ZamerColors.info),
                SizedBox(width: ZamerSpace.sm),
                Expanded(
                  child: Text(
                    'Слои попадают в ведомость материалов и смету по площади помещения. Если материал уже включён в стандартной отделке, отключи его там, чтобы не считать дважды.',
                    style: ZamerTypography.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.index,
    required this.layer,
    required this.canMoveUp,
    required this.onTap,
    required this.onMoveUp,
    required this.onDelete,
  });

  final int index;
  final FinishLayer layer;
  final bool canMoveUp;
  final VoidCallback onTap;
  final VoidCallback onMoveUp;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZamerSpace.md,
          ZamerSpace.sm,
          ZamerSpace.xs,
          ZamerSpace.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ZamerColors.surfaceHigh,
                borderRadius: BorderRadius.circular(ZamerRadius.sm),
                border: Border.all(color: ZamerColors.outlineSoft),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: ZamerColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: ZamerSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    layer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZamerColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${layer.thicknessMm.toStringAsFixed(1)} мм',
                    style: ZamerTypography.caption,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Поднять слой',
              onPressed: canMoveUp ? onMoveUp : null,
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            ),
            IconButton(
              tooltip: 'Удалить слой',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: ZamerColors.danger,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: ZamerSpace.sm,
      vertical: ZamerSpace.xs,
    ),
    decoration: BoxDecoration(
      color: ZamerColors.surfaceHigh,
      borderRadius: BorderRadius.circular(ZamerRadius.sm),
      border: Border.all(color: ZamerColors.outlineSoft),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: ZamerColors.textMuted),
        const SizedBox(width: 5),
        Text('$label ', style: ZamerTypography.caption),
        Text(value, style: ZamerTypography.measurement),
      ],
    ),
  );
}
