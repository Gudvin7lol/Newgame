import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/project_backup_service.dart';
import 'package:zamer_app/services/project_store.dart';

void main() {
  MeasureProject sample() {
    final floor = FloorPlan(id: 'floor', name: 'Этаж 1');
    floor.nodes.addAll([
      PlanNode(id: 'a', xMm: 0, yMm: 0),
      PlanNode(id: 'b', xMm: 4100, yMm: 0),
    ]);
    floor.walls.add(
      PlanWall(
        id: 'w',
        startNodeId: 'a',
        endNodeId: 'b',
        projectLayer: ProjectLayer.demolition,
        openings: [
          WallOpening(
            id: 'door',
            type: OpeningType.door,
            widthMm: 800,
            heightMm: 2100,
            offsetFromStartMm: 700,
          ),
        ],
      ),
    );
    return MeasureProject(id: 'original', name: 'Квартира', floors: [floor]);
  }

  test('portable backup retains editable geometry and imports as a copy', () {
    final original = sample();
    final restored = ProjectBackupService.decode(
      utf8.encode(ProjectBackupService.encode(original)),
    );
    final copy = ProjectBackupService.importAsCopy(restored, 'new-id');
    expect(copy.id, 'new-id');
    expect(copy.name, 'Квартира (копия)');
    expect(
      copy.floors.single.walls.single.projectLayer,
      ProjectLayer.demolition,
    );
    expect(copy.floors.single.walls.single.openings.single.widthMm, 800);
    expect(copy.floors.single.nodes.last.xMm, 4100);
    expect(original.id, 'original');
  });

  test('ZIP backup restores photo in a new device directory', () async {
    final source = await Directory.systemTemp.createTemp('zamer-source-');
    final target = await Directory.systemTemp.createTemp('zamer-target-');
    addTearDown(() async {
      await source.delete(recursive: true);
      await target.delete(recursive: true);
    });
    final photo = File('${source.path}/room.jpg');
    await photo.writeAsBytes([0xff, 0xd8, 1, 2, 0xff, 0xd9]);
    final original = sample();
    original.floors.single.roomMetas.add(
      RoomMeta(
        id: 'r',
        faceKey: 'room',
        name: 'Комната',
        photoPaths: [photo.path],
      ),
    );
    final bytes = await ProjectBackupService.encodePortable(original);
    final backup = ProjectBackupService.decodePortable(bytes);
    final imported = await backup.importAsCopy('new-id', target);
    expect(
      original.floors.single.roomMetas.single.photoPaths.single,
      photo.path,
    );
    final importedPath =
        imported.floors.single.roomMetas.single.photoPaths.single;
    expect(importedPath, isNot(photo.path));
    expect(importedPath, contains(target.path));
    expect(await File(importedPath).readAsBytes(), await photo.readAsBytes());
  });

  test('portable ZIP retains photos in saved project revisions', () async {
    final origin = await Directory.systemTemp.createTemp('zamer-rev-source-');
    final target = await Directory.systemTemp.createTemp('zamer-rev-target-');
    addTearDown(() async {
      await origin.delete(recursive: true);
      await target.delete(recursive: true);
    });
    final livePhoto = File('${origin.path}/live.jpg');
    final olderPhoto = File('${origin.path}/older.png');
    await livePhoto.writeAsBytes([255, 216, 1, 2, 255, 217]);
    await olderPhoto.writeAsBytes([137, 80, 78, 71, 11, 22, 33]);
    final project = sample();
    project.floors.single.roomMetas.add(RoomMeta(
      id: 'room', faceKey: 'room', name: 'Кухня',
      photoPaths: [livePhoto.path],
    ));
    final oldFloor = FloorPlan.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(project.floors.single.toJson())) as Map));
    oldFloor.roomMetas.single.photoPaths[0] = olderPhoto.path;
    project.revisions.add(ProjectRevision(
      label: 'До ремонта',
      createdAt: DateTime.utc(2026, 10, 1),
      floors: [oldFloor],
    ));

    final backup = ProjectBackupService.decodePortable(
        await ProjectBackupService.encodePortable(project));
    final restored = await backup.importAsCopy('recovered', target);
    final livePath =
        restored.floors.single.roomMetas.single.photoPaths.single;
    final oldPath = restored.revisions.single.floors.single
        .roomMetas.single.photoPaths.single;
    expect(livePath, isNot(livePhoto.path));
    expect(oldPath, isNot(olderPhoto.path));
    expect(oldPath, isNot(livePath));
    expect(await File(livePath).readAsBytes(),
        await livePhoto.readAsBytes());
    expect(await File(oldPath).readAsBytes(),
        await olderPhoto.readAsBytes());
  });

  test('ZIP backup rejects archive entries outside its photo manifest', () {
    final archive = Archive()
      ..add(ArchiveFile.string('project.json', '{}'))
      ..add(ArchiveFile.string('../other.txt', 'unsafe'));
    final bytes = ZipEncoder().encodeBytes(archive);
    expect(
      () => ProjectBackupService.decodePortable(bytes),
      throwsFormatException,
    );
  });

  test('damaged wall references cannot be imported', () {
    final root =
        jsonDecode(ProjectBackupService.encode(sample()))
            as Map<String, dynamic>;
    final floor = (root['project'] as Map)['floors'][0] as Map;
    floor['nodes'] = [];
    expect(
      () => ProjectBackupService.decode(utf8.encode(jsonEncode(root))),
      throwsFormatException,
    );
  });

  test('recovers local projects when primary record is damaged', () async {
    SharedPreferences.setMockInitialValues({
      'zamer_projects_v3': '{broken',
      'zamer_projects_v3_backup': jsonEncode([sample().toJson()]),
    });
    final result = await ProjectStore().loadWithStatus();
    expect(result.recovered, isTrue);
    expect(result.projects.single.name, 'Квартира');
  });

  test(
    'does not report an unreadable record as a new empty project list',
    () async {
      SharedPreferences.setMockInitialValues({'zamer_projects_v3': '{broken'});
      final result = await ProjectStore().loadWithStatus();
      expect(result.unreadable, isTrue);
      expect(result.projects, isEmpty);
    },
  );
}
