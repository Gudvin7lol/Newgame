import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/project_backup_service.dart';

class MasterProfileScreen extends StatefulWidget {
  const MasterProfileScreen({
    super.key,
    required this.project,
    this.projectCount = 1,
    this.onBack,
    this.onHome,
    this.onOpenMeasure,
    this.onOpen3D,
    this.onOpenElevations,
  });

  final MeasureProject project;
  final int projectCount;
  final VoidCallback? onBack;
  final VoidCallback? onHome;
  final VoidCallback? onOpenMeasure;
  final VoidCallback? onOpen3D;
  final VoidCallback? onOpenElevations;

  @override
  State<MasterProfileScreen> createState() => _MasterProfileScreenState();
}

class _MasterProfileScreenState extends State<MasterProfileScreen> {
  static const _nameKey = 'zamer.profile.name';
  static const _roleKey = 'zamer.profile.role';

  String _name = 'Пользователь';
  String _role = 'Специалист';
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _name = prefs.getString(_nameKey)?.trim().isNotEmpty == true
          ? prefs.getString(_nameKey)!.trim()
          : 'Пользователь';
      _role = prefs.getString(_roleKey)?.trim().isNotEmpty == true
          ? prefs.getString(_roleKey)!.trim()
          : 'Специалист';
      _loading = false;
    });
  }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: _name);
    final role = TextEditingController(text: _role);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Профиль'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Имя'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: role,
              decoration: const InputDecoration(labelText: 'Специализация'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              (name.text.trim(), role.text.trim()),
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
    final nextName = result.$1.isEmpty ? 'Пользователь' : result.$1;
    final nextRole = result.$2.isEmpty ? 'Специалист' : result.$2;
    await prefs.setString(_nameKey, nextName);
    await prefs.setString(_roleKey, nextRole);
    if (!mounted) return;
    setState(() {
      _name = nextName;
      _role = nextRole;
    });
  }

  Future<void> _exportBackup() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await ProjectBackupService.encodePortable(widget.project);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'application/zip')],
        fileNameOverrides: ['zamer-${widget.project.id}.zip'],
        text: 'Полная копия проекта «${widget.project.name}» с фотографиями',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать резервную копию: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _notConnected(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature пока не подключено. Локальные данные остаются на устройстве.',
        ),
      ),
    );
  }

  void _goBack() {
    final callback = widget.onBack;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.trim().isEmpty
        ? 'П'
        : _name.trim().characters.first.toUpperCase();
    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ZMasterTopBar(
              title: 'Профиль',
              subtitle: 'Настройки и резервные копии',
              onBack: _goBack,
              onSettings: _editProfile,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                      children: [
                        InkWell(
                          onTap: _editProfile,
                          borderRadius: BorderRadius.circular(12),
                          child: ZMasterPanel(
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
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.work_outline_rounded,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            '${widget.projectCount} проектов',
                                            style: ZamerTypography.caption,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded),
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
                            border: Border.all(color: ZamerColors.outline),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.phone_android_rounded,
                                color: ZamerColors.accent,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Локальный режим',
                                      style: ZamerTypography.h4.copyWith(
                                        color: ZamerColors.accent,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Проекты и настройки хранятся на устройстве',
                                      style: ZamerTypography.bodySmall,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Облачный аккаунт будет подключён отдельно',
                                      style: ZamerTypography.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ProfileRow(
                          icon: Icons.person_outline_rounded,
                          title: 'Имя и специализация',
                          subtitle: '$_name • $_role',
                          onTap: _editProfile,
                        ),
                        const SizedBox(height: 8),
                        _ProfileRow(
                          icon: Icons.storage_outlined,
                          title: 'Резервная копия',
                          subtitle: _exporting
                              ? 'Подготавливаю архив…'
                              : 'Проект, фото и настройки в ZIP',
                          status: _exporting ? null : Icons.download_done_rounded,
                          onTap: _exporting ? null : _exportBackup,
                        ),
                        const SizedBox(height: 8),
                        _ProfileRow(
                          icon: Icons.folder_outlined,
                          title: 'Текущий проект',
                          subtitle: widget.project.name,
                          onTap: widget.onOpenMeasure ?? _goBack,
                        ),
                        const SizedBox(height: 8),
                        _ProfileRow(
                          icon: Icons.cloud_off_outlined,
                          title: 'Синхронизация',
                          subtitle: 'Облачный backend пока не подключён',
                          onTap: () => _notConnected('Синхронизация'),
                        ),
                        const SizedBox(height: 8),
                        _ProfileRow(
                          icon: Icons.workspace_premium_outlined,
                          title: 'Подписка',
                          subtitle: 'Платёжный backend пока не подключён',
                          onTap: () => _notConnected('Подписка'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ProfilePrimaryNav(
        onHome: widget.onHome ?? _goBack,
        onMeasure: widget.onOpenMeasure ?? _goBack,
        on3D: widget.onOpen3D,
        onElevations: widget.onOpenElevations,
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.status,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData? status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            opacity: onTap == null ? .65 : 1,
            child: ZMasterPanel(
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
                        Text(
                          title,
                          style: ZamerTypography.bodySmall.copyWith(
                            color: ZamerColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(subtitle, style: ZamerTypography.caption),
                        ],
                      ],
                    ),
                  ),
                  if (status != null) ...[
                    Icon(status, color: ZamerColors.success, size: 20),
                    const SizedBox(width: 8),
                  ],
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ProfilePrimaryNav extends StatelessWidget {
  const _ProfilePrimaryNav({
    required this.onHome,
    required this.onMeasure,
    this.on3D,
    this.onElevations,
  });

  final VoidCallback onHome;
  final VoidCallback onMeasure;
  final VoidCallback? on3D;
  final VoidCallback? onElevations;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback?)>[
      (Icons.home_outlined, 'Главная', onHome),
      (Icons.architecture_outlined, 'Замер', onMeasure),
      (Icons.view_in_ar_outlined, '3D', on3D),
      (Icons.view_carousel_outlined, 'Развёртки', onElevations),
      (Icons.person_rounded, 'Профиль', null),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 62,
        decoration: const BoxDecoration(
          color: ZamerColors.surfaceLow,
          border: Border(top: BorderSide(color: ZamerColors.outlineSoft)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: items[i].$3,
                  child: Opacity(
                    opacity: items[i].$3 == null && i != 4 ? .4 : 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == 4
                                ? ZamerColors.accent.withValues(alpha: .13)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            border: i == 4
                                ? Border.all(
                                    color: ZamerColors.accent.withValues(alpha: .55),
                                  )
                                : null,
                          ),
                          child: Icon(
                            items[i].$1,
                            size: 19,
                            color: i == 4
                                ? ZamerColors.accent
                                : ZamerColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: i == 4
                                ? ZamerColors.accent
                                : ZamerColors.textSecondary,
                            fontSize: 8.8,
                            fontWeight: i == 4
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
