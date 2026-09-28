import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

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
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) {
          final h = meta.ceilingHeightMm ?? widget.floor.defaultHeightMm;
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
                      meta.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _metric('Пол', '${face.areaM2.toStringAsFixed(2)} м²'),
                        _metric(
                          'Периметр',
                          '${face.perimeterM.toStringAsFixed(2)} м',
                        ),
                        _metric(
                          'Стены',
                          '${GeometryService.roomNetWallAreaM2(widget.floor, face).toStringAsFixed(2)} м²',
                        ),
                        _metric(
                          'Плинтус',
                          '${GeometryService.roomSkirtingM(widget.floor, face).toStringAsFixed(2)} м',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final c = TextEditingController(text: meta.name);
                        final v = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Название помещения'),
                            content: TextField(controller: c, autofocus: true),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Отмена'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(context, c.text.trim()),
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
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Переименовать'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final c = TextEditingController(
                          text: h.round().toString(),
                        );
                        final v = await showDialog<double>(
                          context: context,
                          builder: (context) => AlertDialog(
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
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Отмена'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(
                                  context,
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
                          widget.floor.dimensionRecords[key] = DimensionRecord(
                            valueMm: v,
                            source: DimensionSource.manual,
                            author: 'Не указан',
                            recordedAt: DateTime.now(),
                          );
                        } else if (old.valueMm != v) {
                          old.revise(v, DimensionSource.manual, 'Не указан');
                        }
                        meta.ceilingHeightMm = v;
                        await widget.onChanged();
                        modalSetState(() {});
                      },
                      icon: const Icon(Icons.height),
                      label: Text('Высота ${h.round()} мм'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: () async {
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
                      icon: const Icon(Icons.layers_outlined),
                      label: Text(
                        'Пироги пола и стен • пол ${meta.floorBuildUpMm.round()} мм',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Заметки',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Фото',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            final image = await _picker.pickImage(
                              source: ImageSource.camera,
                              imageQuality: 78,
                            );
                            if (image == null) return;
                            final root =
                                await getApplicationDocumentsDirectory();
                            final folder = Directory(
                              '${root.path}/room_photos',
                            );
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
                      ],
                    ),
                    if (meta.photoPaths.isNotEmpty)
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: meta.photoPaths.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(meta.photoPaths[i]),
                              width: 130,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 130,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () async {
                        await widget.onChanged();
                        if (context.mounted) Navigator.pop(context);
                      },
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

  Widget _metric(String label, String value) => Container(
    width: 150,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F3F7),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7480)),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    GeometryService.syncRoomMetadata(widget.floor);
    final faces = GeometryService.roomFaces(widget.floor);
    if (faces.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Пока нет замкнутых помещений. Построй наружный контур и перегородки на вкладке «План».',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: faces.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final face = faces[i];
        final meta = widget.floor.roomMetaByKey(face.key)!;
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text(
              meta.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${face.areaM2.toStringAsFixed(2)} м² • стены ${GeometryService.roomNetWallAreaM2(widget.floor, face).toStringAsFixed(1)} м² • ${face.edges.length} стен',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(face, meta),
          ),
        );
      },
    );
  }
}
