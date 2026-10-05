from pathlib import Path

root = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'anchor not found in {path}: {old[:120]!r}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


# 1) The real app entry is HomeConceptScreen. Project cards must open the
# workspace directly instead of routing through the legacy FloorsScreen gate.
home = root / 'lib/screens/home_concept_screen.dart'
replace_once(home, "import 'floors_screen.dart';\n", '')
replace_once(
    home,
    """  Future<void> _openProject(MeasureProject project) async {
    await _rememberOpened(project);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FloorsScreen(project: project, onChanged: _save),
      ),
    );
    if (mounted) setState(() {});
  }
""",
    """  Future<void> _openProject(MeasureProject project) async {
    await _rememberOpened(project);
    if (project.floors.isEmpty) {
      project.floors.add(FloorPlan(id: _id('f'), name: 'Этаж 1'));
      await _save();
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FloorWorkspaceScreen(
          project: project,
          floor: project.floors.first,
          onChanged: _save,
          initialMode: 0,
        ),
      ),
    );
    if (mounted) setState(() {});
  }
""",
)

# 2) Preserve the approved measure shell, but restore the master five-section
# navigation that was hidden by the old full-canvas UI change.
measure = root / 'lib/screens/measure_concept_workspace_screen.dart'
text = measure.read_text(encoding='utf-8')
text = text.replace(
    "import '../models/models.dart';\n",
    "import '../models/models.dart';\nimport '../widgets/workspace_navigation.dart';\n",
    1,
)
text = text.replace(
    """    required this.onCatalog,
  });
""",
    """    required this.onCatalog,
    required this.onPrimaryModeSelected,
  });
""",
    1,
)
text = text.replace(
    """  final VoidCallback onCatalog;

  @override
""",
    """  final VoidCallback onCatalog;
  final ValueChanged<int> onPrimaryModeSelected;

  @override
""",
    1,
)
start = text.find('  Future<void> _showTutorial() async {')
end = text.find('  @override\n  Widget build(BuildContext context) {', start)
if start < 0 or end < 0:
    raise SystemExit('tutorial block anchor missing')
text = text[:start] + text[end:]
old_nav = """            _ConceptBottomNav(
              onHome: widget.onHome,
              onProjects: widget.onProjects,
              onAdd: widget.onOpenObjects,
              onCatalog: widget.onCatalog,
              onTutorial: _showTutorial,
              onMore: widget.onMore,
            ),
"""
new_nav = """            _ConceptBottomNav(
              onHome: widget.onHome,
              onModeSelected: widget.onPrimaryModeSelected,
            ),
"""
if old_nav not in text:
    raise SystemExit('concept nav usage anchor missing')
text = text.replace(old_nav, new_nav, 1)
nav_start = text.find('class _ConceptBottomNav extends StatelessWidget {')
if nav_start < 0:
    raise SystemExit('concept bottom nav class anchor missing')
text = text[:nav_start] + """class _ConceptBottomNav extends StatelessWidget {
  const _ConceptBottomNav({
    required this.onHome,
    required this.onModeSelected,
  });

  final VoidCallback onHome;
  final ValueChanged<int> onModeSelected;

  @override
  Widget build(BuildContext context) => ZWorkspacePrimaryNav(
        selectedIndex: 0,
        onSelected: onModeSelected,
        onHome: onHome,
      );
}
"""
measure.write_text(text, encoding='utf-8')

workspace = root / 'lib/screens/floor_workspace_screen.dart'
replace_once(
    workspace,
    """        onCatalog: _openObjectsFromMeasure,
      );
""",
    """        onCatalog: _openObjectsFromMeasure,
        onPrimaryModeSelected: _selectPrimaryMode,
      );
""",
)

