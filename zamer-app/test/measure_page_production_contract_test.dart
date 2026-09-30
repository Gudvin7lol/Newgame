import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure page keeps the master-concept production shell', () {
    final workspace = File(
      'lib/screens/floor_workspace_screen.dart',
    ).readAsStringSync();
    final concept = File(
      'lib/screens/measure_concept_workspace_screen.dart',
    ).readAsStringSync();

    expect(workspace.contains('MeasureConceptWorkspaceScreen('), isTrue);
    expect(workspace.contains('onOpen3D: () => _selectMeasureView'), isTrue);
    expect(workspace.contains('onOpenPhoto: () => _selectMeasureView'), isTrue);
    expect(workspace.contains('_showFloorPicker'), isTrue);
    expect(workspace.contains('_switchFloor'), isTrue);
    expect(workspace.contains('Добавить этаж'), isTrue);
    expect(workspace.contains('Navigator.pushReplacement'), isTrue);

    expect(concept.contains("'ЗАМЕР'"), isTrue);
    expect(concept.contains("'Сохранить'"), isTrue);
    expect(concept.contains("(_MeasureConceptView.twoD, '2D')"), isTrue);
    expect(concept.contains("(_MeasureConceptView.threeD, '3D')"), isTrue);
    expect(concept.contains("(_MeasureConceptView.ar, 'AR')"), isTrue);
    expect(concept.contains("(_MeasureConceptView.photo, 'Фото')"), isTrue);
    expect(concept.contains('PlanEditorConceptScreen('), isTrue);
    expect(concept.contains('_ConceptBottomNav('), isTrue);
    expect(concept.contains("label: 'Главная'"), isTrue);
    expect(concept.contains("label: 'Проекты'"), isTrue);
    expect(concept.contains("label: 'Каталог'"), isTrue);
    expect(concept.contains("label: 'Обучение'"), isTrue);
    expect(concept.contains("label: 'Ещё'"), isTrue);
    expect(concept.contains('ZPressEffect('), isTrue);
  });
}
