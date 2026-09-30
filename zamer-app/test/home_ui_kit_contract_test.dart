import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Production Home keeps the approved UI KIT 01 composition', () {
    final source = File(
      'lib/screens/home_production_screen.dart',
    ).readAsStringSync();

    for (final requiredLabel in const [
      'ЗАМЕР',
      'Поиск проектов',
      'Новый проект',
      'Импорт плана',
      'Недавние проекты',
      'Шаблоны',
      'Главная',
      'Проекты',
      'Каталог',
      'Обучение',
      'Ещё',
    ]) {
      expect(
        source.contains(requiredLabel),
        isTrue,
        reason: 'Missing approved production Home element: $requiredLabel',
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
        reason: 'Production Home drifted away from UI KIT 01: $forbiddenElement',
      );
    }
  });

  test('Application starts from the production Home screen', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      source.contains("import 'screens/home_production_screen.dart';"),
      isTrue,
    );
    expect(source.contains('home: const HomeProductionScreen()'), isTrue);
  });
}