# 3) Direct manipulation must live ABOVE InteractiveViewer. Gesture regions
# inside its transformed child lose the arena to viewport pan/zoom on Android.
editor = root / 'lib/screens/plan_editor_master_v4_screen.dart'
text = editor.read_text(encoding='utf-8')
text = text.replace(
    """  void initState() {
    super.initState();
    GeometryService.syncRoomMetadata(floor);
""",
    """  void initState() {
    super.initState();
    _transform.addListener(_handleTransformChanged);
    GeometryService.syncRoomMetadata(floor);
""",
    1,
)
text = text.replace(
    """  void dispose() {
    _transform.dispose();
    super.dispose();
  }
""",
    """  void dispose() {
    _transform.removeListener(_handleTransformChanged);
    _transform.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    if (mounted) setState(() {});
  }
""",
    1,
)
old_interaction = """
  void _movePlanObject(PlanObject object, DragUpdateDetails details) {
    if (_dragObjectId != object.id) return;
    final oldX = object.xMm;
    final oldY = object.yMm;
    PlanDirectInteraction.moveObjectByMm(
      object,
      dxMm: details.delta.dx / _mmToPx,
      dyMm: details.delta.dy / _mmToPx,
      snapMm: _snapping ? 10 : 0,
    );
    if (SpaceCheckService.intersectsWall(floor, object)) {
      object.xMm = oldX;
      object.yMm = oldY;
    } else if (object.xMm != oldX || object.yMm != oldY) {
      _dragObjectDirty = true;
    }
    setState(() {});
  }

  Future<void> _finishObjectDrag() async {
    if (_dragObjectId == null) return;
    final changed = _dragObjectDirty;
    setState(() {
      _dragObjectId = null;
      _dragObjectDirty = false;
    });
    if (changed) await _changed();
  }

  Iterable<Widget> _objectDragRegions() sync* {
    for (final object in floor.planObjects) {
      if (!_visibleLayers.contains(object.layer)) continue;
      final catalog = ObjectCatalog.byId(object.catalogId);
      final mount = catalog.id == object.catalogId
          ? catalog.mount
          : CatalogMount.floor;
      // Fixed wall and ceiling fixtures stay hosted. Their dedicated editors
      // manage mounting height and wall-side placement.
      if (mount != CatalogMount.floor) continue;

      final width = math.max(28.0, object.widthMm * _mmToPx + 14);
      final depth = math.max(28.0, object.depthMm * _mmToPx + 14);
      final center = _origin + Offset(
        object.xMm * _mmToPx,
        object.yMm * _mmToPx,
      );
      yield Positioned(
        key: ValueKey('direct-object:${object.id}'),
        left: center.dx - width / 2,
        top: center.dy - depth / 2,
        width: width,
        height: depth,
        child: Transform.rotate(
          angle: object.rotationDeg * math.pi / 180,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) => setState(() {
              _dragObjectId = object.id;
              _dragObjectDirty = false;
            }),
            onPanUpdate: (details) => _movePlanObject(object, details),
            onPanEnd: (_) => _finishObjectDrag(),
            onPanCancel: _finishObjectDrag,
            child: const SizedBox.expand(),
          ),
        ),
      );
    }
  }
"""
new_interaction = """
  Offset _canvasToViewport(Offset point) {
    final m = _transform.value.storage;
    return Offset(
      m[0] * point.dx + m[4] * point.dy + m[12],
      m[1] * point.dx + m[5] * point.dy + m[13],
    );
  }

  void _movePlanObject(PlanObject object, DragUpdateDetails details) {
    if (_dragObjectId != object.id) return;
    final oldX = object.xMm;
    final oldY = object.yMm;
    final viewScale = math.max(.1, _scale);
    PlanDirectInteraction.moveObjectByMm(
      object,
      dxMm: details.delta.dx / (_mmToPx * viewScale),
      dyMm: details.delta.dy / (_mmToPx * viewScale),
      snapMm: _snapping ? 10 : 0,
    );
    if (SpaceCheckService.intersectsWall(floor, object)) {
      object.xMm = oldX;
      object.yMm = oldY;
    } else if (object.xMm != oldX || object.yMm != oldY) {
      _dragObjectDirty = true;
    }
    setState(() {});
  }

  Future<void> _finishObjectDrag() async {
    if (_dragObjectId == null) return;
    final changed = _dragObjectDirty;
    setState(() {
      _dragObjectId = null;
      _dragObjectDirty = false;
    });
    if (changed) await _changed();
  }

  Iterable<Widget> _objectDragRegions() sync* {
    final viewScale = math.max(.1, _scale);
    for (final object in floor.planObjects) {
      if (!_visibleLayers.contains(object.layer)) continue;
      final catalog = ObjectCatalog.byId(object.catalogId);
      final mount = catalog.id == object.catalogId
          ? catalog.mount
          : CatalogMount.floor;
      if (mount != CatalogMount.floor) continue;

      final width = math.max(
        34.0,
        object.widthMm * _mmToPx * viewScale + 16,
      );
      final depth = math.max(
        34.0,
        object.depthMm * _mmToPx * viewScale + 16,
      );
      final center = _canvasToViewport(
        _origin + Offset(object.xMm * _mmToPx, object.yMm * _mmToPx),
      );
      yield Positioned(
        key: ValueKey('direct-object:${object.id}'),
        left: center.dx - width / 2,
        top: center.dy - depth / 2,
        width: width,
        height: depth,
        child: Transform.rotate(
          angle: object.rotationDeg * math.pi / 180,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => setState(() {
              _dragObjectId = object.id;
              _dragObjectDirty = false;
            }),
            onPanUpdate: (details) => _movePlanObject(object, details),
            onPanEnd: (_) => _finishObjectDrag(),
            onPanCancel: _finishObjectDrag,
            child: const SizedBox.expand(),
          ),
        ),
      );
    }
  }
"""
if old_interaction not in text:
    raise SystemExit('object interaction block anchor missing')
