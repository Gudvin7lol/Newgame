import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measure page keeps the compact production shell', () {
    final workspace = File(
      'lib/screens/floor_workspace_screen.dart',
    ).readAsStringSync();
    final chrome = File(
      'lib/design_system/zamer_measure_chrome.dart',
    ).readAsStringSync();
    final header = File(
      'lib/widgets/workspace_master_header.dart',
    ).readAsStringSync();

    expect(workspace.contains('_MeasureProductionStrip'), isTrue);
    expect(workspace.contains('height: 54'), isTrue);
    expect(workspace.contains('PhotoStudioScreen('), isTrue);
    expect(workspace.contains('Floor3DScreen(floor: widget.floor)'), isTrue);
    expect(workspace.contains('_showFloorPicker'), isTrue);
    expect(workspace.contains('_switchFloor'), isTrue);
    expect(workspace.contains('Добавить этаж'), isTrue);
    expect(workspace.contains('Navigator.pushReplacement'), isTrue);

    expect(chrome.contains("_tab('2D'"), isTrue);
    expect(chrome.contains("_tab('3D'"), isTrue);
    expect(chrome.contains("_tab('Фото'"), isTrue);
    expect(chrome.contains('height: 40'), isTrue);
    expect(chrome.contains('ZPressEffect('), isTrue);

    expect(header.contains('projectName,'), isTrue);
    expect(header.contains("tooltip: 'Назад'"), isTrue);
    expect(header.contains('Navigator.maybePop(context)'), isTrue);
    expect(header.contains('Size.fromHeight(56)'), isTrue);
  });
}
