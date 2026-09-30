import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home remembers the last opened project', () {
    final source = File('lib/screens/home_concept_screen.dart').readAsStringSync();

    expect(source.contains("zamer.last_opened_project_id"), isTrue);
    expect(source.contains('SharedPreferences.getInstance()'), isTrue);
    expect(source.contains('await _rememberOpened(project)'), isTrue);
    expect(source.contains('_lastOpenedProjectId'), isTrue);
  });

  test('Home sheets force readable dark contrast', () {
    final source = File('lib/screens/home_concept_screen.dart').readAsStringSync();

    expect(source.contains('backgroundColor: _homeSurface'), isTrue);
    expect(source.contains('color: ZamerColors.white'), isTrue);
    expect(source.contains('barrierColor: Colors.black'), isTrue);
  });

  test('Measure page uses the production 2D 3D Photo selector', () {
    final source = File('lib/screens/floor_workspace_screen.dart').readAsStringSync();

    expect(source.contains('_MeasureProductionStrip'), isTrue);
    expect(source.contains('ZMeasureViewTabs('), isTrue);
    expect(source.contains('ZMeasureViewMode.twoD'), isTrue);
    expect(source.contains('_selectMeasureView'), isTrue);
  });
}
