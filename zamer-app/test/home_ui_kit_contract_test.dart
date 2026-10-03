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

  test('UI review build starts from the supplied master screen launcher', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      source.contains("import 'screens/master_ui_preview_screen.dart';"),
      isTrue,
    );
    expect(source.contains('home: const MasterUiPreviewScreen()'), isTrue);
  });
}
