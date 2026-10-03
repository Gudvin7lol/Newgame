import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Production Home keeps the approved master composition', () {
    final source = File(
      'lib/screens/home_production_screen.dart',
    ).readAsStringSync();

    for (final requiredLabel in const [
      'ЗАМЕР',
      'Поиск проектов…',
      'Новый проект',
      'Импорт плана',
      'Недавние проекты',
      'Шаблоны',
      'Квартира',
      'Дом',
      'Коммерция',
      'Главная',
      'Проекты',
      'Каталог',
      'Обучение',
      'Ещё',
    ]) {
      expect(
        source.contains(requiredLabel),
        isTrue,
        reason: 'Missing approved master Home element: $requiredLabel',
      );
    }

    expect(source.contains('ZProjectThumbnail'), isTrue);
    expect(source.contains('ZamerSize.bottomNavigation'), isTrue);
    expect(source.contains('ZamerColors.beige'), isTrue);
    expect(source.contains('ZamerColors.graphite'), isTrue);
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
