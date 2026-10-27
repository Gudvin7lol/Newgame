import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/models.dart';
import 'project_backup_service.dart';

/// One portable ZIP containing independently restorable v2 project ZIPs.
/// Size bounds avoid unbounded memory use from nested archives.
class PortablePortfolioBackup {
  const PortablePortfolioBackup(this.projects);

  final List<PortableProjectBackup> projects;

  /// Restore to NEW project IDs. Never overwrite existing project data.
  Future<List<MeasureProject>> importAsCopies(
    Directory documents,
    String Function(int index) nextId,
  ) async {
    final output = <MeasureProject>[];
    final allocated = <String>{};
    try {
      for (var i = 0; i < projects.length; i++) {
        final id = nextId(i);
        if (id.trim().isEmpty || allocated.contains(id) ||
            !RegExp(r'^[a-zA-Z0-9_-]+
          throw const FormatException(
            'Идентификатор импортируемого проекта некорректен.',
          );
        }
        final destination = Directory(
            '${documents.path}/zamer_photos/$id');
        if (await destination.exists()) {
          throw const FormatException(
              'Папка проекта уже существует. Импорт остановлен.');
        }
        // Track only NEW folders so cleanup can never delete user data.
        allocated.add(id);
        output.add(await projects[i].importAsCopy(id, documents));
      }
      return output;
    } catch (_) {
      for (final id in allocated) {
        final folder = Directory('${documents.path}/zamer_photos/$id');
        if (await folder.exists()) {
          await folder.delete(recursive: true);
        }
      }
      rethrow;
    }
  }
}

class ProjectPortfolioBackupService {
  const ProjectPortfolioBackupService._();

  static const format = 'ru.zamer.portfolio';
  static const version = 1;
  static const maxProjects = 30;
  static const maxBytes = 160 * 1024 * 1024;

  static String _filename(int index) =>
      'projects/${index.toString().padLeft(3, '0')}.zip';

  static Future<Uint8List> encode(List<MeasureProject> projects) async {
    if (projects.isEmpty || projects.length > maxProjects) {
      throw const FormatException('В архиве должно быть от 1 до 30 проектов.');
    }
    final ids = projects.map((p) => p.id).toSet();
    if (ids.length != projects.length) {
      throw const FormatException(
        'Найдены повторяющиеся идентификаторы проектов.',
      );
    }
    final archive = Archive();
    final manifest = <Map<String, String>>[];
    var total = 0;
    for (var i = 0; i < projects.length; i++) {
      final data = await ProjectBackupService.encodePortable(projects[i]);
      total += data.length;
      if (total > maxBytes) {
        throw const FormatException(
          'Все проекты не помещаются в 160 МБ. '
          'Экспортируйте несколько проектов по отдельности.',
        );
      }
      final name = _filename(i);
      archive.add(ArchiveFile.bytes(name, data));
      manifest.add({'file': name, 'id': projects[i].id});
    }
    archive.add(ArchiveFile.string('portfolio.json', jsonEncode({
      'format': format,
      'version': version,
      'projects': manifest,
    })));
    final encoded = ZipEncoder().encodeBytes(archive);
    if (encoded.length > maxBytes) {
      throw const FormatException(
        'Архив превышает 160 МБ. Выгрузите проекты по отдельности.',
      );
    }
    return encoded;
  }

  static bool isPortfolio(List<int> bytes) {
    try {
      if (bytes.isEmpty || bytes.length > maxBytes) return false;
      final archive = ZipDecoder().decodeBytes(bytes);
      return archive.any((entry) => entry.name == 'portfolio.json');
    } catch (_) {
      return false;
    }
  }

  static PortablePortfolioBackup decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException(
        'Размер общей копии должен быть меньше 160 МБ.',
      );
    }
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      if (archive.length < 2 || archive.length > maxProjects + 1) {
        throw const FormatException('Повреждён состав архива проектов.');
      }
      final entries = <String, ArchiveFile>{};
      var total = 0;
      for (final entry in archive) {
        if (!entry.isFile || entry.isSymbolicLink ||
            (entry.name != 'portfolio.json' &&
             !RegExp(r'^projects/[0-9]{3}\.zip$').hasMatch(entry.name)) ||
            entries.containsKey(entry.name)) {
          throw const FormatException('Недопустимый файл в общей копии.');
        }
        total += entry.size;
        if (total > maxBytes ||
            entry.size > ProjectBackupService.maxPortableBytes) {
          throw const FormatException('Архив превышает безопасный размер.');
        }
        entries[entry.name] = entry;
      }
      final rawManifest = entries['portfolio.json']?.readBytes();
      if (rawManifest == null || rawManifest.length > 256 * 1024) {
        throw const FormatException('В общей копии нет списка проектов.');
      }
      final manifest = jsonDecode(
        utf8.decode(rawManifest, allowMalformed: false),
      );
      if (manifest is! Map || manifest['format'] != format ||
          manifest['version'] != version ||
          manifest['projects'] is! List) {
        throw const FormatException('Неизвестный формат общей копии.');
      }
      final list = manifest['projects'] as List;
      if (list.isEmpty || list.length > maxProjects ||
          entries.length != list.length + 1) {
        throw const FormatException('Список проектов повреждён.');
      }
      final output = <PortableProjectBackup>[];
      final ids = <String>{};
      for (var i = 0; i < list.length; i++) {
        if (list[i] is! Map) {
          throw const FormatException('Запись проекта недопустима.');
        }
        final item = list[i] as Map;
        final name = item['file'], id = item['id'];
        if (name != _filename(i) || id is! String ||
            !ids.add(id) || !entries.containsKey(name)) {
          throw const FormatException('Нарушена целостность списка проектов.');
        }
        final nested = entries[name]!.readBytes();
        if (nested == null) {
          throw const FormatException('Один из проектов не читается.');
        }
        final project = ProjectBackupService.decodePortable(nested);
        if (project.project.id != id) {
          throw const FormatException('Идентификатор проекта не совпадает.');
        }
        output.add(project);
      }
      return PortablePortfolioBackup(output);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Не удалось прочитать общую копию.');
    }
  }
}
).hasMatch(id)) {
          throw const FormatException(
            'Идентификатор импортируемого проекта некорректен.',
          );
        }
        // Track before copying so even partially restored photos get cleaned.
        output.add(await projects[i].importAsCopy(id, documents));
      }
      return output;
    } catch (_) {
      for (final id in allocated) {
        final folder = Directory('${documents.path}/zamer_photos/$id');
        if (await folder.exists()) {
          await folder.delete(recursive: true);
        }
      }
      rethrow;
    }
  }
}

