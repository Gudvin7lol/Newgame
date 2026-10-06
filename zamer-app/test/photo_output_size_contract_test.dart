import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Photo Studio exposes distinct real output sizes up to true UHD 4K', () {
    final source = File('lib/screens/photo_studio_screen.dart')
        .readAsStringSync();

    expect(source, contains("'Черновой' => (1280, 720)"));
    expect(source, contains("'Стандарт' => (1920, 1080)"));
    expect(source, contains("'Высокий' => (2560, 1440)"));
    expect(source, contains("_ => (3840, 2160)"));
    expect(
      source,
      contains("_mode == '4K' ? 'Ультра' : _quality"),
      reason: 'The dedicated 4K mode must force the true UHD output profile.',
    );

    expect(source, contains("'720p • быстро'"));
    expect(source, contains("'1080p • баланс'"));
    expect(source, contains("'1440p • финальный кадр'"));
    expect(source, contains("'4K • максимальный размер'"));
  });
}
