import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';

/// Edits the finish visible on one elevation without leaving the drawing.
///
/// The current project model stores the base wall finish per room and tile
/// enable/offset state per elevation run. The UI says this explicitly instead
/// of pretending that paint already has per-wall storage.
class ElevationMaterialEditor extends StatelessWidget {
  const ElevationMaterialEditor({
    super.key,
    required this.settings,
    required this.run,
    required this.heightMm,
    required this.onChanged,
  });

  final RoomMaterialSettings settings;
  final ElevationRun run;
  final double heightMm;
  final Future<void> Function() onChanged;

  VisualMaterialPreset get _current => MaterialCatalog.byId(
        settings.wallTileEnabledFor(run.id)
            ? settings.wallTileMaterialId
            : settings.wallMaterialId,
      );

  Future<void> _pickMaterial(BuildContext context) async {
    final wallPresets = MaterialCatalog.forCategory('Стены');
    final tilePresets = MaterialCatalog.forCategory('Плитка');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ZamerColors.surface,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: DefaultTabController(
          length: 2,
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Материал стены',
                    style: ZamerTypography.h3,
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Стена'),
                    Tab(text: 'Плитка'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _MaterialList(
                        presets: wallPresets,
                        selectedId: settings.wallMaterialId,
                        note:
                            'Базовая отделка применяется ко всем неплиточным стенам помещения.',
                        onPick: (preset) async {
                          settings.wallMaterialId = preset.id;
                          settings.wallTileRunEnabled[run.id] = false;
                          await onChanged();
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                      ),
                      _MaterialList(
                        presets: tilePresets,
                        selectedId: settings.wallTileMaterialId,
                        note:
                            'Плитка включается только на выбранной стене. Размер и раскладка настраиваются отдельно.',
                        onPick: (preset) async {
                          settings.wallTileMaterialId = preset.id;
                          settings.wallTileRunEnabled[run.id] = true;
                          settings.wallTileToMm = settings.wallTileToMm
                              .clamp(0.0, heightMm)
                              .toDouble();
                          await onChanged();
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<double?> _number(
    BuildContext context,
    String title,
    double value,
  ) async {
    final controller = TextEditingController(
      text: value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'мм'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _tileSettings(BuildContext context) async {
    if (!settings.wallTileEnabledFor(run.id)) {
      settings.wallTileRunEnabled[run.id] = true;
      await onChanged();
    }
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ZamerColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> edit(String field) async {
            final descriptor = switch (field) {
              'w' => (settings.wallTileWidthMm, 'Ширина плитки'),
              'h' => (settings.wallTileHeightMm, 'Высота плитки'),
              'from' => (settings.wallTileFromMm, 'Плитка от пола'),
              _ => (settings.wallTileToMm, 'Плитка до высоты'),
            };
            final value = await _number(
              context,
              descriptor.$2,
              descriptor.$1,
            );
            if (value == null || !value.isFinite) return;
            if ((field == 'w' || field == 'h') &&
                (value < 20 || value > 10000)) {
              return;
            }
            if (field == 'w') settings.wallTileWidthMm = value;
            if (field == 'h') settings.wallTileHeightMm = value;
            if (field == 'from') {
              settings.wallTileFromMm = value.clamp(0.0, heightMm).toDouble();
            }
            if (field == 'to') {
              settings.wallTileToMm = value.clamp(0.0, heightMm).toDouble();
            }
            settings.normalizeFormats();
            await onChanged();
            if (context.mounted) setSheetState(() {});
          }

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Раскладка плитки', style: ZamerTypography.h3),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: Text('Ш ${settings.wallTileWidthMm.round()}'),
                        onPressed: () => edit('w'),
                      ),
                      ActionChip(
                        label: Text('В ${settings.wallTileHeightMm.round()}'),
                        onPressed: () => edit('h'),
                      ),
                      ActionChip(
                        label: Text('От ${settings.wallTileFromMm.round()}'),
                        onPressed: () => edit('from'),
                      ),
                      ActionChip(
                        label: Text('До ${settings.wallTileToMm.round()}'),
                        onPressed: () => edit('to'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'straight', label: Text('Прямая')),
                      ButtonSegment(value: 'half', label: Text('1/2')),
                    ],
                    selected: {settings.wallTilePattern},
                    onSelectionChanged: (value) async {
                      settings.wallTilePattern = value.first;
                      await onChanged();
                      if (context.mounted) setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Повернуть плитку на стене'),
                    value: settings.wallTileRotatedFor(run.id),
                    onChanged: (value) async {
                      settings.wallTileRunRotated[run.id] = value;
                      await onChanged();
                      if (context.mounted) setSheetState(() {});
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Зеркальная раскладка'),
                    value: settings.wallTileMirroredFor(run.id),
                    onChanged: (value) async {
                      settings.wallTileRunMirrored[run.id] = value;
                      await onChanged();
                      if (context.mounted) setSheetState(() {});
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      settings.wallTileRunEnabled[run.id] = false;
                      await onChanged();
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.layers_clear_outlined),
                    label: const Text('Убрать плитку с этой стены'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiled = settings.wallTileEnabledFor(run.id);
    final material = _current;
    return SizedBox(
      height: 54,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
        scrollDirection: Axis.horizontal,
        children: [
          ActionChip(
            avatar: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: material.color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: ZamerColors.outline),
              ),
            ),
            label: Text(material.name),
            side: const BorderSide(color: ZamerColors.outline),
            backgroundColor: ZamerColors.surface,
            labelStyle: ZamerTypography.caption.copyWith(
              color: ZamerColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            onPressed: () => _pickMaterial(context),
          ),
          if (tiled) ...[
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.grid_on_outlined, size: 16),
              label: Text(
                '${settings.wallTileWidthFor(run.id).round()}×'
                '${settings.wallTileHeightFor(run.id).round()} мм',
              ),
              onPressed: () => _tileSettings(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _MaterialList extends StatelessWidget {
  const _MaterialList({
    required this.presets,
    required this.selectedId,
    required this.note,
    required this.onPick,
  });

  final List<VisualMaterialPreset> presets;
  final String selectedId;
  final String note;
  final Future<void> Function(VisualMaterialPreset preset) onPick;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(note, style: ZamerTypography.caption),
          ),
          for (final preset in presets)
            ListTile(
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: preset.color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ZamerColors.outline),
                ),
              ),
              title: Text(preset.name),
              subtitle: Text(
                preset.roughness == null
                    ? preset.category
                    : '${preset.category} • roughness ${preset.roughness!.toStringAsFixed(2)}',
              ),
              trailing: preset.id == selectedId
                  ? const Icon(Icons.check_circle, color: ZamerColors.accent)
                  : null,
              onTap: () => onPick(preset),
            ),
        ],
      );
}