text = text.replace(old_interaction, new_interaction, 1)
text = text.replace(
    """      worldDxMm: details.delta.dx / _mmToPx,
      worldDyMm: details.delta.dy / _mmToPx,
""",
    """      worldDxMm: details.delta.dx / (_mmToPx * math.max(.1, _scale)),
      worldDyMm: details.delta.dy / (_mmToPx * math.max(.1, _scale)),
""",
    1,
)
text = text.replace(
    """    final points = face.innerPolygon
        .map(
          (point) => _origin + Offset(
            point.x * _mmToPx,
            point.y * _mmToPx,
          ),
        )
        .toList(growable: false);
""",
    """    final points = face.innerPolygon
        .map(
          (point) => _canvasToViewport(
            _origin + Offset(
              point.x * _mmToPx,
              point.y * _mmToPx,
            ),
          ),
        )
        .toList(growable: false);
""",
    1,
)
text = text.replace(
    """    return Positioned(
      left: minX,
""",
    """    return Positioned(
      key: ValueKey('direct-layout:${meta.id}'),
      left: minX,
""",
    1,
)
old_canvas = """                  child: Stack(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: _tapCanvas,
                        child: CustomPaint(
                          size: _canvasSize,
                          painter: CadPlanPainter(
                            floor: floor,
                            mmToPx: _mmToPx,
                            origin: _origin,
                            selectedWallId: _selectedWallId,
                            showGrid: _grid,
                            visibleLayers: _visibleLayers,
                          ),
                        ),
                      ),
                      if (_layoutDragRegion() case final region?) region,
                      ..._objectDragRegions(),
                    ],
                  ),
                ),
              ),
              Positioned(
"""
new_canvas = """                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _tapCanvas,
                    child: CustomPaint(
                      size: _canvasSize,
                      painter: CadPlanPainter(
                        floor: floor,
                        mmToPx: _mmToPx,
                        origin: _origin,
                        selectedWallId: _selectedWallId,
                        showGrid: _grid,
                        visibleLayers: _visibleLayers,
                      ),
                    ),
                  ),
                ),
              ),
              if (_layoutDragRegion() case final region?) region,
              ..._objectDragRegions(),
              Positioned(
"""
if old_canvas not in text:
    raise SystemExit('canvas interaction placement anchor missing')
text = text.replace(old_canvas, new_canvas, 1)
editor.write_text(text, encoding='utf-8')

