import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/material_service.dart';
import '../services/material_catalog.dart';
import 'estimate_screen.dart';


Future<int?> _pickFinishColor(
  BuildContext context, {
  required int initialArgb,
  required String title,
}) async {
  var selected = Color(initialArgb);
  final controller = TextEditingController(
    text: selected.toARGB32().toRadixString(16).substring(2).toUpperCase(),
  );
  const palette = <Color>[
    Color(0xFFF6F3EC),
    Color(0xFFFFFFFF),
    Color(0xFFD8C8AF),
    Color(0xFFCFC7BC),
    Color(0xFFB8B7B2),
    Color(0xFF686C6F),
    Color(0xFF34383B),
    Color(0xFFC7D1C2),
    Color(0xFFAEB89F),
    Color(0xFFB2C3C9),
    Color(0xFF879FAA),
    Color(0xFFD3A18B),
    Color(0xFFC27E69),
    Color(0xFFE0CFB8),
    Color(0xFF8B6E58),
    Color(0xFF58736A),
  ];

  return showDialog<int>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialog) {
        void applyHex(String raw) {
          final text = raw.trim().replaceAll('#', '');
          if (text.length != 6) return;
          final rgb = int.tryParse(text, radix: 16);
          if (rgb == null) return;
          setDialog(() => selected = Color(0xFF000000 | rgb));
        }

        Widget slider(String label, int value, ValueChanged<int> change) => Row(
          children: [
            SizedBox(width: 22, child: Text(label)),
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 255,
                divisions: 255,
                onChanged: (v) {
                  change(v.round());
                  controller.text = selected
                      .toARGB32()
                      .toRadixString(16)
                      .substring(2)
                      .toUpperCase();
                },
              ),
            ),
            SizedBox(width: 34, child: Text('$value')),
          ],
        );

        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: selected,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x33000000)),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: palette.map((color) => InkWell(
                    onTap: () => setDialog(() {
                      selected = color;
                      controller.text = color
                          .toARGB32()
                          .toRadixString(16)
                          .substring(2)
                          .toUpperCase();
                    }),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.toARGB32() == selected.toARGB32()
                              ? Theme.of(context).colorScheme.primary
                              : const Color(0x33000000),
                          width: color.toARGB32() == selected.toARGB32() ? 3 : 1,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'HEX',
                    prefixText: '#',
                    hintText: 'D8C8AF',
                  ),
                  onChanged: applyHex,
                ),
                slider('R', (selected.r * 255).round(), (v) {
                  selected = Color.fromARGB(
                    255,
                    v,
                    (selected.g * 255).round(),
                    (selected.b * 255).round(),
                  );
                }),
                slider('G', (selected.g * 255).round(), (v) {
                  selected = Color.fromARGB(
                    255,
                    (selected.r * 255).round(),
                    v,
                    (selected.b * 255).round(),
                  );
                }),
                slider('B', (selected.b * 255).round(), (v) {
                  selected = Color.fromARGB(
                    255,
                    (selected.r * 255).round(),
                    (selected.g * 255).round(),
                    v,
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected.toARGB32()),
              child: const Text('Применить'),
            ),
          ],
        );
      },
    ),
  );
}

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({
    super.key,
    required this.floor,
    required this.onChanged,
    this.project,
  });
  final FloorPlan floor;
  final MeasureProject? project;
  final Future<void> Function() onChanged;

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  String? _faceKey;

  Future<void> _settings(RoomMeta meta) async {
    final s = meta.materials;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) {
          Future<void> numEdit(
            String title,
            double initial,
            void Function(double) set, {
            String suffix = '',
          }) async {
            final c = TextEditingController(text: initial.toString());
            final v = await showDialog<double>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(title),
                content: TextField(
                  controller: c,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(suffixText: suffix),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      double.tryParse(c.text.replaceAll(',', '.')),
                    ),
                    child: const Text('Готово'),
                  ),
                ],
              ),
            );
            if (v == null) return;
            set(v);
            await widget.onChanged();
            setModal(() {});
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                0,
                18,
                18 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Настройка материалов',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Пол',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value:
                          MaterialCatalog.presets.any(
                            (e) => e.id == s.floorMaterialId,
                          )
                          ? s.floorMaterialId
                          : MaterialCatalog.floorFinishes.first.id,
                      decoration: const InputDecoration(
                        labelText: 'Материал для визуализации',
                      ),
                      items: MaterialCatalog.floorFinishes
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: m.color,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: const Color(0x33000000),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(m.name)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        s.floorMaterialId = v;
                        await widget.onChanged();
                        setModal(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      value: 'laminate',
                      groupValue: s.floorMode,
                      title: const Text('Ламинат / SPC'),
                      onChanged: (v) async {
                        s.floorMode = v!;
                        await widget.onChanged();
                        setModal(() {});
                      },
                    ),
                    RadioListTile<String>(
                      value: 'none',
                      groupValue: s.floorMode,
                      title: const Text('Без ламината'),
                      onChanged: (v) async {
                        s.floorMode = v!;
                        await widget.onChanged();
                        setModal(() {});
                      },
                    ),
                    ListTile(
                      title: const Text('Запас ламината'),
                      trailing: Text('${s.floorWastePct.toStringAsFixed(0)}%'),
                      onTap: () => numEdit(
                        'Запас ламината',
                        s.floorWastePct,
                        (v) => s.floorWastePct = v,
                        suffix: '%',
                      ),
                    ),
                    ListTile(
                      title: const Text('Площадь в пачке'),
                      trailing: Text(
                        '${s.floorPackageM2.toStringAsFixed(2)} м²',
                      ),
                      onTap: () => numEdit(
                        'Площадь в пачке',
                        s.floorPackageM2,
                        (v) => s.floorPackageM2 = v,
                        suffix: 'м²',
                      ),
                    ),
                    SwitchListTile(
                      value: s.floorTile,
                      title: const Text('Плитка на пол'),
                      onChanged: (v) async {
                        s.floorTile = v;
                        await widget.onChanged();
                        setModal(() {});
                      },
                    ),
                    const Divider(),
                    Text(
                      'Стены',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value:
                          MaterialCatalog.presets.any(
                            (e) => e.id == s.wallMaterialId,
                          )
                          ? s.wallMaterialId
                          : MaterialCatalog.wallFinishes.first.id,
                      decoration: const InputDecoration(
                        labelText: 'Основная поверхность стены',
                      ),
                      items: MaterialCatalog.wallFinishes
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: m.color,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: const Color(0x33000000),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(m.name)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        s.wallMaterialId = v;
                        final preset = MaterialCatalog.byId(v);
                        if (preset.pattern == 'paint') {
                          s.wallPaintColorArgb = preset.color.toARGB32();
                        }
                        await widget.onChanged();
                        setModal(() {});
                      },
                    ),
                    if (s.wallMaterialId.startsWith('paint-'))
                      ListTile(
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(s.wallPaintColorArgb == 0
                                ? MaterialCatalog.byId(s.wallMaterialId).color.toARGB32()
                                : s.wallPaintColorArgb),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: const Color(0x33000000)),
                          ),
                        ),
                        title: const Text('Цвет покраски'),
                        subtitle: Text(
                          '#${(s.wallPaintColorArgb == 0 ? MaterialCatalog.byId(s.wallMaterialId).color.toARGB32() : s.wallPaintColorArgb).toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                        ),
                        trailing: const Icon(Icons.palette_outlined),
                        onTap: () async {
                          final color = await _pickFinishColor(
                            context,
                            initialArgb: s.wallPaintColorArgb == 0
                                ? MaterialCatalog.byId(s.wallMaterialId).color.toARGB32()
                                : s.wallPaintColorArgb,
                            title: 'Цвет краски',
                          );
                          if (color == null) return;
                          s.wallPaintColorArgb = color;
                          await widget.onChanged();
                          setModal(() {});
                        },
                      ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: s.wallPlaster,
                      title: const Text('Штукатурка'),
                      onChanged: (v) async {
                        s.wallPlaster = v;
                        await widget.onChanged();
                        setModal(() {});
                      },
                    ),
                    if (s.wallPlaster)
                      ListTile(
                        title: const Text('Толщина штукатурки'),
                        trailing: Text(
                          '${s.plasterThicknessMm.toStringAsFixed(0)} мм',
                        ),
                        onTap: () => numEdit(
                          'Толщина штукатурки',
                          s.plasterThicknessMm,
                          (v) => s.plasterThicknessMm = v,
                          suffix: 'мм',
                        ),
                      ),
                    SwitchListTile(
                      value: s.wallPutty,
                      title: const Text('Шпаклёвка'),
                      onChanged: (v) async {
                        s.wallPutty = v;
                        await widget.onChanged();
                        setModal(() {});
                      },
                    ),
                    SwitchListTile(
                      value: s.wallPaint,
                      title: const Text('Краска'),
                      onChanged: (v) async {
                        s.wallPaint = v;
                        await widget.onChanged();
                        setModal(() {});
                      },
                    ),
                    if (s.wallPaint)
                      ListTile(
                        title: const Text('Слоёв краски'),
                        trailing: Text('${s.paintCoats}'),
                        onTap: () => numEdit(
                          'Слоёв краски',
                          s.paintCoats.toDouble(),
                          (v) => s.paintCoats = v.round(),
                        ),
                      ),
                    SwitchListTile(
                      value: s.wallTile,
                      title: const Text('Плитка на стены'),
                      onChanged: (v) async {
                        s.wallTile = v;
                        await widget.onChanged();
                        setModal(() {});
                      },
                    ),
                    if (s.wallTile) ...[
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value:
                            MaterialCatalog.presets.any(
                              (e) => e.id == s.wallTileMaterialId,
                            )
                            ? s.wallTileMaterialId
                            : 'tile-light-stone',
                        decoration: const InputDecoration(
                          labelText: 'Коллекция плитки для 3D',
                        ),
                        items: MaterialCatalog.presets
                            .where((m) => m.category == 'Плитка')
                            .map(
                              (m) => DropdownMenuItem(
                                value: m.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: m.color,
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: const Color(0x33000000),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(child: Text(m.name)),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) async {
                          if (v == null) return;
                          s.wallTileMaterialId = v;
                          s.wallTileTintArgb = 0xFFFFFFFF;
                          await widget.onChanged();
                          setModal(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 96,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: MaterialCatalog.tileFinishes.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final material = MaterialCatalog.tileFinishes[index];
                            final selected = material.id == s.wallTileMaterialId;
                            return InkWell(
                              onTap: () async {
                                s.wallTileMaterialId = material.id;
                                s.wallTileTintArgb = 0xFFFFFFFF;
                                await widget.onChanged();
                                setModal(() {});
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 112,
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: (material.textureAssetMobile ?? material.textureAsset) == null
                                            ? ColoredBox(color: material.color)
                                            : Image.asset(
                                                material.textureAssetMobile ??
                                                    material.textureAsset!,
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      material.name.replaceFirst('Керамогранит ', ''),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      ListTile(
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(s.wallTileTintArgb),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: const Color(0x33000000)),
                          ),
                        ),
                        title: const Text('Оттенок плитки'),
                        subtitle: const Text('Белый = исходный рисунок коллекции'),
                        trailing: const Icon(Icons.color_lens_outlined),
                        onTap: () async {
                          final color = await _pickFinishColor(
                            context,
                            initialArgb: s.wallTileTintArgb,
                            title: 'Оттенок плитки',
                          );
                          if (color == null) return;
                          s.wallTileTintArgb = color;
                          await widget.onChanged();
                          setModal(() {});
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Готово'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    GeometryService.syncRoomMetadata(widget.floor);
    final faces = GeometryService.roomFaces(widget.floor);
    if (faces.isEmpty)
      return const Center(child: Text('Сначала создай помещения.'));
    _faceKey ??= faces.first.key;
    final face = faces.firstWhere(
      (f) => f.key == _faceKey,
      orElse: () => faces.first,
    );
    final meta = widget.floor.roomMetaByKey(face.key)!;
    final estimates = MaterialService.roomEstimates(widget.floor, face, meta);
    final partitions = MaterialService.partitionTakeoff(widget.floor);
    final wallVolumes = MaterialService.wallConstructionVolumes(widget.floor);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        DropdownButtonFormField<String>(
          value: face.key,
          decoration: const InputDecoration(labelText: 'Помещение'),
          items: faces.map((f) {
            final m = widget.floor.roomMetaByKey(f.key)!;
            return DropdownMenuItem(
              value: f.key,
              child: Text('${m.name} • ${f.areaM2.toStringAsFixed(2)} м²'),
            );
          }).toList(),
          onChanged: (v) => setState(() => _faceKey = v),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                'Отделочные материалы',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              onPressed: () => _settings(meta),
              icon: const Icon(Icons.tune),
              tooltip: 'Настроить',
            ),
          ],
        ),
        if (widget.project != null)
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EstimateScreen(
                  project: widget.project!,
                  onChanged: widget.onChanged,
                ),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Автосмета по проекту'),
          ),
        const SizedBox(height: 6),
        ...estimates.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                title: Text(
                  e.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: e.note.isEmpty ? null : Text(e.note),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${e.quantity.toStringAsFixed(e.quantity >= 100 ? 0 : 2)} ${e.unit}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (e.packages != null)
                      Text(
                        '${e.packages} ${e.packageLabel ?? 'уп.'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Перегородки ГКЛ',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _row(
                  'Длина перегородок',
                  '${partitions.wallLengthM.toStringAsFixed(2)} м',
                ),
                _row(
                  'ГКЛ с двух сторон +10%',
                  '${partitions.boardAreaM2.toStringAsFixed(2)} м²',
                ),
                _row('Листы ГКЛ 1200×2500', '${partitions.boardSheets} шт.'),
                _row('Стоечный профиль, шаг 600', '${partitions.studs} шт.'),
                _row(
                  'Направляющий профиль +5%',
                  '${partitions.trackM.toStringAsFixed(2)} м',
                ),
                _row(
                  'Минвата +5%',
                  '${partitions.insulationM2.toStringAsFixed(2)} м²',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Объём стен по материалам',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: wallVolumes.isEmpty
                ? const Text('Нет стен')
                : Column(
                    children: wallVolumes.entries
                        .map(
                          (e) =>
                              _row(e.key, '${e.value.toStringAsFixed(3)} м³'),
                        )
                        .toList(),
                  ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _row(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(a)),
        Text(b, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
