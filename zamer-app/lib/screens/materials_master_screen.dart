import 'package:flutter/material.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_catalog.dart';
import '../widgets/material_finish_swatch.dart';

enum _MaterialSurface { walls, floor, ceiling }

enum _MaterialEditorTab { color, texture, parameters }

class MaterialsMasterScreen extends StatefulWidget {
  const MaterialsMasterScreen({
    super.key,
    required this.floor,
    required this.onChanged,
    this.onClose,
  });

  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final VoidCallback? onClose;

  @override
  State<MaterialsMasterScreen> createState() => _MaterialsMasterScreenState();
}

class _MaterialsMasterScreenState extends State<MaterialsMasterScreen> {
  static const _palette = <Color>[
    Color(0xFFF2EBDD),
    Color(0xFFE6DED0),
    Color(0xFFB9BDC0),
    Color(0xFF747A7D),
    Color(0xFF7F846B),
    Color(0xFF8A6250),
  ];

  _MaterialSurface _surface = _MaterialSurface.walls;
  _MaterialEditorTab _editorTab = _MaterialEditorTab.color;
  String _category = 'Все';
  String? _faceKey;
  final Set<String> _favorites = <String>{};

  List<RoomFace> _faces() {
    GeometryService.syncRoomMetadata(widget.floor);
    return GeometryService.roomFaces(widget.floor);
  }

  RoomMaterialSettings _settings(List<RoomFace> faces) {
    _faceKey ??= faces.first.key;
    final face = faces.firstWhere(
      (item) => item.key == _faceKey,
      orElse: () => faces.first,
    );
    return widget.floor.roomMetaByKey(face.key)!.materials;
  }

  String _categoryFor(VisualMaterialPreset material) {
    final name = material.name.toLowerCase();
    if (name.contains('краск')) return 'Краска';
    if (name.contains('штукатур')) return 'Штукатурка';
    if (name.contains('микроцемент') || name.contains('бетон')) return 'Бетон';
    if (material.category == 'Плитка') return 'Плитка';
    if (material.pattern == 'wood' || material.category == 'Пол') {
      return 'Дерево';
    }
    return material.category;
  }

  List<VisualMaterialPreset> _sourceMaterials() {
    switch (_surface) {
      case _MaterialSurface.walls:
        return MaterialCatalog.masterWallFinishes;
      case _MaterialSurface.floor:
        return MaterialCatalog.masterFloorFinishes;
      case _MaterialSurface.ceiling:
        return MaterialCatalog.masterWallFinishes
            .where((item) => item.category != 'Плитка')
            .toList(growable: false);
    }
  }

  List<String> _categories() {
    final values = <String>{'Все'};
    for (final item in _sourceMaterials()) {
      values.add(_categoryFor(item));
    }
    return values.toList(growable: false);
  }

  List<VisualMaterialPreset> _visibleMaterials() {
    final source = _sourceMaterials();
    if (_category == 'Все') return source;
    return source
        .where((item) => _categoryFor(item) == _category)
        .toList(growable: false);
  }

  String _selectedMaterialId(RoomMaterialSettings settings) {
    switch (_surface) {
      case _MaterialSurface.walls:
        return settings.wallTile
            ? settings.wallTileMaterialId
            : settings.wallMaterialId;
      case _MaterialSurface.floor:
        return settings.floorMaterialId;
      case _MaterialSurface.ceiling:
        return settings.ceilingMaterialId;
    }
  }

