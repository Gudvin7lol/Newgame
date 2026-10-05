from pathlib import Path

root = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'anchor not found in {path}: {old[:100]!r}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


projects = root / 'lib/screens/projects_screen.dart'
replace_once(
    projects,
    "import 'floors_screen.dart';\n",
    "import 'floor_workspace_screen.dart';\n",
)
replace_once(
    projects,
    """  Future<void> _open(MeasureProject project) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FloorsScreen(project: project, onChanged: _save),
      ),
    );
    if (mounted) setState(() {});
  }
""",
    """  Future<void> _open(MeasureProject project) async {
    if (project.floors.isEmpty) {
      project.floors.add(FloorPlan(id: _id('f'), name: 'Этаж 1'));
      await _save();
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FloorWorkspaceScreen(
          project: project,
          floor: project.floors.first,
          onChanged: _save,
        ),
      ),
    );
    if (mounted) setState(() {});
  }
""",
)
replace_once(
    projects,
    "subtitle: 'Открыть этажи и рабочее пространство',",
    "subtitle: 'Открыть рабочее пространство',",
)

editor = root / 'lib/screens/plan_editor_master_v4_screen.dart'
replace_once(
    editor,
    """import '../services/geometry_service.dart';
import '../services/material_catalog.dart';
""",
    """import '../services/geometry_service.dart';
import '../services/material_catalog.dart';
import '../services/object_catalog.dart';
import '../services/plan_direct_interaction.dart';
import '../services/space_check_service.dart';
""",
)
replace_once(
    editor,
    """  String? _wallStartNodeId;
  String? _dimensionStartNodeId;
  String _materialCategory = 'Пол';
""",
    """  String? _wallStartNodeId;
  String? _dimensionStartNodeId;
  String? _dragObjectId;
  bool _dragObjectDirty = false;
  bool _layoutDragDirty = false;
  String _materialCategory = 'Пол';
""",
)

interaction_methods = r'''
  PlanObject? _planObjectById(String? id) {
    if (id == null) return null;
    for (final object in floor.planObjects) {
      if (object.id == id) return object;
    }
    return null;
  }

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

  void _syncGroupedFloorOffsets(RoomMaterialSettings source) {
    if (floor.carpetRoomIds.isEmpty) return;
    for (final meta in floor.roomMetas) {
      if (!floor.carpetRoomIds.contains(meta.id) ||
          identical(meta.materials, source)) {
        continue;
      }
      final target = meta.materials;
      target.laminateOffsetXMm = source.laminateOffsetXMm;
      target.laminateOffsetYMm = source.laminateOffsetYMm;
      target.tileOffsetXMm = source.tileOffsetXMm;
      target.tileOffsetYMm = source.tileOffsetYMm;
    }
  }

  void _moveFloorLayout(
    RoomMaterialSettings settings,
    DragUpdateDetails details,
  ) {
    PlanDirectInteraction.shiftFloorLayout(
      settings,
      worldDxMm: details.delta.dx / _mmToPx,
      worldDyMm: details.delta.dy / _mmToPx,
    );
    _syncGroupedFloorOffsets(settings);
    _layoutDragDirty = true;
    setState(() {});
  }

  Future<void> _finishLayoutDrag() async {
    if (!_layoutDragDirty) return;
    _layoutDragDirty = false;
    await _changed();
  }

  Widget? _layoutDragRegion() {
    if (!_materialPickMode || _materialCategory != 'Пол') return null;
    final face = _selectedRoomFace;
    final meta = _selectedRoomMeta;
    if (face == null || meta == null || face.innerPolygon.length < 3) return null;

    final points = face.innerPolygon
        .map(
          (point) => _origin + Offset(
            point.x * _mmToPx,
            point.y * _mmToPx,
          ),
        )
        .toList(growable: false);
    final minX = points.map((p) => p.dx).reduce(math.min);
    final maxX = points.map((p) => p.dx).reduce(math.max);
    final minY = points.map((p) => p.dy).reduce(math.min);
    final maxY = points.map((p) => p.dy).reduce(math.max);
    final local = points
        .map((point) => point - Offset(minX, minY))
        .toList(growable: false);

    return Positioned(
      left: minX,
      top: minY,
      width: math.max(1, maxX - minX),
      height: math.max(1, maxY - minY),
      child: ClipPath(
        clipper: _RoomDragClipper(local),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => _layoutDragDirty = false,
          onPanUpdate: (details) => _moveFloorLayout(meta.materials, details),
          onPanEnd: (_) => _finishLayoutDrag(),
          onPanCancel: _finishLayoutDrag,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

'''
replace_once(editor, "  void _fit() {\n", interaction_methods + "  void _fit() {\n")

replace_once(
    editor,
    """                  child: GestureDetector(
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
""",
    """                  child: Stack(
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
""",
)

clipper = r'''
class _RoomDragClipper extends CustomClipper<Path> {
  const _RoomDragClipper(this.points);
  final List<Offset> points;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _RoomDragClipper oldClipper) =>
      oldClipper.points != points;
}

'''
replace_once(editor, "class _ToolRail extends StatelessWidget {\n", clipper + "class _ToolRail extends StatelessWidget {\n")

pubspec = root / 'pubspec.yaml'
replace_once(pubspec, 'version: 1.5.6+115\n', 'version: 1.5.6+116\n')
