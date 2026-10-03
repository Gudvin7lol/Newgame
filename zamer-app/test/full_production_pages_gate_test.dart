import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('production app starts from the real Home page', () {
    final main = source('lib/main.dart');
    expect(main.contains("import 'screens/ready_home_screen.dart';"), isTrue);
    expect(main.contains('home: const ReadyHomeScreen()'), isTrue);
  });

  test('Home opens every production workspace mode', () {
    final home = source('lib/screens/ready_home_screen.dart');
    for (final route in const [
      '_openWorkspace(0)',
      '_openWorkspace(1)',
      '_openWorkspace(2)',
      '_openWorkspace(3)',
    ]) {
      expect(home.contains(route), isTrue, reason: 'Missing Home route: $route');
    }
    for (final operation in const [
      '_createProject',
      '_renameProject',
      '_duplicateProject',
      '_deleteProject',
      '_importPlan',
      '_importBackup',
      '_shareCurrentPdf',
    ]) {
      expect(home.contains(operation), isTrue, reason: 'Missing Home operation: $operation');
    }
  });

  test('workspace binds all five master pages to production screens', () {
    final workspace = source('lib/screens/floor_workspace_screen.dart');
    final navigation = source('lib/widgets/workspace_navigation.dart');

    for (final label in const [
      'Главная',
      'Замер',
      '3D',
      'Оснащение',
      'Развёртки',
    ]) {
      expect(
        navigation.contains("'$label'"),
        isTrue,
        reason: 'Missing master navigation page: $label',
      );
    }

    for (final screen in const [
      'MeasureConceptWorkspaceScreen(',
      'Floor3DScreen(',
      'MasterEquipmentScreen(',
      'ElevationsScreen(',
      'LayoutsScreen(',
      'MaterialsScreen(',
      'PlanningObjectsScreen(',
      'ElectricalScreen(',
      'EngineeringScreen(',
      'RoomsScreen(',
    ]) {
      expect(
        workspace.contains(screen),
        isTrue,
        reason: 'Production workspace is not wired to $screen',
      );
    }
  });

  test('Measure exposes only working view modes and real project actions', () {
    final measure = source('lib/screens/measure_concept_workspace_screen.dart');
    expect(measure.contains('ZMeasureViewMode.twoD'), isTrue);
    expect(measure.contains('ZMeasureViewMode.threeD'), isTrue);
    expect(measure.contains('ZMeasureViewMode.photo'), isTrue);
    expect(
      measure.contains('enabledModes: const [\n                  ZMeasureViewMode.twoD,\n                  ZMeasureViewMode.threeD,\n                  ZMeasureViewMode.photo,'),
      isTrue,
      reason: 'A non-working Measure view must not be enabled in release',
    );
    for (final action in const [
      '_saveNow',
      '_renameProject',
      '_showMeasureSettings',
      '_openMaterials',
      'widget.onOpenObjects',
      'widget.onOpenReview',
      'widget.onOpenGeometry',
      'widget.onOpenFloors',
    ]) {
      expect(measure.contains(action), isTrue, reason: 'Missing Measure action: $action');
    }
  });

  test('3D page keeps real navigation, cutaway, walk and render controls', () {
    final threeD = source('lib/screens/floor_3d_screen.dart');
    for (final action in const [
      '_toggleWalk',
      '_topView',
      '_showRenderSheet',
      '_showWalkSettingsSheet',
      '_noclip = !_noclip',
      '_cutaway = !_cutaway',
      'ZamerGpuViewport(',
    ]) {
      expect(threeD.contains(action), isTrue, reason: 'Missing 3D action: $action');
    }
  });

  test('Equipment page searches, filters and adds real catalog objects', () {
    final equipment = source('lib/screens/master_equipment_screen.dart');
    for (final action in const [
      'ObjectCatalog.items',
      '_search',
      '_showFilters',
      '_favorites',
      'onAdd',
      '_add(',
    ]) {
      expect(equipment.contains(action), isTrue, reason: 'Missing Equipment action: $action');
    }
  });

  test('Elevations page edits real wall layouts and persists changes', () {
    final elevations = source('lib/screens/elevations_screen.dart');
    for (final action in const [
      'GeometryService.elevationRuns',
      '_openLargeElevation',
      '_tileOptions',
      'wallTileRunEnabled',
      'wallTileRunRotated',
      'wallTileRunMirrored',
      'LayoutService.balanceWallTiles',
      'widget.onChanged()',
    ]) {
      expect(elevations.contains(action), isTrue, reason: 'Missing Elevations action: $action');
    }
  });
}
