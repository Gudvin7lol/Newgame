import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';
import '../services/measurement_review_service.dart';
import '../services/report_service.dart';
import 'measurement_review_screen.dart';

class MasterLivePhotoScreen extends StatefulWidget {
  const MasterLivePhotoScreen({
    super.key,
    required this.project,
    required this.floor,
    required this.onChanged,
  });

  final MeasureProject project;
  final FloorPlan floor;
  final Future<void> Function() onChanged;

  @override
  State<MasterLivePhotoScreen> createState() => _MasterLivePhotoScreenState();
}

class _MasterLivePhotoScreenState extends State<MasterLivePhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  int _roomIndex = 0;
  int _filter = 0;

  List<RoomMeta> get _rooms {
    GeometryService.syncRoomMetadata(widget.floor);
    return widget.floor.roomMetas;
  }

  RoomMeta? get _room {
    final rooms = _rooms;
    if (rooms.isEmpty) return null;
    _roomIndex = _roomIndex.clamp(0, rooms.length - 1);
    return rooms[_roomIndex];
  }

  Future<void> _addPhoto(ImageSource source) async {
    final room = _room;
    if (room == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала создай замкнутое помещение в Замере')),
      );
      return;
    }
    final image = await _picker.pickImage(source: source, imageQuality: 82);
    if (image == null) return;
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/room_photos');
    await folder.create(recursive: true);
    final saved = await File(image.path).copy(
      '${folder.path}/${room.id}-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    room.photoPaths.add(saved.path);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _showAddMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.background,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Снять фото'),
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
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: const Text('Добавить заметку'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _editNote();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editNote() async {
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
            hintText: 'Что важно зафиксировать на объекте...',
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
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _deletePhoto(RoomMeta room, String path) async {
    room.photoPaths.remove(path);
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // The project must remain editable even if the source file disappeared.
    }
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _rooms;
    final room = _room;
    final photos = <({RoomMeta room, String path})>[
      for (final meta in rooms)
        for (final path in meta.photoPaths) (room: meta, path: path),
    ];
    final notes = rooms.where((meta) => meta.notes.trim().isNotEmpty).toList();

    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ZMasterTopBar(
              title: 'Фото и заметки',
              onBack: () => Navigator.maybePop(context),
              trailing: IconButton(
                onPressed: _showAddMenu,
                icon: const Icon(Icons.add_rounded),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 96),
                children: [
                  ZMasterPanel(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        _LiveRoomPreview(path: room?.photoPaths.firstOrNull),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.project.name, style: ZamerTypography.h4),
                              const SizedBox(height: 7),
                              DropdownButtonFormField<int>(
                                initialValue: rooms.isEmpty ? null : _roomIndex,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Помещение',
                                ),
                                items: [
                                  for (var i = 0; i < rooms.length; i++)
                                    DropdownMenuItem(value: i, child: Text(rooms[i].name)),
                                ],
                                onChanged: rooms.isEmpty
                                    ? null
                                    : (value) => setState(() => _roomIndex = value ?? 0),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${photos.length} фото • ${notes.length} заметок',
                                style: ZamerTypography.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final (index, label, icon) in const [
                        (0, 'Все', Icons.grid_view_rounded),
                        (1, 'Фото', Icons.image_outlined),
                        (2, 'Заметки', Icons.notes_rounded),
                      ]) ...[
                        if (index > 0) const SizedBox(width: 6),
                        Expanded(
                          child: index == _filter
                              ? FilledButton.icon(
                                  onPressed: () => setState(() => _filter = index),
                                  icon: Icon(icon, size: 17),
                                  label: Text(label),
                                )
                              : OutlinedButton.icon(
                                  onPressed: () => setState(() => _filter = index),
                                  icon: Icon(icon, size: 17),
                                  label: Text(label),
                                ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  if ((_filter == 0 || _filter == 1) && photos.isNotEmpty)
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
                      itemBuilder: (_, index) {
                        final item = photos[index];
                        return _LivePhotoTile(
                          path: item.path,
                          roomName: item.room.name,
                          onDelete: () => _deletePhoto(item.room, item.path),
                        );
                      },
                    )
                  else if (_filter == 1 && photos.isEmpty)
                    const _MasterEmpty(
                      icon: Icons.photo_camera_back_outlined,
                      title: 'Фото пока нет',
                      subtitle: 'Сделай фото камерой или выбери его из галереи.',
                    ),
                  if ((_filter == 0 || _filter == 2) && notes.isNotEmpty) ...[
                    if (_filter == 0 && photos.isNotEmpty) const SizedBox(height: 14),
                    Text('Заметки', style: ZamerTypography.h4),
                    const SizedBox(height: 8),
                    for (final meta in notes) ...[
                      ZMasterPanel(
                        padding: const EdgeInsets.all(12),
                        child: InkWell(
                          onTap: () {
                            _roomIndex = rooms.indexOf(meta);
                            _editNote();
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.sticky_note_2_outlined, color: ZamerColors.accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(meta.name, style: ZamerTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 3),
                                    Text(meta.notes, maxLines: 4, overflow: TextOverflow.ellipsis, style: ZamerTypography.caption),
                                  ],
                                ),
                              ),
                              const Icon(Icons.edit_outlined, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ] else if (_filter == 2)
                    const _MasterEmpty(
                      icon: Icons.notes_outlined,
                      title: 'Заметок пока нет',
                      subtitle: 'Добавь заметку к выбранному помещению.',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        backgroundColor: ZamerColors.accent,
        foregroundColor: ZamerColors.accentInk,
        child: const Icon(Icons.camera_alt_rounded),
      ),
    );
  }
}

class MasterLiveDocumentationScreen extends StatefulWidget {
  const MasterLiveDocumentationScreen({
    super.key,
    required this.project,
    required this.floor,
  });

  final MeasureProject project;
  final FloorPlan floor;

  @override
  State<MasterLiveDocumentationScreen> createState() => _MasterLiveDocumentationScreenState();
}

class _MasterLiveDocumentationScreenState extends State<MasterLiveDocumentationScreen> {
  bool _working = false;

  Future<void> _share() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await ReportService.shareFloorPdf(widget.project, widget.floor);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось собрать PDF: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _preview() async {
    await Printing.layoutPdf(
      name: 'Замер_${widget.project.name}_${widget.floor.name}.pdf',
      onLayout: (_) => ReportService.buildFloorPdf(widget.project, widget.floor),
    );
  }

  @override
  Widget build(BuildContext context) {
    GeometryService.syncRoomMetadata(widget.floor);
    final faces = GeometryService.roomFaces(widget.floor);
    final area = faces.fold<double>(0, (sum, face) => sum + face.areaM2);
    final issues = MeasurementReviewService.review(widget.floor);
    final elevationCount = GeometryService.elevationRuns(widget.floor).length;

    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ZMasterTopBar(
              title: 'Документация',
              onBack: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                children: [
                  Text(widget.project.name, style: ZamerTypography.h2),
                  const SizedBox(height: 5),
                  Text(
                    '${faces.length} пом. • ${area.toStringAsFixed(1)} м² • ${issues.length} замечаний',
                    style: ZamerTypography.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  _LiveDocumentCard(
                    icon: Icons.architecture_outlined,
                    title: 'План 2D',
                    subtitle: '${widget.floor.walls.length} стен • ${widget.floor.measures.length} контрольных размеров',
                    status: widget.floor.walls.isEmpty ? 'Пусто' : 'Готов',
                  ),
                  const SizedBox(height: 8),
                  _LiveDocumentCard(
                    icon: Icons.view_in_ar_outlined,
                    title: '3D виды',
                    subtitle: '${widget.floor.planObjects.length} объектов • PBR-сцена',
                    status: widget.floor.walls.isEmpty ? 'Пусто' : 'Готово',
                  ),
                  const SizedBox(height: 8),
                  _LiveDocumentCard(
                    icon: Icons.view_carousel_outlined,
                    title: 'Развёртки',
                    subtitle: 'Автоматически по внутреннему периметру',
                    status: '$elevationCount шт.',
                  ),
                  const SizedBox(height: 8),
                  _LiveDocumentCard(
                    icon: Icons.table_chart_outlined,
                    title: 'Спецификация',
                    subtitle: 'Материалы, электрика, инженерия и объекты',
                    status: 'В PDF',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _working ? null : _share,
                      icon: _working
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.description_outlined),
                      label: Text(_working ? 'Собираю PDF…' : 'Собрать PDF-комплект'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _preview,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Предпросмотр'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MasterLiveControlScreen extends StatelessWidget {
  const MasterLiveControlScreen({
    super.key,
    required this.project,
    required this.floor,
  });

  final MeasureProject project;
  final FloorPlan floor;

  @override
  Widget build(BuildContext context) {
    final issues = MeasurementReviewService.review(floor);
    int count(MeasurementIssueKind kind) => issues.where((issue) => issue.kind == kind).length;
    final critical = count(MeasurementIssueKind.openContour) +
        count(MeasurementIssueKind.intersection) +
        count(MeasurementIssueKind.discrepancy);
    final missing = count(MeasurementIssueKind.missingOffset) +
        count(MeasurementIssueKind.missingHeight) +
        count(MeasurementIssueKind.missingDiagonal);
    final rooms = GeometryService.roomFaces(floor).length;

    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ZMasterTopBar(
              title: 'Контроль',
              onBack: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
                children: [
                  Text(project.name, style: ZamerTypography.h4),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (critical == 0 ? ZamerColors.success : ZamerColors.warning)
                          .withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: critical == 0 ? ZamerColors.success : ZamerColors.warning,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: critical == 0 ? ZamerColors.success : ZamerColors.warning,
                          child: Icon(
                            critical == 0 ? Icons.check_rounded : Icons.priority_high_rounded,
                            color: ZamerColors.accentInk,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                issues.isEmpty ? 'Проект проверен' : 'Нужна проверка',
                                style: ZamerTypography.h4,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${issues.length} замечаний • $critical критичных',
                                style: ZamerTypography.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Проверки проекта', style: ZamerTypography.h4),
                  const SizedBox(height: 8),
                  _LiveCheckRow(
                    ok: count(MeasurementIssueKind.openContour) == 0,
                    icon: Icons.crop_free_rounded,
                    title: 'Контуры помещений',
                    subtitle: '$rooms помещений • ${count(MeasurementIssueKind.openContour)} незамкнутых узлов',
                  ),
                  const SizedBox(height: 8),
                  _LiveCheckRow(
                    ok: count(MeasurementIssueKind.discrepancy) == 0,
                    icon: Icons.functions_rounded,
                    title: 'Суммы размеров',
                    subtitle: '${count(MeasurementIssueKind.discrepancy)} расхождений от 5 мм',
                  ),
                  const SizedBox(height: 8),
                  _LiveCheckRow(
                    ok: count(MeasurementIssueKind.intersection) == 0,
                    icon: Icons.polyline_outlined,
                    title: 'Геометрия стен',
                    subtitle: '${count(MeasurementIssueKind.intersection)} пересечений • ${count(MeasurementIssueKind.acuteAngle)} острых углов',
                  ),
                  const SizedBox(height: 8),
                  _LiveCheckRow(
                    ok: missing == 0,
                    icon: Icons.storage_outlined,
                    title: 'Источники размеров',
                    subtitle: '$missing размеров требуют подтверждения',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(builder: (_) => MeasurementReviewScreen(floor: floor)),
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Показать замечания на плане'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MasterLiveProfileScreen extends StatefulWidget {
  const MasterLiveProfileScreen({
    super.key,
    required this.projectCount,
  });

  final int projectCount;

  @override
  State<MasterLiveProfileScreen> createState() => _MasterLiveProfileScreenState();
}

class _MasterLiveProfileScreenState extends State<MasterLiveProfileScreen> {
  static const _nameKey = 'zamer.profile.name';
  static const _roleKey = 'zamer.profile.role';
  static const _qualityKey = 'zamer.profile.highQuality';
  String _name = 'Пользователь';
  String _role = 'Строитель';
  bool _highQuality = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _name = prefs.getString(_nameKey) ?? 'Пользователь';
      _role = prefs.getString(_roleKey) ?? 'Строитель';
      _highQuality = prefs.getBool(_qualityKey) ?? true;
    });
  }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: _name);
    final role = TextEditingController(text: _role);
    final result = await showDialog<({String name, String role})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Профиль'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Имя')),
            const SizedBox(height: 10),
            TextField(controller: role, decoration: const InputDecoration(labelText: 'Роль')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              (name: name.text.trim(), role: role.text.trim()),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    name.dispose();
    role.dispose();
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, result.name.isEmpty ? 'Пользователь' : result.name);
    await prefs.setString(_roleKey, result.role.isEmpty ? 'Строитель' : result.role);
    await _load();
  }

  Future<void> _toggleQuality(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_qualityKey, value);
    if (mounted) setState(() => _highQuality = value);
  }

  void _aboutPro() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.background,
      showDragHandle: true,
      builder: (sheetContext) => const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ZAMER PRO', style: ZamerTypography.h2),
              SizedBox(height: 8),
              Text(
                'Платёжный контур ещё не подключён к этой тестовой сборке. '
                'Функции приложения не блокируются искусственной подпиской.',
                style: ZamerTypography.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.trim().isEmpty ? 'П' : _name.trim().characters.first.toUpperCase();
    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ZMasterTopBar(
              title: 'Профиль',
              onBack: () => Navigator.maybePop(context),
              onSettings: _editProfile,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                children: [
                  ZMasterPanel(
                    child: InkWell(
                      onTap: _editProfile,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: ZamerColors.accent,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: ZamerColors.accentInk,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_name, style: ZamerTypography.h3),
                                const SizedBox(height: 2),
                                Text(_role, style: ZamerTypography.bodySmall),
                                const SizedBox(height: 5),
                                Text('${widget.projectCount} проектов', style: ZamerTypography.caption),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit_outlined),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ZamerColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ZamerColors.accent, width: 1.4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded, color: ZamerColors.accent, size: 34),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PRO', style: ZamerTypography.h3.copyWith(color: ZamerColors.accent)),
                              const SizedBox(height: 3),
                              const Text('Подготовлено к подключению оплаты', style: ZamerTypography.caption),
                            ],
                          ),
                        ),
                        FilledButton(onPressed: _aboutPro, child: const Text('Подробнее')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ZMasterPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _highQuality,
                      onChanged: _toggleQuality,
                      secondary: const Icon(Icons.high_quality_outlined),
                      title: const Text('Высокое качество 3D'),
                      subtitle: const Text('Использовать Quality как основной realtime-режим'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _LiveProfileRow(
                    icon: Icons.cloud_done_outlined,
                    title: 'Хранилище проектов',
                    subtitle: 'Локальное сохранение и резервная запись включены',
                  ),
                  const SizedBox(height: 8),
                  const _LiveProfileRow(
                    icon: Icons.devices_outlined,
                    title: 'Устройство',
                    subtitle: 'Текущий Android-профиль',
                  ),
                  const SizedBox(height: 8),
                  const _LiveProfileRow(
                    icon: Icons.headset_mic_outlined,
                    title: 'Поддержка',
                    subtitle: 'Диагностика доступна из рабочих экранов',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveRoomPreview extends StatelessWidget {
  const _LiveRoomPreview({required this.path});
  final String? path;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 96,
          height: 112,
          child: path == null
              ? const ColoredBox(
                  color: ZamerColors.surfaceHigh,
                  child: Icon(Icons.chair_outlined, size: 42),
                )
              : Image.file(
                  File(path!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: ZamerColors.surfaceHigh,
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
        ),
      );
}

class _LivePhotoTile extends StatelessWidget {
  const _LivePhotoTile({required this.path, required this.roomName, required this.onDelete});
  final String path;
  final String roomName;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: ZamerColors.surfaceHigh,
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .56),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(roomName, style: ZamerTypography.caption.copyWith(color: Colors.white)),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                tooltip: 'Удалить',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
              ),
            ),
          ],
        ),
      );
}

class _LiveDocumentCard extends StatelessWidget {
  const _LiveDocumentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) => ZMasterPanel(
        padding: const EdgeInsets.all(11),
        child: Row(
          children: [
            Container(
              width: 104,
              height: 78,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ZamerColors.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ZamerColors.outline),
              ),
              child: Icon(icon, size: 38, color: ZamerColors.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ZamerTypography.h4),
                  const SizedBox(height: 3),
                  Text(subtitle, style: ZamerTypography.caption),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ZamerColors.accent.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: ZamerColors.accent),
                    ),
                    child: Text(status, style: ZamerTypography.caption.copyWith(color: ZamerColors.accent)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LiveCheckRow extends StatelessWidget {
  const _LiveCheckRow({required this.ok, required this.icon, required this.title, required this.subtitle});
  final bool ok;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = ok ? ZamerColors.success : ZamerColors.warning;
    return ZMasterPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: Icon(ok ? Icons.check_rounded : Icons.priority_high_rounded, color: ZamerColors.accentInk, size: 19),
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ZamerColors.surfaceHigh,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: ZamerColors.outline),
            ),
            child: Icon(icon, size: 23),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ZamerTypography.bodySmall.copyWith(color: ZamerColors.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: ZamerTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveProfileRow extends StatelessWidget {
  const _LiveProfileRow({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => ZMasterPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ZamerColors.surfaceHigh,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: ZamerColors.outline),
              ),
              child: Icon(icon, size: 23),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ZamerTypography.bodySmall.copyWith(color: ZamerColors.textPrimary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: ZamerTypography.caption),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MasterEmpty extends StatelessWidget {
  const _MasterEmpty({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => ZMasterPanel(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(icon, size: 38, color: ZamerColors.textMuted),
              const SizedBox(height: 8),
              Text(title, style: ZamerTypography.h4),
              const SizedBox(height: 4),
              Text(subtitle, textAlign: TextAlign.center, style: ZamerTypography.caption),
            ],
          ),
        ),
      );
}
