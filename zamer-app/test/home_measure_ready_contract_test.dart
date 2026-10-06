import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production app starts from functional field-first Home', () {
    final main = File('lib/main.dart').readAsStringSync();
    final home =
        File('lib/screens/production_home_screen.dart').readAsStringSync();

    expect(main.contains('home: const ProductionHomeScreen()'), isTrue);
    expect(main.contains('MasterUiPreviewScreen'), isFalse);

    for (final required in const [
      '_createProject(',
      '_rename(',
      '_duplicate(',
      '_delete(',
      '_importPlan(',
      '_importBackup(',
      '_sharePdf(',
      '_settings(',
      '_openProfile(',
      '_openWorkspace(0)',
      '_openWorkspace(1)',
      '_openWorkspace(2)',
    ]) {
      expect(home.contains(required), isTrue, reason: 'Missing Home action: $required');
    }

    expect(home.contains('FloorWorkspaceScreen('), isTrue);
    expect(home.contains('FloorsScreen('), isFalse);
  });

  test('Measure exposes working production views and functional layers', () {
    final measure = File('lib/screens/measure_unified_workspace_screen.dart')
        .readAsStringSync();
    final chrome =
        File('lib/design_system/zamer_measure_chrome.dart').readAsStringSync();

    for (final required in const [
      'PlanEditorProductionScreen(',
      'MeasureFloorPlanLayerScreen(',
      'PlanningObjectsScreen(',
      'ElectricalScreen(',
      'EngineeringScreen(',
      'MaterialsMasterScreen(',
      'ZMeasureViewTabs(',
      'ZWorkspacePrimaryNav(',
      'ZWorkspaceSubnav(',
    ]) {
      expect(
        measure.contains(required),
        isTrue,
        reason: 'Missing Measure action/layer: $required',
      );
    }

    expect(measure.contains('ZMeasureViewMode.twoD'), isTrue);
    expect(measure.contains('ZMeasureViewMode.threeD'), isTrue);
    expect(measure.contains('ZMeasureViewMode.photo'), isTrue);
    expect(measure.contains('ZMeasureViewMode.ar'), isFalse);
    expect(chrome.contains('enabledModes.contains(mode)'), isTrue);
    expect(chrome.contains('onTap: enabled ? () => onChanged(mode) : null'), isTrue);
  });

  test('candidate APK build number is 111 or newer', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'version:\s+1\.5\.[67]\+(\d+)').firstMatch(pubspec);
    expect(match, isNotNull);
    expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(111));
  });
}
