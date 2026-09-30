import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home screen keeps the approved UI-kit composition', () {
    final source = File(
      'lib/screens/home_ui_kit_screen.dart',
    ).readAsStringSync();

    for (final requiredLabel in const [
      'ЗАМЕР',
      'Поиск проектов…',
      'Новый проект',
      'Импорт плана',
      'Недавние проекты',
      'Шаблоны',
    ]) {
      expect(
        source.contains(requiredLabel),
        isTrue,
        reason: 'Missing approved Home UI-kit element: $requiredLabel',
      );
    }

    for (final forbiddenElement in const [
      'Продолжить работу',
      "_sectionTitle('Быстрые действия')",
      'ZActiveProjectCard(',
    ]) {
      expect(
        source.contains(forbiddenElement),
        isFalse,
        reason: 'Home drifted away from the approved UI-kit: $forbiddenElement',
      );
    }
  });

  test('Application starts from the UI-kit Home screen', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source.contains("import 'screens/home_ui_kit_screen.dart';"), isTrue);
    expect(source.contains('home: const HomeUiKitScreen()'), isTrue);
  });
}
