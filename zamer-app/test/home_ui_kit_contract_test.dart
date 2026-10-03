import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production Home keeps the approved dark field composition', () {
    final source =
        File('lib/screens/production_home_screen.dart').readAsStringSync();

    for (final requiredLabel in const [
      'ЗАМЕР',
      'Обмер • проект • рабочая документация',
      'Продолжить работу',
      'АКТИВНЫЙ ПРОЕКТ',
      'Новый проект',
      'Сканировать',
      'Импорт плана',
      'Восстановить',
      'Недавние проекты',
      'Главная',
      'Замер',
      '3D',
      'Развёртки',
      'Профиль',
    ]) {
      expect(
        source.contains(requiredLabel),
        isTrue,
        reason: 'Missing approved production Home element: $requiredLabel',
      );
    }

    expect(source.contains('HomeConceptAssets.logo'), isTrue);
    expect(source.contains('HomeConceptAssets.currentProject'), isTrue);
    expect(source.contains('const _bg = Color(0xFF050B10)'), isTrue);
    expect(source.contains('FloorsScreen('), isFalse);
    expect(source.contains("'Оснащение'"), isFalse);
  });

  test('production build starts from the field-first Home screen', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      source.contains("import 'screens/production_home_screen.dart';"),
      isTrue,
    );
    expect(source.contains('home: const ProductionHomeScreen()'), isTrue);
    expect(source.contains('MasterUiPreviewScreen'), isFalse);
  });
}