# 4) Lock the recovered route/navigation plus real drag behaviour with tests.
test = root / 'test/main_workspace_regression_test.dart'
test.write_text(r'''import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/screens/plan_editor_master_v4_screen.dart';

FloorPlan _room({bool withObject = false}) {
  final floor = FloorPlan(
    id: 'f1',
    name: 'Этаж 1',
    nodes: [
      PlanNode(id: 'n1', xMm: 0, yMm: 0),
      PlanNode(id: 'n2', xMm: 4000, yMm: 0),
      PlanNode(id: 'n3', xMm: 4000, yMm: 4000),
      PlanNode(id: 'n4', xMm: 0, yMm: 4000),
    ],
    walls: [
      PlanWall(id: 'w1', startNodeId: 'n1', endNodeId: 'n2'),
      PlanWall(id: 'w2', startNodeId: 'n2', endNodeId: 'n3'),
      PlanWall(id: 'w3', startNodeId: 'n3', endNodeId: 'n4'),
      PlanWall(id: 'w4', startNodeId: 'n4', endNodeId: 'n1'),
    ],
  );
  if (withObject) {
    floor.planObjects.add(
      PlanObject(
        id: 'o1',
        type: PlanObjectType.furniture,
        xMm: 2000,
        yMm: 2000,
        widthMm: 600,
        depthMm: 600,
        heightMm: 800,
      ),
    );
  }
  return floor;
}

Widget _editor(FloorPlan floor) => MaterialApp(
      home: Scaffold(
        body: PlanEditorMasterV4Screen(
          floor: floor,
          onChanged: () async {},
          onOpenObjects: () {},
          onOpenReview: () {},
          onOpenGeometry: () {},
          onOpen3D: () {},
          onOpenFloors: () {},
          onOpenSettings: () {},
          onOpenMaterials: () {},
          onUndo: null,
          onRedo: null,
          canUndo: false,
          canRedo: false,
        ),
      ),
    );

void main() {
  test('project cards open workspace directly and master sections stay reachable', () {
    final home = File('lib/screens/home_concept_screen.dart').readAsStringSync();
    final measure = File(
      'lib/screens/measure_concept_workspace_screen.dart',
    ).readAsStringSync();
    expect(home, contains('builder: (_) => FloorWorkspaceScreen('));
    expect(home, isNot(contains('builder: (_) => FloorsScreen(')));
    expect(measure, contains('ZWorkspacePrimaryNav('));
    expect(measure, contains('onPrimaryModeSelected'));
  });

  testWidgets('furniture moves directly on the main measure canvas', (tester) async {
    final floor = _room(withObject: true);
    await tester.pumpWidget(_editor(floor));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final handle = find.byKey(const ValueKey('direct-object:o1'));
    expect(handle, findsOneWidget);
    final before = floor.planObjects.single.xMm;
    await tester.drag(handle, const Offset(48, 0));
    await tester.pumpAndSettle();
    expect(floor.planObjects.single.xMm, greaterThan(before));
  });

  testWidgets('selected floor layout can be dragged on the main measure canvas',
      (tester) async {
    final floor = _room();
    await tester.pumpWidget(_editor(floor));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final viewer = find.byType(InteractiveViewer);
    expect(viewer, findsOneWidget);
    await tester.tapAt(tester.getCenter(viewer));
    await tester.pump();

    expect(floor.roomMetas, isNotEmpty);
    final settings = floor.roomMetas.first.materials;
    final beforeX = settings.laminateOffsetXMm;
    final beforeY = settings.laminateOffsetYMm;
    final handle = find.byKey(
      ValueKey('direct-layout:${floor.roomMetas.first.id}'),
    );
    expect(handle, findsOneWidget);
    await tester.drag(handle, const Offset(36, 24));
    await tester.pumpAndSettle();
    expect(
      settings.laminateOffsetXMm != beforeX ||
          settings.laminateOffsetYMm != beforeY,
      isTrue,
    );
  });
}
''', encoding='utf-8')

pubspec = root / 'pubspec.yaml'
replace_once(pubspec, 'version: 1.5.6+116\n', 'version: 1.5.6+117\n')
