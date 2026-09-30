import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/render_quality.dart';

void main() {
  test('Photo quality remains true UHD 4K', () {
    expect(ZamerRenderQuality.ultra4k.width, 3840);
    expect(ZamerRenderQuality.ultra4k.height, 2160);
    expect(ZamerRenderQuality.ultra4k.label, 'Photo');
    expect(ZamerRenderQuality.ultra4k.isPhoto, isTrue);
    expect(ZamerRenderQuality.ultra4k.description, contains('3840×2160'));
  });

  test('realtime modes stay separate from Photo', () {
    expect(ZamerRenderQuality.interactive.isPhoto, isFalse);
    expect(ZamerRenderQuality.high.isPhoto, isFalse);
    expect(ZamerRenderQuality.interactive.label, 'Performance');
    expect(ZamerRenderQuality.high.label, 'Quality');
  });
}