class ProjectPortfolioBackupService {
  const ProjectPortfolioBackupService._();

  static const format = 'ru.zamer.portfolio';
  static const version = 1;
  static const maxProjects = 30;
  static const maxBytes = 160 * 1024 * 1024;

  static String _filename(int index) =>
      'projects/${index.toString().padLeft(3, '0')}.zip';

  static Future<Uint8List> encode(List<MeasureProject> projects) async {
    if (projects.isEmpty || projects.length > maxProjects) {
      throw const FormatException('В архиве должно быть от 1 до 30 проектов.');
    }
    final ids = projects.map((p) => p.id).toSet();
    if (ids.length != projects.length) {
      throw const FormatException(
        'Найдены повторяющиеся идентификаторы проектов.',
      );
    }
    final archive = Archive();
    final manifest = <Map<String, String>>[];
    var total = 0;
    for (var i = 0; i < projects.length; i++) {
      final data = await ProjectBackupService.encodePortable(projects[i]);
      total += data.length;
      if (total > maxBytes) {
        throw const FormatException(
          'Все проекты не помещаются в 160 МБ. '
          'Экспортируйте несколько проектов по отдельности.',
        );
      }
      final name = _filename(i);
      archive.add(ArchiveFile.bytes(name, data));
      manifest.add({'file': name, 'id': projects[i].id});
    }
    archive.add(ArchiveFile.string('portfolio.json', jsonEncode({
      'format': format,
      'version': version,
      'projects': manifest,
    })));
    final encoded = ZipEncoder().encodeBytes(archive);
    if (encoded.length > maxBytes) {
      throw const FormatException(
        'Архив превышает 160 МБ. Выгрузите проекты по отдельности.',
      );
    }
    return encoded;
  }

  static bool isPortfolio(List<int> bytes) {
    try {
      if (bytes.isEmpty || bytes.length > maxBytes) return false;
      final archive = ZipDecoder().decodeBytes(bytes);
      return archive.any((entry) => entry.name == 'portfolio.json');
    } catch (_) {
      return false;
    }
  }

  static PortablePortfolioBackup decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException(
        'Размер общей копии должен быть меньше 160 МБ.',
      );
    }
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      if (archive.length < 2 || archive.length > maxProjects + 1) {
        throw const FormatException('Повреждён состав архива проектов.');
      }
      final entries = <String, ArchiveFile>{};
      var total = 0;
      for (final entry in archive) {
        if (!entry.isFile || entry.isSymbolicLink ||
            (entry.name != 'portfolio.json' &&
             !RegExp(r'^projects/[0-9]{3}\.zip$').hasMatch(entry.name)) ||
            entries.containsKey(entry.name)) {
          throw const FormatException('Недопустимый файл в общей копии.');
        }
        total += entry.size;
        if (total > maxBytes ||
            entry.size > ProjectBackupService.maxPortableBytes) {
          throw const FormatException('Архив превышает безопасный размер.');
        }
        entries[entry.name] = entry;
      }
      final rawManifest = entries['portfolio.json']?.readBytes();
      if (rawManifest == null || rawManifest.length > 256 * 1024) {
        throw const FormatException('В общей копии нет списка проектов.');
      }
      final manifest = jsonDecode(
        utf8.decode(rawManifest, allowMalformed: false),
      );
      if (manifest is! Map || manifest['format'] != format ||
          manifest['version'] != version ||
          manifest['projects'] is! List) {
        throw const FormatException('Неизвестный формат общей копии.');
      }
      final list = manifest['projects'] as List;
      if (list.isEmpty || list.length > maxProjects ||
          entries.length != list.length + 1) {
        throw const FormatException('Список проектов повреждён.');
      }
      final output = <PortableProjectBackup>[];
      final ids = <String>{};
      for (var i = 0; i < list.length; i++) {
        if (list[i] is! Map) {
          throw const FormatException('Запись проекта недопустима.');
        }
        final item = list[i] as Map;
        final name = item['file'], id = item['id'];
        if (name != _filename(i) || id is! String ||
            !ids.add(id) || !entries.containsKey(name)) {
          throw const FormatException('Нарушена целостность списка проектов.');
        }
        final nested = entries[name]!.readBytes();
        if (nested == null) {
          throw const FormatException('Один из проектов не читается.');
        }
        final project = ProjectBackupService.decodePortable(nested);
        if (project.project.id != id) {
          throw const FormatException('Идентификатор проекта не совпадает.');
        }
        output.add(project);
      }
      return PortablePortfolioBackup(output);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Не удалось прочитать общую копию.');
    }
  }
}
