import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/device_diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'device diagnostics exercise a free partition and layout dimensions',
    () async {
      final geometry = await DeviceDiagnostics.geometry();
      final layout = await DeviceDiagnostics.layout();
      expect(geometry.ok, isTrue, reason: geometry.detail);
      expect(layout.ok, isTrue, reason: layout.detail);
    },
  );

  test('device diagnostics rasterize finishes and a cutaway scene', () async {
    final floor = await DeviceDiagnostics.floorRender();
    final scene = await DeviceDiagnostics.sceneRender();
    expect(floor.ok, isTrue, reason: floor.detail);
    expect(scene.ok, isTrue, reason: scene.detail);
  });

  test('device diagnostics round-trip pipes, backup and PDF', () async {
    final result = await DeviceDiagnostics.projectRoundTrip();
    expect(result.ok, isTrue, reason: result.detail);
  });
}
