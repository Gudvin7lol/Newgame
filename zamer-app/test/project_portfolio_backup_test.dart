import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/project_portfolio_backup_service.dart';

MeasureProject fixture(String id, {String? photoPath}) {
  final floor = FloorPlan(id: 'floor-$id', name: 'Этаж');
  floor.nodes.addAll([
    PlanNode(id: 'a', xMm: 0, yMm: 0),
    PlanNode(id: 'b', xMm: 3600, yMm: 0),
  ]);
  floor.walls.add(PlanWall(
    id: 'w', startNodeId: 'a', endNodeId: 'b', thicknessMm: 120,
    openings: [WallOpening(
      id: 'door', type: OpeningType.door,
      widthMm: 900, heightMm: 2100, offsetFromStartMm: 1200,
    )],
  ));
  if (photoPath != null) {
    floor.roomMetas.add(RoomMeta(
      id: 'room', faceKey: 'f', name: 'Комната', photoPaths: [photoPath],
    ));
  }
  return MeasureProject(id: id, name: 'Объект $id', floors: [floor]);
}

void main() {
  test('one ZIP encodes two editable projects and restores without overwrite',
      () async {
    final dir = await Directory.systemTemp.createTemp('zamer-all-projects-');
    addTearDown(() async => dir.delete(recursive: true));
    final photo = File('${dir.path}/room.jpg');
    await photo.writeAsBytes([255, 216, 1, 23, 255, 217]);
    final original = [
      fixture('one', photoPath: photo.path),
      fixture('two'),
    ];
    final bytes = await ProjectPortfolioBackupService.encode(original);
    expect(ProjectPortfolioBackupService.isPortfolio(bytes), true);
    final backup = ProjectPortfolioBackupService.decode(bytes);
    expect(backup.projects, hasLength(2));
    expect(backup.projects.map((p) => p.project.id).toList(),
        ['one', 'two']);

    final restored = await backup.importAsCopies(
        dir, (i) => 'copy-${i + 1}');
    expect(restored, hasLength(2));
    expect(restored.map((e) => e.id).toList(), ['copy-1', 'copy-2']);
    expect(restored.first.floors.single.walls.single.thicknessMm, 120);
    expect(restored.first.floors.single.walls.single.openings.single.widthMm,
        900);
    final restoredPath = restored.first.floors.single.roomMetas.single
        .photoPaths.single;
    expect(restoredPath, isNot(photo.path));
    expect(await File(restoredPath).readAsBytes(), photo.readAsBytes());
    expect(original.first.floors.single.roomMetas.single.photoPaths.single,
        photo.path);
  });

  test('archive refuses duplicate project IDs, empty selection, and excess',
      () async {
    final a = fixture('a');
    await expectLater(ProjectPortfolioBackupService.encode([]),
        throwsFormatException);
    await expectLater(ProjectPortfolioBackupService.encode([a, a]),
        throwsFormatException);
    await expectLater(ProjectPortfolioBackupService.encode(
        List.generate(31, (i) => fixture('id-$i'))), throwsFormatException);
  });

  test('manifest cannot smuggle path traversal or invalid nested content',
      () async {
    final original = await ProjectPortfolioBackupService.encode(
        [fixture('a')]);
    final archive = ZipDecoder().decodeBytes(original);
    final bad = Archive();
    for (final item in archive) {
      if (item.name == 'projects/000.zip') {
        bad.add(ArchiveFile.bytes(
            '../projects/000.zip', item.readBytes()!));
      } else {
        bad.add(ArchiveFile.bytes(item.name, item.readBytes()!));
      }
    }
    expect(() => ProjectPortfolioBackupService.decode(
        ZipEncoder().encodeBytes(bad)), throwsFormatException);

    final notArchive = utf8.encode('{bad');
    expect(() => ProjectPortfolioBackupService.decode(notArchive),
        throwsFormatException);
  });

  test('restore cannot destroy pre-existing photo directory on ID collision',
      () async {
    final dir = await Directory.systemTemp.createTemp('zamer-guard-');
    addTearDown(() async => dir.delete(recursive: true));
    final original = await ProjectPortfolioBackupService.encode(
        [fixture('a')]);
    final backup = ProjectPortfolioBackupService.decode(original);
    final occupied = Directory('${dir.path}/zamer_photos/occupied');
    await occupied.create(recursive: true);
    final marker = File('${occupied.path}/do-not-remove.txt');
    await marker.writeAsString('existing project');
    await expectLater(
      backup.importAsCopies(dir, (_) => 'occupied'),
      throwsFormatException,
    );
    expect(await marker.readAsString(), 'existing project');
  });

  test('restore rejects duplicate target IDs before mutating second project',
      () async {
    final dir = await Directory.systemTemp.createTemp('zamer-duplicate-');
    addTearDown(() async => dir.delete(recursive: true));
    final original = await ProjectPortfolioBackupService.encode(
        [fixture('a'), fixture('b')]);
    final backup = ProjectPortfolioBackupService.decode(original);
    await expectLater(backup.importAsCopies(dir, (_) => 'same-id'),
        throwsFormatException);
    expect(await Directory(
        '${dir.path}/zamer_photos/same-id').exists(), false);
  });
}
