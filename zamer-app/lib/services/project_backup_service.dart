import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/models.dart';

class PortableProjectBackup {
  const PortableProjectBackup(this.project, this.photos);
  final MeasureProject project;
  final Map<String, Uint8List> photos;

  Future<MeasureProject> importAsCopy(String newId, Directory documents) async {
    final copy = ProjectBackupService.importAsCopy(project, newId);
    final directory = Directory('${documents.path}/zamer_photos/$newId');
    await directory.create(recursive: true);
    var serial = 0;
    for (final floor in copy.floors) {
      for (final room in floor.roomMetas) {
        for (var i = 0; i < room.photoPaths.length; i++) {
          final name = room.photoPaths[i];
          final data = photos[name];
          if (data == null)
            throw const FormatException('Фото отсутствует в копии');
          final ext = name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
          final file = File('${directory.path}/photo-${serial++}.$ext');
          await file.writeAsBytes(data, flush: true);
          room.photoPaths[i] = file.path;
        }
      }
    }
    return copy;
  }
}

/// Portable, versioned project backup. PDF exports are presentation only;
/// this format retains editable geometry, materials, electrical work and notes.
class ProjectBackupService {
  static const format = 'ru.zamer.project';
  static const version = 1;
  static const maxBytes = 20 * 1024 * 1024;
  static const portableVersion = 2;
  static const maxPortableBytes = 100 * 1024 * 1024;

  static String encode(MeasureProject project) =>
      const JsonEncoder.withIndent('  ').convert({
        'format': format,
        'version': version,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'project': project.toJson(),
      });

  static MeasureProject decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException(
        'Размер файла вне допустимого диапазона (до 20 МБ)',
      );
    }
    try {
      final root = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (root is! Map ||
          root['format'] != format ||
          root['version'] != version) {
        throw const FormatException(
          'Это не поддерживаемая копия проекта «Замер»',
        );
      }
      final data = Map<String, dynamic>.from(root['project'] as Map);
      final project = MeasureProject.fromJson(data);
      if (project.id.isEmpty ||
          project.name.trim().isEmpty ||
          project.floors.isEmpty) {
        throw const FormatException('В копии отсутствует объект или этаж');
      }
      for (final floor in project.floors) {
        final nodeIds = floor.nodes.map((node) => node.id).toSet();
        if (floor.id.isEmpty ||
            floor.walls.any(
              (wall) =>
                  !nodeIds.contains(wall.startNodeId) ||
                  !nodeIds.contains(wall.endNodeId),
            )) {
          throw const FormatException('В копии повреждены связи стен и точек');
        }
      }
      return project;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Не удалось прочитать копию проекта');
    }
  }

  /// ZIP v2 stores photos by room, so imported paths do not refer to the old
  /// phone. Missing pictures stop export instead of producing a false backup.
  static Future<Uint8List> encodePortable(MeasureProject project) async {
    final data = project.toJson();
    final floors = data['floors'] as List;
    final archive = Archive();
    var total = 0;
    var count = 0;
    for (var f = 0; f < project.floors.length; f++) {
      final rooms = (floors[f] as Map)['roomMetas'] as List;
      for (var r = 0; r < project.floors[f].roomMetas.length; r++) {
        final paths = project.floors[f].roomMetas[r].photoPaths;
        final savedPaths = (rooms[r] as Map)['photoPaths'] as List;
        for (var i = 0; i < paths.length; i++) {
          final file = File(paths[i]);
          if (!await file.exists()) {
            throw FormatException('Не найдено фото помещения: ${paths[i]}');
          }
          final size = await file.length();
          total += size;
          if (size > 16 * 1024 * 1024 ||
              total > 75 * 1024 * 1024 ||
              ++count > 300) {
            throw const FormatException('Для копии слишком много фотографий');
          }
          final ext = paths[i].toLowerCase().endsWith('.png') ? 'png' : 'jpg';
          final name = 'photos/$f-$r-$i.$ext';
          archive.add(ArchiveFile.bytes(name, await file.readAsBytes()));
          savedPaths[i] = name;
        }
      }
    }
    archive.add(
      ArchiveFile.string(
        'project.json',
        jsonEncode({
          'format': format,
          'version': portableVersion,
          'exportedAt': DateTime.now().toUtc().toIso8601String(),
          'project': data,
        }),
      ),
    );
    final bytes = ZipEncoder().encodeBytes(archive);
    if (bytes.length > maxPortableBytes) {
      throw const FormatException('Размер копии превышает 100 МБ');
    }
    return bytes;
  }

  static PortableProjectBackup decodePortable(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxPortableBytes) {
      throw const FormatException('Размер копии вне диапазона (до 100 МБ)');
    }
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      if (archive.length > 301) {
        throw const FormatException('Слишком много файлов в копии');
      }
      final entries = <String, ArchiveFile>{};
      var total = 0;
      for (final file in archive) {
        if (!file.isFile ||
            file.isSymbolicLink ||
            (file.name != 'project.json' &&
                !RegExp(
                  r'^photos/[0-9]+-[0-9]+-[0-9]+\.(jpg|png)$',
                ).hasMatch(file.name))) {
          throw const FormatException('Недопустимый файл в копии');
        }
        total += file.size;
        if (file.size > 20 * 1024 * 1024 ||
            total > maxPortableBytes ||
            entries.containsKey(file.name)) {
          throw const FormatException('Повреждена структура копии');
        }
        entries[file.name] = file;
      }
      final manifest = entries['project.json']?.readBytes();
      if (manifest == null) throw const FormatException('Нет проекта в копии');
      final root = jsonDecode(utf8.decode(manifest, allowMalformed: false));
      if (root is! Map ||
          root['format'] != format ||
          root['version'] != portableVersion) {
        throw const FormatException('Неизвестная версия копии');
      }
      final project = MeasureProject.fromJson(
        Map<String, dynamic>.from(root['project'] as Map),
      );
      final photos = <String, Uint8List>{};
      final expected = <String>{};
      for (final floor in project.floors) {
        final ids = floor.nodes.map((e) => e.id).toSet();
        if (floor.walls.any(
          (w) => !ids.contains(w.startNodeId) || !ids.contains(w.endNodeId),
        )) {
          throw const FormatException('В копии повреждены связи стен');
        }
        for (final room in floor.roomMetas) {
          for (final name in room.photoPaths) {
            if (!name.startsWith('photos/') ||
                !expected.add(name) ||
                !entries.containsKey(name)) {
              throw const FormatException('Нарушены привязки фотографий');
            }
            photos[name] = entries[name]!.readBytes()!;
          }
        }
      }
      if (project.id.isEmpty ||
          project.floors.isEmpty ||
          entries.length != expected.length + 1) {
        throw const FormatException('В копии отсутствуют данные проекта');
      }
      return PortableProjectBackup(project, photos);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Не удалось прочитать архив проекта');
    }
  }

  static MeasureProject importAsCopy(MeasureProject project, String newId) {
    final data = project.toJson();
    data['id'] = newId;
    data['name'] = '${project.name} (копия)';
    return MeasureProject.fromJson(data);
  }
}
