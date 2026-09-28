import 'dart:math' as math;
import 'package:flutter/material.dart';

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
      builder: (context) => AlertDialog(
        title: Text(layer == null ? 'Добавить слой' : 'Изменить слой'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Материал'),
              onChanged: (value) => name = value,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: thickness,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Толщина',
                suffixText: 'мм',
              ),
              onChanged: (value) => thickness = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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
        value > 1000)
      return;
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

  Widget _section(String title, List<FinishLayer> layers) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Добавить слой в $title',
                onPressed: () => _edit(layers),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (layers.isEmpty) const Text('Слои не заданы'),
          for (var i = 0; i < layers.length; i++)
            ListTile(
              title: Text('${i + 1}. ${layers[i].name}'),
              subtitle: Text('${layers[i].thicknessMm.toStringAsFixed(1)} мм'),
              onTap: () => _edit(layers, layers[i]),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Поднять слой',
                    onPressed: i == 0
                        ? null
                        : () async {
                            final item = layers.removeAt(i);
                            layers.insert(i - 1, item);
                            await widget.onChanged();
                            if (mounted) setState(() {});
                          },
                    icon: const Icon(Icons.arrow_upward, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Удалить слой',
                    onPressed: () async {
                      layers.removeAt(i);
                      await widget.onChanged();
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

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
    final width = maxX - minX, depth = maxY - minY;
    final isRectangular =
        ((width * depth / 1000000) - widget.face.areaM2).abs() <
        widget.face.areaM2 * .01;
    final clearWidth = math.max(0.0, width - 2 * meta.wallBuildUpMm);
    final clearDepth = math.max(0.0, depth - 2 * meta.wallBuildUpMm);
    return Scaffold(
      appBar: AppBar(title: Text('Пироги • ${meta.name}')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Пол: ${meta.floorBuildUpMm.toStringAsFixed(1)} мм'),
                  Text(
                    'Стены: ${meta.wallBuildUpMm.toStringAsFixed(1)} мм на сторону',
                  ),
                  Text('Чистовая высота: ${clearHeight.toStringAsFixed(1)} мм'),
                  if (isRectangular)
                    Text(
                      'Чистовые габариты: ${clearWidth.round()} × ${clearDepth.round()} мм',
                    ),
                  if (!isRectangular)
                    const Text(
                      'Для сложной формы чистовые габариты смотри на плане по каждой стене.',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _section('Пол снизу вверх', meta.floorLayers),
          const SizedBox(height: 10),
          _section('Стены от основания', meta.wallLayers),
          const SizedBox(height: 12),
          const Text(
            'Слои добавляются в ведомость материалов и смету по площади помещения. '
            'Если этот материал уже включён в стандартных настройках отделки, отключи его там, чтобы не посчитать дважды.',
          ),
        ],
      ),
    );
  }
}
