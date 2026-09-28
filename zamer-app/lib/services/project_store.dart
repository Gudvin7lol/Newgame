import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ProjectStore {
  static const _key = 'zamer_projects_v3';
  static const _backupKey = 'zamer_projects_v3_backup';
  static Future<void> _pendingSave = Future<void>.value();

  Future<ProjectLoadResult> loadWithStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final primary = _parse(raw);
    if (primary != null) return ProjectLoadResult(primary);
    final backup = _parse(prefs.getString(_backupKey));
    if (backup != null) return ProjectLoadResult(backup, recovered: true);
    if (raw == null || raw.isEmpty) return const ProjectLoadResult([]);
    return const ProjectLoadResult([], unreadable: true);
  }

  Future<List<MeasureProject>> load() async => (await loadWithStatus()).projects;

  static List<MeasureProject>? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => MeasureProject.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> save(List<MeasureProject> projects) async {
    // Capture the state now, before another edit mutates these same objects.
    final snapshot = jsonEncode(projects.map((e) => e.toJson()).toList());
    final write = _pendingSave.catchError((Object _) {}).then((_) => _write(snapshot));
    _pendingSave = write;
    await write;
  }

  Future<void> _write(String snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString(_key);
    if (_parse(old) != null && !await prefs.setString(_backupKey, old!)) {
      throw StateError('Не удалось создать резервную копию проектов');
    }
    if (!await prefs.setString(_key, snapshot)) {
      throw StateError('Не удалось сохранить проекты');
    }
  }
}

class ProjectLoadResult {
  const ProjectLoadResult(this.projects, {this.recovered = false, this.unreadable = false});
  final List<MeasureProject> projects;
  final bool recovered;
  final bool unreadable;
}