  Future<void> _selectMaterial(
    RoomMaterialSettings settings,
    VisualMaterialPreset material,
  ) async {
    switch (_surface) {
      case _MaterialSurface.walls:
        if (material.category == 'Плитка') {
          settings
            ..wallTile = true
            ..wallTileMaterialId = material.id
            ..wallTileTintArgb = 0xFFFFFFFF;
        } else {
          settings
            ..wallTile = false
            ..wallMaterialId = material.id
            ..wallPaintColorArgb = 0;
        }
        break;
      case _MaterialSurface.floor:
        settings
          ..floorMaterialId = material.id
          ..floorTile = material.category == 'Плитка'
          ..floorMode = material.category == 'Плитка' ? 'tile' : 'laminate';
        break;
      case _MaterialSurface.ceiling:
        settings
          ..ceilingMaterialId = material.id
          ..ceilingPaintColorArgb = 0;
        break;
    }
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Color _activeColor(RoomMaterialSettings settings) {
    switch (_surface) {
      case _MaterialSurface.walls:
        if (settings.wallTile) {
          return Color(settings.wallTileTintArgb);
        }
        return settings.wallPaintColorArgb == 0
            ? MaterialCatalog.byId(settings.wallMaterialId).color
            : Color(settings.wallPaintColorArgb);
      case _MaterialSurface.floor:
        return MaterialCatalog.byId(settings.floorMaterialId).color;
      case _MaterialSurface.ceiling:
        return settings.ceilingPaintColorArgb == 0
            ? MaterialCatalog.byId(settings.ceilingMaterialId).color
            : Color(settings.ceilingPaintColorArgb);
    }
  }

  Future<void> _applyColor(
    RoomMaterialSettings settings,
    Color color,
  ) async {
    switch (_surface) {
      case _MaterialSurface.walls:
        if (settings.wallTile) {
          settings.wallTileTintArgb = color.toARGB32();
        } else {
          settings.wallPaintColorArgb = color.toARGB32();
        }
        break;
      case _MaterialSurface.floor:
        final current = MaterialCatalog.byId(settings.floorMaterialId);
        final choices = current.pattern == 'wood'
            ? MaterialCatalog.masterFloorFinishes
                  .where((item) => item.pattern == 'wood')
                  .toList(growable: false)
            : MaterialCatalog.masterFloorFinishes
                  .where((item) => item.category == 'Плитка')
                  .toList(growable: false);
        if (choices.isNotEmpty) {
          choices.sort((a, b) {
            int distance(VisualMaterialPreset item) {
              final c = item.color;
              return ((c.r - color.r).abs() * 255 +
                      (c.g - color.g).abs() * 255 +
                      (c.b - color.b).abs() * 255)
                  .round();
            }
            return distance(a).compareTo(distance(b));
          });
          settings.floorMaterialId = choices.first.id;
        }
        break;
      case _MaterialSurface.ceiling:
        settings.ceilingPaintColorArgb = color.toARGB32();
        break;
    }
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _pickCustomColor(RoomMaterialSettings settings) async {
    final initial = _activeColor(settings);
    final controller = TextEditingController(
      text: initial.toARGB32().toRadixString(16).padLeft(8, '0').substring(2),
    );
    final hex = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Свой цвет'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            prefixText: '#',
            labelText: 'HEX',
            hintText: 'F2EBDD',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    if (hex == null) return;
    final normalized = hex.trim().replaceAll('#', '');
    if (normalized.length != 6) return;
    final rgb = int.tryParse(normalized, radix: 16);
    if (rgb == null) return;
    await _applyColor(settings, Color(0xFF000000 | rgb));
  }

  Future<void> _setPattern(
    RoomMaterialSettings settings,
    String pattern,
  ) async {
    settings.laminatePattern = pattern;
    if (pattern == 'straight' && settings.laminateOffsetMode == 'none') {
      settings.laminateOffsetMode = 'half';
    }
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Widget _surfaceTabs() {
    Widget tab(
      _MaterialSurface value,
      String label,
      IconData icon,
    ) {
      final selected = _surface == value;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() {
            _surface = value;
            _category = 'Все';
            _editorTab = _MaterialEditorTab.color;
          }),
          borderRadius: BorderRadius.circular(ZamerRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 52,
            decoration: BoxDecoration(
              color: selected ? ZamerColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(ZamerRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: selected
                      ? ZamerColors.accentInk
                      : ZamerColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? ZamerColors.accentInk
                        : ZamerColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ZamerColors.surfaceLow,
        borderRadius: BorderRadius.circular(ZamerRadius.lg),
        border: Border.all(color: ZamerColors.outline),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          tab(_MaterialSurface.walls, 'Стены', Icons.view_sidebar_outlined),
          tab(_MaterialSurface.floor, 'Пол', Icons.grid_4x4_outlined),
          tab(_MaterialSurface.ceiling, 'Потолок', Icons.roofing_outlined),
        ],
      ),
    );
  }

  Widget _categoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories().length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final label = _categories()[index];
          final selected = label == _category;
          final icon = switch (label) {
            'Краска' => Icons.format_paint_outlined,
            'Штукатурка' => Icons.texture_outlined,
            'Бетон' => Icons.crop_square_rounded,
            'Плитка' => Icons.grid_view_rounded,
            'Дерево' => Icons.layers_outlined,
            _ => Icons.apps_rounded,
          };
          return ZStatusChip(
            label: label,
            icon: icon,
            selected: selected,
            onTap: () => setState(() => _category = label),
          );
        },
      ),
    );
  }

  Widget _materialCard(
    VisualMaterialPreset material,
    String selectedId,
    RoomMaterialSettings settings,
  ) {
    final selected = material.id == selectedId;
    final favorite = _favorites.contains(material.id);
    return Material(
      color: ZamerColors.surface,
      borderRadius: BorderRadius.circular(ZamerRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _selectMaterial(settings, material),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZamerRadius.md),
            border: Border.all(
              color: selected ? ZamerColors.accent : ZamerColors.outlineSoft,
              width: selected ? 1.7 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(6, 7, 6, 6),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: MaterialFinishSwatch(
                        material: material,
                        size: 58,
                        borderRadius: 29,
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          if (favorite) {
                            _favorites.remove(material.id);
                          } else {
                            _favorites.add(material.id);
                          }
                        }),
                        child: Icon(
                          favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 17,
                          color: favorite
                              ? ZamerColors.danger
                              : ZamerColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  material.name
                      .replaceAll(' · Runtime v4', '')
                      .replaceAll(' · PBR', ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ZamerColors.textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  _badge('PBR'),
                  const SizedBox(width: 4),
                  _badge(material.pattern == 'wood' ? 'Лёгкий' : '2K'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(ZamerRadius.pill),
      border: Border.all(color: ZamerColors.outlineLight),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: ZamerColors.textSecondary,
        fontSize: 8.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _preview(
    VisualMaterialPreset material,
    RoomMaterialSettings settings,
  ) {
    final texture = material.textureAsset;
    return Container(
      height: 286,
      decoration: BoxDecoration(
        color: ZamerColors.surface,
        borderRadius: BorderRadius.circular(ZamerRadius.lg),
        border: Border.all(color: ZamerColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (texture != null)
            Image.asset(
              texture,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => ColoredBox(color: material.color),
            )
          else
            ColoredBox(color: material.color),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: .20),
                  Colors.transparent,
                  Colors.black.withValues(alpha: .34),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .62),
                borderRadius: BorderRadius.circular(ZamerRadius.md),
              ),
              child: const Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 17),
                  SizedBox(width: 6),
                  Text(
                    'Предпросмотр материала',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: ZamerColors.surface.withValues(alpha: .90),
                borderRadius: BorderRadius.circular(ZamerRadius.md),
                border: Border.all(color: ZamerColors.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        switch (_surface) {
                          _MaterialSurface.walls => 'Стена',
                          _MaterialSurface.floor => 'Пол',
                          _MaterialSurface.ceiling => 'Потолок',
                        },
                        style: const TextStyle(
                          color: ZamerColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Center(
                      child: Text(
                        _categoryFor(material),
                        style: ZamerTypography.caption,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editor(
    VisualMaterialPreset material,
    RoomMaterialSettings settings,
  ) {
    Widget editorTab(
      _MaterialEditorTab value,
      String label,
      IconData icon,
    ) {
      final selected = value == _editorTab;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _editorTab = value),
          borderRadius: BorderRadius.circular(ZamerRadius.md),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: selected ? ZamerColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(ZamerRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? ZamerColors.accentInk
                      : ZamerColors.textSecondary,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? ZamerColors.accentInk
                          : ZamerColors.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 286),
      decoration: BoxDecoration(
        color: ZamerColors.surface,
        borderRadius: BorderRadius.circular(ZamerRadius.lg),
        border: Border.all(color: ZamerColors.outline),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: ZamerColors.surfaceLow,
              borderRadius: BorderRadius.circular(ZamerRadius.md),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              children: [
                editorTab(_MaterialEditorTab.color, 'Цвет', Icons.palette_outlined),
                editorTab(_MaterialEditorTab.texture, 'Текстура', Icons.grid_view_rounded),
                editorTab(_MaterialEditorTab.parameters, 'Параметры', Icons.tune_rounded),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_editorTab == _MaterialEditorTab.color)
            _colorPanel(settings)
          else if (_editorTab == _MaterialEditorTab.texture)
            _texturePanel(material, settings)
          else
            _parametersPanel(material, settings),
          const Spacer(),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () async {
              await widget.onChanged();
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    duration: Duration(milliseconds: 900),
                    content: Text('Материал применён к выбранной поверхности'),
                  ),
                );
            },
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Применить'),
          ),
        ],
      ),
    );
  }

  Widget _colorPanel(RoomMaterialSettings settings) {
    final active = _activeColor(settings);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Цвет материала',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final color in _palette)
              GestureDetector(
                onTap: () => _applyColor(settings, color),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _closeColor(color, active)
                          ? ZamerColors.accent
                          : ZamerColors.outlineLight,
                      width: _closeColor(color, active) ? 2.4 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _pickCustomColor(settings),
          icon: const Icon(Icons.colorize_outlined, size: 17),
          label: const Text('Другие цвета / HEX'),
        ),
        const SizedBox(height: 4),
        Text(
          _surface == _MaterialSurface.floor
              ? 'Для пола цвет выбирает ближайший PBR-вариант этой коллекции.'
              : 'Цвет хранится отдельно от базового материала.',
          style: ZamerTypography.caption,
        ),
      ],
    );
  }

  bool _closeColor(Color a, Color b) {
    final d =
        (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
    return d < .18;
  }

  Widget _texturePanel(
    VisualMaterialPreset material,
    RoomMaterialSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            MaterialFinishSwatch(material: material, size: 42, borderRadius: 10),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.name.replaceAll(' · Runtime v4', ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  MaterialPbrSummary(material: material, compact: true),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_surface == _MaterialSurface.floor && material.pattern == 'wood') ...[
          _valueRow('Длина доски', '${settings.laminatePlankLengthMm.round()} мм'),
          _valueRow('Ширина доски', '${settings.laminatePlankWidthMm.round()} мм'),
        ] else if (material.category == 'Плитка') ...[
          _valueRow('Плитка', '${settings.tileWidthMm.round()} × ${settings.tileHeightMm.round()} мм'),
          _valueRow('Ширина шва', '${settings.floorTileGroutMm.toStringAsFixed(1)} мм'),
        ] else ...[
          _valueRow('Тип', _categoryFor(material)),
          _valueRow('Качество', 'PBR · оптимизировано'),
        ],
      ],
    );
  }

  Widget _parametersPanel(
    VisualMaterialPreset material,
    RoomMaterialSettings settings,
  ) {
    if (_surface != _MaterialSurface.floor) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _valueRow('Финиш', material.roughness != null && material.roughness! < .45 ? 'Сатин / гладкий' : 'Матовый'),
          _valueRow('PBR', 'BaseColor · Normal · Roughness'),
          const SizedBox(height: 8),
          Text(
            'Геометрия и цвет не запекаются в десятки дубликатов материала.',
            style: ZamerTypography.caption,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Тип раскладки',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: _patternButton(
                settings,
                'Прямая',
                Icons.view_column_outlined,
                settings.laminatePattern == 'straight',
                () => _setPattern(settings, 'straight'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _patternButton(
                settings,
                'Ёлочка',
                Icons.compare_arrows_rounded,
                settings.laminatePattern == 'herringbone',
                () => _setPattern(settings, 'herringbone'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 70, child: Text('Поворот', style: ZamerTypography.caption)),
            Expanded(
              child: Slider(
                value: settings.floorDirectionDeg.clamp(0, 180).toDouble(),
                min: 0,
                max: 180,
                divisions: 36,
                onChanged: (value) => setState(() => settings.floorDirectionDeg = value),
                onChangeEnd: (_) => widget.onChanged(),
              ),
            ),
            SizedBox(
              width: 38,
              child: Text(
                '${settings.floorDirectionDeg.round()}°',
                textAlign: TextAlign.end,
                style: ZamerTypography.caption,
              ),
            ),
          ],
        ),
        if (settings.laminatePattern == 'straight')
          Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: const Text('1/2'),
                selected: settings.laminateOffsetMode == 'half',
                onSelected: (_) async {
                  settings.laminateOffsetMode = 'half';
                  await widget.onChanged();
                  if (mounted) setState(() {});
                },
              ),
              ChoiceChip(
                label: const Text('1/3'),
                selected: settings.laminateOffsetMode == 'third',
                onSelected: (_) async {
                  settings.laminateOffsetMode = 'third';
                  await widget.onChanged();
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _patternButton(
    RoomMaterialSettings settings,
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZamerRadius.md),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: selected ? ZamerColors.accent : ZamerColors.surfaceLow,
          borderRadius: BorderRadius.circular(ZamerRadius.md),
          border: Border.all(
            color: selected ? ZamerColors.accent : ZamerColors.outline,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? ZamerColors.accentInk : ZamerColors.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: selected ? ZamerColors.accentInk : ZamerColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _valueRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: ZamerTypography.caption)),
        Text(
          value,
          style: const TextStyle(
            color: ZamerColors.textPrimary,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final faces = _faces();
    if (faces.isEmpty) {
      return const ZEmptyState(
        icon: Icons.layers_outlined,
        title: 'Материалы пока некуда применять',
        subtitle: 'Сначала создай хотя бы одно помещение.',
      );
    }

    final settings = _settings(faces);
    final selectedId = _selectedMaterialId(settings);
    final materials = _visibleMaterials();
    final selectedMaterial = MaterialCatalog.byId(selectedId);

    return ColoredBox(
      color: ZamerColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: ZamerColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(ZamerRadius.md),
                  border: Border.all(color: ZamerColors.accent.withValues(alpha: .55)),
                ),
                child: const Icon(Icons.layers_outlined, color: ZamerColors.accent),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Материалы', style: ZamerTypography.h2),
                    SizedBox(height: 2),
                    Text(
                      'Отделочные материалы для стен, пола и потолка',
                      style: ZamerTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  tooltip: 'Закрыть',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _surfaceTabs(),
          const SizedBox(height: 10),
          _categoryChips(),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: materials.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: .72,
            ),
            itemBuilder: (context, index) =>
                _materialCard(materials[index], selectedId, settings),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 400;
              if (!sideBySide) {
                return Column(
                  children: [
                    _preview(selectedMaterial, settings),
                    const SizedBox(height: 10),
                    _editor(selectedMaterial, settings),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 48,
                    child: _preview(selectedMaterial, settings),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 52,
                    child: _editor(selectedMaterial, settings),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
