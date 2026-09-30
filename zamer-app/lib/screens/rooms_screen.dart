import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import 'finish_layers_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key, required this.floor, required this.onChanged});

  final FloorPlan floor;
  final Future<void> Function() onChanged;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _picker = ImagePicker();

  Future<void> _open(RoomFace face, RoomMeta meta) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, modalSetState) {
          final h = meta.ceilingHeightMm ?? widget.floor.defaultHeightMm;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                ZamerSpace.lg,
                0,
                ZamerSpace.lg,
                ZamerSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ZamerColors.accent.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(ZamerRadius.md),
                            border: Border.all(
                              color: ZamerColors.accent.withValues(alpha: .38),
                            ),
                          ),
                          child: const Icon(
                            Icons.meeting_room_outlined,
                            color: ZamerColors.accent,
                          ),
                        ),
                        const SizedBox(width: ZamerSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(meta.name, style: ZamerTypography.sheetTitle),
                              const SizedBox(height: 3),
                              Text(
                                '${face.edges.length} стен • высота ${h.round()} мм',
                                style: ZamerTypography.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZamerSpace.lg),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - ZamerSpace.sm) / 2;
                        return Wrap(
                          spacing: ZamerSpace.sm,
                          runSpacing: ZamerSpace.sm,
                          children: [
                            _metric(
                              width: width,
                              icon: Icons.crop_square_rounded,
                              label: 'Площадь пола',
                              value: '${face.areaM2.toStringAsFixed(2)} м²',
                            ),
                            _metric(
                              width: width,
                              icon: Icons.polyline_outlined,
                              label: 'Периметр',
                              value: '${face.perimeterM.toStringAsFixed(2)} м',
                            ),
                            _metric(
                              width: width,
                              icon: Icons.view_carousel_outlined,
                              label: 'Площадь стен',
                              value:
                                  '${GeometryService.roomNetWallAreaM2(widget.floor, face).toStringAsFixed(2)} м²',
                            ),
                            _metric(
                              width: width,
                              icon: Icons.linear_scale_rounded,
                              label: 'Плинтус',
                              value:
                                  '${GeometryService.roomSkirtingM(widget.floor, face).toStringAsFixed(2)} м',
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: ZamerSpace.lg),
                    ZSectionTitle(
                      'Параметры помещения',
                      trailing: ZStatusChip(
                        label: '${h.round()} мм',
                        icon: Icons.height,
                      ),
                    ),
                    const SizedBox(height: ZamerSpace.sm),
                    ZPanel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ZPropertyRow(
                            icon: Icons.edit_outlined,
                            label: 'Название',
                            value: meta.name,
                            onTap: () async {
                              final c = TextEditingController(text: meta.name);
                              final v = await showDialog<String>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Название помещения'),
                                  content: TextField(
                                    controller: c,
                                    autofocus: true,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      child: const Text('Отмена'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(
                                        dialogContext,
                                        c.text.trim(),
                                      ),
                                      child: const Text('Сохранить'),
                                    ),
                                  ],
                                ),
                              );
                              if (v == null || v.isEmpty) return;
                              meta.name = v;
                              await widget.onChanged();
                              modalSetState(() {});
                            },
                          ),
                          const Divider(),
                          ZPropertyRow(
                            icon: Icons.height,
                            label: 'Высота помещения',
                            value: '${h.round()} мм',
                            onTap: () async {
                              final c = TextEditingController(
                                text: h.round().toString(),
                              );
                              final v = await showDialog<double>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Высота помещения'),
                                  content: TextField(
                                    controller: c,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      suffixText: 'мм',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      child: const Text('Отмена'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(
                                        dialogContext,
                                        double.tryParse(c.text),
                                      ),
                                      child: const Text('Сохранить'),
                                    ),
                                  ],
                                ),
                              );
                              if (v == null || v <= 0) return;
                              final key = 'room:${meta.id}:height';
                              final old = widget.floor.dimensionRecords[key];
                              if (old == null) {
                                widget.floor.dimensionRecords[key] =
                                    DimensionRecord(
                                      valueMm: v,
                                      source: DimensionSource.manual,
                                      author: 'Не указан',
                                      recordedAt: DateTime.now(),
                                    );
                              } else if (old.valueMm != v) {
                                old.revise(
                                  v,
                                  DimensionSource.manual,
                                  'Не указан',
                                );
                              }
                              meta.ceilingHeightMm = v;
                              await widget.onChanged();
                              modalSetState(() {});
                            },
                          ),
                          const Divider(),
                          ZPropertyRow(
                            icon: Icons.layers_outlined,
                            label: 'Пироги пола и стен',
                            value: 'пол ${meta.floorBuildUpMm.round()} мм',
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FinishLayersScreen(
                                    floor: widget.floor,
                                    face: face,
                                    meta: meta,
                                    onChanged: widget.onChanged,
                                  ),
                                ),
                              );
                              modalSetState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ZamerSpace.lg),
                    const ZSectionTitle('Заметки'),
                    const SizedBox(height: ZamerSpace.sm),
                    TextFormField(
                      initialValue: meta.notes,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'Кривизна стен, перенос розеток, демонтаж...',
                      ),
                      onChanged: (v) => meta.notes = v,
                      onFieldSubmitted: (_) => widget.onChanged(),
                    ),
                    const SizedBox(height: ZamerSpace.lg),
                    ZSectionTitle(
                      'Фотофиксация',
                      trailing: TextButton.icon(
                        onPressed: () async {
                          final image = await _picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 78,
                          );
                          if (image == null) return;
                          final root = await getApplicationDocumentsDirectory();
                          final folder = Directory('${root.path}/room_photos');
                          await folder.create(recursive: true);
                          final saved = await File(image.path).copy(
                            '${folder.path}/${meta.id}-${DateTime.now().microsecondsSinceEpoch}.jpg',
                          );
                          meta.photoPaths.add(saved.path);
                          await widget.onChanged();
                          modalSetState(() {});
                        },
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Добавить'),
                      ),
                    ),
                    const SizedBox(height: ZamerSpace.sm),
                    if (meta.photoPaths.isEmpty)
                      Container(
                        height: 92,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ZamerColors.surface,
                          borderRadius: BorderRadius.circular(ZamerRadius.md),
                          border: Border.all(color: ZamerColors.outlineSoft),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_camera_back_outlined,
                              color: ZamerColors.textFaint,
                            ),
                            SizedBox(width: ZamerSpace.sm),
                            Text(
                              'Фото помещения ещё не добавлены',
                              style: ZamerTypography.caption,
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: 112,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: meta.photoPaths.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: ZamerSpace.sm),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(ZamerRadius.md),
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: ZamerColors.surfaceHigh,
                              ),
                              child: Image.file(
                                File(meta.photoPaths[i]),
                                width: 142,
                                height: 108,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox(
                                  width: 142,
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: ZamerColors.textFaint,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: ZamerSpace.lg),
                    FilledButton.icon(
                      onPressed: () async {
                        await widget.onChanged();
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Готово'),
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

  Widget _metric({
    required double width,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return SizedBox(
      width: width,
      child: ZCard(
        padding: const EdgeInsets.all(ZamerSpace.md),
        backgroundColor: ZamerColors.surfaceHigh,
        borderColor: ZamerColors.outlineSoft,
        radius: ZamerRadius.md,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ZamerColors.accent.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(ZamerRadius.sm),
              ),
              child: Icon(icon, size: 17, color: ZamerColors.accent),
            ),
            const SizedBox(width: ZamerSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: ZamerTypography.caption),
                  const SizedBox(height: 2),
                  Text(value, style: ZamerTypography.measurement),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    GeometryService.syncRoomMetadata(widget.floor);
    final faces = GeometryService.roomFaces(widget.floor);
    if (faces.isEmpty) {
      return const ZEmptyState(
        icon: Icons.grid_off_outlined,
        title: 'Помещений пока нет',
        subtitle:
            'Замкни наружный контур и перегородки на вкладке «План». Комнаты появятся автоматически вместе с площадью и периметром.',
      );
    }

    final totalArea = faces.fold<double>(0, (sum, face) => sum + face.areaM2);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            ZamerSpace.md,
            ZamerSpace.sm,
            ZamerSpace.md,
            ZamerSpace.sm,
          ),
          decoration: const BoxDecoration(
            color: ZamerColors.surfaceLow,
            border: Border(
              bottom: BorderSide(color: ZamerColors.outlineSoft),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${faces.length} ${_roomWord(faces.length)}',
                  style: const TextStyle(
                    color: ZamerColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ZMeasureBadge('${totalArea.toStringAsFixed(2)} м²'),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(ZamerSpace.md),
            itemCount: faces.length,
            separatorBuilder: (_, _) => const SizedBox(height: ZamerSpace.sm),
            itemBuilder: (_, i) {
              final face = faces[i];
              final meta = widget.floor.roomMetaByKey(face.key)!;
              final height =
                  meta.ceilingHeightMm ?? widget.floor.defaultHeightMm;
              return ZCard(
                padding: EdgeInsets.zero,
                onTap: () => _open(face, meta),
                child: Padding(
                  padding: const EdgeInsets.all(ZamerSpace.md),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ZamerColors.accent.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(ZamerRadius.md),
                          border: Border.all(
                            color: ZamerColors.accent.withValues(alpha: .28),
                          ),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: ZamerColors.accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZamerSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meta.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ZamerColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: ZamerSpace.md,
                              runSpacing: ZamerSpace.xs,
                              children: [
                                _roomMeta(
                                  Icons.crop_square_rounded,
                                  '${face.areaM2.toStringAsFixed(2)} м²',
                                ),
                                _roomMeta(
                                  Icons.polyline_outlined,
                                  '${face.perimeterM.toStringAsFixed(2)} м',
                                ),
                                _roomMeta(
                                  Icons.height,
                                  '${height.round()} мм',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: ZamerSpace.sm),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: ZamerColors.textMuted,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _roomMeta(IconData icon, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: ZamerColors.textFaint),
      const SizedBox(width: 4),
      Text(value, style: ZamerTypography.caption),
    ],
  );

  static String _roomWord(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'помещение';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'помещения';
    }
    return 'помещений';
  }
}
