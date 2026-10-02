import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Photo Render gallery persists captures per floor and exposes real actions', () {
    final source = File('lib/screens/photo_studio_screen.dart')
        .readAsStringSync();

    expect(source.contains('getApplicationDocumentsDirectory()'), isTrue);
    expect(source.contains("photo_renders/\$_safeFloorId"), isTrue);
    expect(source.contains("_showRenderGallery"), isTrue);
    expect(source.contains('GridView.builder'), isTrue);
    expect(source.contains('InteractiveViewer'), isTrue);
    expect(source.contains('Share.shareXFiles'), isTrue);
    expect(source.contains('await file.delete()'), isTrue);
    expect(
      source.contains("_renderCount == 0 ? 'Пусто' : '\$_renderCount'"),
      isTrue,
    );
    expect(
      source.contains(
        "zamer-photo-\$timestamp-\${size.\$1}-\${size.\$2}-\${_time.name}.png",
      ),
      isTrue,
    );
    expect(source.contains("return '\${parts[3]}×\${parts[4]}'"), isTrue);
    expect(
      source.contains('Галерея проекта будет подключена отдельным проходом'),
      isFalse,
    );
  });
}
