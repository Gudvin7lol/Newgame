import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production app starts from functional Home', () {
    final main = File('lib/main.dart').readAsStringSync();
    final home = File('lib/screens/ready_home_screen.dart').readAsStringSync();

    expect(main.contains("home: const ReadyHomeScreen()"), isTrue);
    expect(main.contains('MasterUiPreviewScreen'), isFalse);

    for (final required in const [
      '_createProject(',
      '_renameProject(',
      '_duplicateProject(',
      '_deleteProject(',
      '_importPlan(',
      '_importBackup(',
      '_shareCurrentPdf(',
      '_showSettings(',
      '_showLearning(',
      '_openProjects(',
      '_openWorkspace(0)',
    ]) {
      expect(home.contains(required), isTrue, reason: 'Missing Home action: $required');
    }

    expect(home.contains("label: 'Настройки'"), isTrue);
    expect(home.contains("label: 'PDF текущего проекта'"), isTrue);
    expect(home.contains("label: 'Первый замер'"), isTrue);
  });

  test('Measure page exposes only working production view modes', () {
    final measure = File('lib/screens/measure_concept_workspace_screen.dart')
        .readAsStringSync();
    final chrome =
        File('lib/design_system/zamer_measure_chrome.dart').readAsStringSync();

    for (final required in const [
      '_saveNow()',
      '_renameProject()',
      '_showMeasureSettings()',
      'PlanEditorProductionScreen(',
      'ZMeasureViewTabs(',
      'onOpenSettings: _showMeasureSettings',
      "'Сохранить'",
      "'Главная'",
      "'Проекты'",
      "'Каталог'",
      "'Обучение'",
      "'Ещё'",
    ]) {
      expect(
        measure.contains(required),
        isTrue,
        reason: 'Missing Measure action: $required',
      );
    }

    expect(
      measure.contains(
        'ZMeasureViewMode.twoD,\n                  ZMeasureViewMode.threeD,\n                  ZMeasureViewMode.photo',
      ),
      isTrue,
    );
    expect(chrome.contains('enabledModes.contains(mode)'), isTrue);
    expect(chrome.contains('onTap: enabled ? () => onChanged(mode) : null'), isTrue);
  });

  test('ready APK build number is 109 or newer', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'version:\s+1\.5\.6\+(\d+)').firstMatch(pubspec);
    expect(match, isNotNull);
    expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(109));
  });
}
