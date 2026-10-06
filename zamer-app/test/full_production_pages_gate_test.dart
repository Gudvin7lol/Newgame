import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('production app starts from the field-first Home page', () {
    final main = source('lib/main.dart');
    expect(main.contains("import 'screens/production_home_screen.dart';"), isTrue);
    expect(main.contains('home: const ProductionHomeScreen()'), isTrue);
  });

  test('Home opens Measure 3D Elevations and Profile without Floors screen', () {
    final home = source('lib/screens/production_home_screen.dart');
    for (final route in const [
      '_openWorkspace(0)',
      '_openWorkspace(1)',
      '_openWorkspace(2)',
      '_openProfile()',
    ]) {
      expect(home.contains(route), isTrue, reason: 'Missing Home route: $route');
    }
    expect(home.contains('FloorsScreen('), isFalse);
    expect(home.contains("import 'floors_screen.dart';"), isFalse);
    expect(home.contains('FloorWorkspaceScreen('), isTrue);
    for (final operation in const [
      '_createProject',
      '_rename(',
      '_duplicate(',
      '_delete(',
      '_importPlan',
      '_importBackup',
      '_sharePdf',
    ]) {
      expect(home.contains(operation), isTrue, reason: 'Missing Home operation: $operation');
    }
  });

  test('primary navigation is Home Measure 3D Elevations Profile', () {
    final navigation = source('lib/widgets/workspace_navigation.dart');
    for (final label in const [
      'Главная',
      'Замер',
      '3D',
      'Развёртки',
      'Профиль',
    ]) {
      expect(
        navigation.contains("'$label'"),
        isTrue,
        reason: 'Missing primary navigation page: $label',
      );
    }
    expect(
      navigation.contains("(Icons.chair_alt_outlined, 'Оснащение')"),
      isFalse,
      reason: 'Equipment must be a Measure layer, not a primary page',
    );
  });

  test('Measure owns floor objects electrical engineering and materials layers', () {
    final workspace = source('lib/screens/floor_workspace_screen.dart');
    final measure = source('lib/screens/measure_unified_workspace_screen.dart');

    expect(workspace.contains('MeasureUnifiedWorkspaceScreen('), isTrue);
    expect(workspace.contains('MasterEquipmentScreen('), isTrue);
    expect(workspace.contains('RoomsScreen('), isTrue);
    expect(workspace.contains('LayeredElevationsScreen('), isTrue);

    for (final label in const [
      "('План'",
      "('Пол'",
      "('Объекты'",
      "('Электрика'",
      "('Инженерия'",
      "('Материалы'",
    ]) {
      expect(measure.contains(label), isTrue, reason: 'Missing Measure layer: $label');
    }
    for (final screen in const [
      'PlanEditorProductionScreen(',
      'MeasureFloorPlanLayerScreen(',
      'PlanningObjectsScreen(',
      'ElectricalScreen(',
      'EngineeringScreen(',
      'MaterialsMasterScreen(',
    ]) {
      expect(measure.contains(screen), isTrue, reason: 'Measure is not wired to $screen');
    }

    // +116 keeps the catalogue inside Measure as a working bottom sheet.
    // Adding an item persists a real PlanObject and returns straight to the
    // Objects layer so placement continues on the measured plan.
    expect(measure.contains('Future<void> _openCatalogSheet()'), isTrue);
    expect(measure.contains('MasterEquipmentScreen('), isTrue);
    expect(measure.contains('EquipmentPlacementService.addCatalogItem('), isTrue);
    expect(measure.contains('_layer = 2;'), isTrue);
  });

  test('Measure exposes only real view modes and project actions', () {
    final measure = source('lib/screens/measure_unified_workspace_screen.dart');
    expect(measure.contains('ZMeasureViewMode.twoD'), isTrue);
    expect(measure.contains('ZMeasureViewMode.threeD'), isTrue);
    expect(measure.contains('ZMeasureViewMode.photo'), isTrue);
    expect(measure.contains('ZMeasureViewMode.ar'), isFalse);
    expect(measure.contains('enabledModes: const ['), isTrue);
    expect(measure.contains('widget.onOpenReview'), isTrue);
    expect(measure.contains('widget.onOpenGeometry'), isTrue);
    expect(measure.contains('widget.onOpenFloors'), isTrue);
    expect(measure.contains('ZWorkspacePrimaryNav('), isTrue);
  });

  test('3D keeps navigation cutaway walk and render controls', () {
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

  test('catalog remains a real object source for the Measure Objects layer', () {
    final equipment = source('lib/screens/master_equipment_screen.dart');
    for (final action in const [
      'ObjectCatalog.items',
      '_search',
      '_showFilters',
      '_favorites',
      'onAdd',
      '_add(',
    ]) {
      expect(equipment.contains(action), isTrue, reason: 'Missing catalog action: $action');
    }
  });

  test('Elevations are layered working drawings from project geometry', () {
    final elevations = source('lib/screens/layered_elevations_screen.dart');
    final painter = source('lib/widgets/elevation_painter.dart');
    expect(elevations.contains('GeometryService.elevationRuns'), isTrue);
    expect(elevations.contains("label: 'Проёмы'"), isTrue);
    expect(elevations.contains("label: 'Электрика'"), isTrue);
    expect(elevations.contains("label: 'Объекты'"), isTrue);
    expect(elevations.contains("label: 'Материалы'"), isTrue);
    expect(elevations.contains('InteractiveViewer('), isTrue);
    expect(elevations.contains('ElevationPainter('), isTrue);
    expect(painter.contains('_drawElectricalForEdge('), isTrue);
    expect(painter.contains('_drawMountedObjectsForEdge('), isTrue);
    expect(painter.contains('_drawDimensionChain('), isTrue);
  });
}
