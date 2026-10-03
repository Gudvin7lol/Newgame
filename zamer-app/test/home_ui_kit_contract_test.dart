import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Concept Home keeps the approved production composition', () {
    final source = File(
      'lib/screens/home_concept_screen.dart',
    ).readAsStringSync();

    for (final requiredLabel in const [
      'ЗАМЕР',
      'ПРОФЕССИОНАЛЬНЫЙ ЗАМЕР',
      'ТЕКУЩИЙ ПРОЕКТ',
      'Новый проект',
      'Замер',
      '3D',
      'Оснащение',
      'Развёртки',
      'МОИ ПРОЕКТЫ',
      'ШАБЛОНЫ',
      'Все',
      'Главная',
      'Проекты',
      'Каталог',
      'Обучение',
      'Ещё',
    ]) {
      expect(
        source.contains(requiredLabel),
        isTrue,
        reason: 'Missing approved concept Home element: $requiredLabel',
      );
    }

    expect(source.contains('HomeConceptAssets.logo'), isTrue);
    expect(source.contains('HomeConceptAssets.currentProject'), isTrue);
    expect(source.contains('foregroundColor: ZamerColors.beige'), isTrue);
    expect(source.contains('const _homeBackground = Color(0xFF050B10)'), isTrue);
  });

  test('production build starts from the live master workspace', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      source.contains("import 'screens/master_production_home_screen.dart';"),
      isTrue,
    );
    expect(source.contains('home: const MasterProductionHomeScreen()'), isTrue);
    expect(source.contains('MasterUiPreviewScreen'), isFalse);
  });

  test('master production home exposes every live workspace page', () {
    final source = File(
      'lib/screens/master_production_home_screen.dart',
    ).readAsStringSync();
    for (final label in const [
      'Замер',
      '3D',
      'Оснащение',
      'Развёртки',
      'Фото',
      'Документы',
      'Контроль',
      'Профиль',
    ]) {
      expect(source.contains("title: '$label'"), isTrue, reason: label);
    }
    expect(source.contains('ProjectStore'), isTrue);
    expect(source.contains('MasterLivePhotoScreen'), isTrue);
    expect(source.contains('MasterLiveDocumentationScreen'), isTrue);
    expect(source.contains('MasterLiveControlScreen'), isTrue);
  });
}
