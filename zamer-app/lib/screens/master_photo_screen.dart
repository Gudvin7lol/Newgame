import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';

class MasterPhotoScreen extends StatefulWidget {
  const MasterPhotoScreen({
    super.key,
    required this.projectTitle,
    required this.floor,
    required this.onChanged,
    this.onBack,
    this.onOpenMeasure,
    this.onOpenProfile,
  });

  final String projectTitle;
  final FloorPlan floor;
  final Future<void> Function() onChanged;
  final VoidCallback? onBack;
  final VoidCallback? onOpenMeasure;
  final VoidCallback? onOpenProfile;

  @override
  State<MasterPhotoScreen> createState() => _MasterPhotoScreenState();
}

class _MasterPhotoScreenState extends State<MasterPhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  int _filter = 0;
  int _roomIndex = 0;
  bool _saving = false;

  static const _filters = [
    ('Все', Icons.grid_view_rounded, true),
    ('Фото', Icons.image_outlined, true),
    ('Видео', Icons.videocam_outlined, false),
    ('Файлы', Icons.attach_file_rounded, false),
  ];

  List<RoomMeta> get _rooms {
    GeometryService.syncRoomMetadata(widget.floor);
    return widget.floor.roomMetas;
  }

  RoomMeta? get _room {
    final rooms = _rooms;
    if (rooms.isEmpty) return null;
    if (_roomIndex >= rooms.length) _roomIndex = 0;
    return rooms[_roomIndex];
  }

  Future<void> _persist() async {
    setState(() => _saving = true);
    try {
      await widget.onChanged();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addPhoto(ImageSource source) async {
    final room = _room;
    if (room == null || _saving) return;
    final image = await _picker.pickImage(source: source, imageQuality: 82);
    if (image == null) return;
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/room_photos');
    await folder.create(recursive: true);
    final saved = await File(image.path).copy(
      '${folder.path}/${room.id}-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    room.photoPaths.add(saved.path);
    await _persist();
  }

  Future<void> _showAddMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Добавить фото', style: ZamerTypography.h3),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Снять камерой'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _addPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Выбрать из галереи'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _addPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editNotes() async {
    final room = _room;
    if (room == null) return;
    final controller = TextEditingController(text: room.notes);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Заметка • ${room.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Кривизна стен, перенос розеток, демонтаж…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    room.notes = value;
    await _persist();
  }

  Future<void> _removePhoto(int index) async {
    final room = _room;
    if (room == null || index < 0 || index >= room.photoPaths.length) return;
    final path = room.photoPaths[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить фото?'),
        content: const Text('Фото будет удалено из проекта и локального хранилища.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    room.photoPaths.removeAt(index);
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // The project reference is authoritative; a missing local file is harmless.
    }
    await _persist();
  }

  Future<void> _pickRoom() async {
    final rooms = _rooms;
    if (rooms.length < 2) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          itemCount: rooms.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, index) => ListTile(
            leading: Icon(
              index == _roomIndex ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: index == _roomIndex ? ZamerColors.accent : null,
            ),
            title: Text(rooms[index].name),
            subtitle: Text('${rooms[index].photoPaths.length} фото'),
            onTap: () {
              setState(() => _roomIndex = index);
              Navigator.pop(sheetContext);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final rooms = _rooms;
    final photos = room?.photoPaths ?? const <String>[];

    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ZMasterTopBar(
              title: 'Фото и заметки',
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
              trailing: _saving
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Заметка',
                      onPressed: room == null ? null : _editNotes,
                      icon: const Icon(Icons.edit_note_rounded),
                    ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 92),
                children: [
                  ZMasterPanel(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        _RoomPreview(photoPath: photos.isEmpty ? null : photos.first),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.projectTitle, style: ZamerTypography.h4),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: rooms.length > 1 ? _pickRoom : null,
                                borderRadius: BorderRadius.circular(9),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: ZamerColors.surfaceHigh,
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(color: ZamerColors.outline),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.meeting_room_outlined, size: 19, color: ZamerColors.accent),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(room?.name ?? 'Нет замкнутых помещений', style: ZamerTypography.bodySmall),
                                            Text(
                                              room == null
                                                  ? 'Создай помещение в Замере'
                                                  : '${photos.length} фото  •  ${room.notes.trim().isEmpty ? 'без заметки' : 'есть заметка'}',
                                              style: ZamerTypography.caption,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (rooms.length > 1) const Icon(Icons.expand_more_rounded),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (room != null && room.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ZMasterPanel(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.sticky_note_2_outlined, color: ZamerColors.accent),
                          const SizedBox(width: 10),
                          Expanded(child: Text(room.notes, style: ZamerTypography.bodySmall)),
                          IconButton(
                            tooltip: 'Изменить',
                            onPressed: _editNotes,
                            icon: const Icon(Icons.edit_outlined, size: 19),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (var i = 0; i < _filters.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: i == _filter
                                ? FilledButton.icon(
                                    onPressed: _filters[i].$3 ? () => setState(() => _filter = i) : null,
                                    icon: Icon(_filters[i].$2, size: 17),
                                    label: Text(_filters[i].$1),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: _filters[i].$3 ? () => setState(() => _filter = i) : null,
                                    icon: Icon(_filters[i].$2, size: 17),
                                    label: Text(_filters[i].$1),
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (room == null)
                    const _EmptyMedia(
                      icon: Icons.grid_off_outlined,
                      text: 'Сначала создай замкнутое помещение в «Замере».',
                    )
                  else if (photos.isEmpty)
                    const _EmptyMedia(
                      icon: Icons.photo_camera_back_outlined,
                      text: 'Фото ещё нет. Добавь снимок камерой или из галереи.',
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: photos.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: .84,
                      ),
                      itemBuilder: (_, index) => _PhotoTile(
                        path: photos[index],
                        roomName: room.name,
                        onDelete: () => _removePhoto(index),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: room == null || _saving ? null : _showAddMenu,
        backgroundColor: ZamerColors.accent,
        foregroundColor: ZamerColors.accentInk,
        child: const Icon(Icons.camera_alt_rounded),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 72,
          decoration: const BoxDecoration(
            color: ZamerColors.surfaceLow,
            border: Border(top: BorderSide(color: ZamerColors.outline)),
          ),
          child: Row(
            children: [
              _BottomItem(
                icon: Icons.folder_outlined,
                label: 'Проект',
                selected: false,
                onTap: widget.onBack ?? () => Navigator.maybePop(context),
              ),
              _BottomItem(
                icon: Icons.straighten_outlined,
                label: 'Замер',
                selected: false,
                onTap: widget.onOpenMeasure,
              ),
              const _BottomItem(icon: Icons.camera_alt_outlined, label: 'Фото', selected: true),
              _BottomItem(
                icon: Icons.person_outline_rounded,
                label: 'Профиль',
                selected: false,
                onTap: widget.onOpenProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomPreview extends StatelessWidget {
  const _RoomPreview({this.photoPath});
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    if (path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(path),
          width: 96,
          height: 112,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _PreviewFallback(),
        ),
      );
    }
    return const _PreviewFallback();
  }
}

class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback();

  @override
  Widget build(BuildContext context) => Container(
        width: 96,
        height: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFBDAE9B), Color(0xFF60584F)],
          ),
        ),
        child: const Icon(Icons.chair_outlined, size: 44, color: Color(0xFFF1E7DA)),
      );
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.path, required this.roomName, required this.onDelete});

  final String path;
  final String roomName;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: ZamerColors.surfaceHigh,
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_outlined, color: ZamerColors.textFaint),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xD0000000)],
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: IconButton.filledTonal(
                tooltip: 'Удалить',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 9,
              child: Text(
                roomName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZamerTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _EmptyMedia extends StatelessWidget {
  const _EmptyMedia({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ZMasterPanel(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Icon(icon, size: 38, color: ZamerColors.textFaint),
              const SizedBox(height: 10),
              Text(text, textAlign: TextAlign.center, style: ZamerTypography.bodySmall),
            ],
          ),
        ),
      );
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null && !selected ? .45 : 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: selected ? ZamerColors.accent : ZamerColors.textPrimary),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: ZamerTypography.caption.copyWith(
                    color: selected ? ZamerColors.accent : ZamerColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
