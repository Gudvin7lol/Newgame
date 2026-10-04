import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/renderer3d/scene_fingerprint.dart';

void main() {
  test('3D fingerprint changes when visible finish settings change', () {
    final floor = FloorPlan(id: 'f', name: 'F');
    final meta = RoomMeta(id: 'r', faceKey: 'room', name: 'Room');
    floor.roomMetas.add(meta);

    final initial = ZamerSceneFingerprint.of(floor);
    meta.materials.wallTile = true;
    meta.materials.wallTileFromMm = 250;
    meta.materials.wallTileToMm = 1800;
    meta.materials.wallTilePattern = 'half';
    final changed = ZamerSceneFingerprint.of(floor);

    expect(changed, isNot(initial));
  });

  test('3D fingerprint changes when floor finish mode changes', () {
    final floor = FloorPlan(id: 'f', name: 'F');
    final meta = RoomMeta(id: 'r', faceKey: 'room', name: 'Room');
    floor.roomMetas.add(meta);

    final initial = ZamerSceneFingerprint.of(floor);
    meta.materials.floorTile = true;
    meta.materials.floorMode = 'tile';
    final changed = ZamerSceneFingerprint.of(floor);

    expect(changed, isNot(initial));
  });
}
