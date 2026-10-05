from pathlib import Path

path = Path('zamer-app/lib/screens/plan_editor_master_v4_screen.dart')
source = path.read_text(encoding='utf-8')

if "../services/plan_direct_interaction.dart" not in source:
    source = source.replace(
        "import '../services/material_catalog.dart';\n",
        "import '../services/material_catalog.dart';\n"
        "import '../services/object_catalog.dart';\n"
        "import '../services/plan_direct_interaction.dart';\n"
        "import '../services/space_check_service.dart';\n",
        1,
    )

state_anchor = "  String? _dimensionStartNodeId;\n  String _materialCategory = 'Пол';"
if "String? _dragObjectId;" not in source:
    assert state_anchor in source
    source = source.replace(
        state_anchor,
        "  String? _dimensionStartNodeId;\n"
        "  String? _dragObjectId;\n"
        "  bool _dragObjectDirty = false;\n"
        "  bool _layoutDragDirty = false;\n"
        "  String _materialCategory = 'Пол';",
        1,
    )

methods = r'''
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
      worldDxMm: details.delta.dx / (_mmToPx * math.max(.1, _scale)),
      worldDyMm: details.delta.dy / (_mmToPx * math.max(.1, _scale)),
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
          (point) => _canvasToViewport(
            _origin + Offset(
              point.x * _mmToPx,
              point.y * _mmToPx,
            ),
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
      key: ValueKey('direct-layout:${meta.id}'),
      left: minX,
      top: minY,
      width: math.max(1.0, maxX - minX),
      height: math.max(1.0, maxY - minY),
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
if "Offset _canvasToViewport" not in source:
    anchor = "  void _fit() {\n"
    assert anchor in source
    source = source.replace(anchor, methods + anchor, 1)

overlay_anchor = "              Positioned(\n                left: 8,\n                top: 8,\n                child: _ToolRail("
if "..._objectDragRegions()," not in source:
    assert overlay_anchor in source
    source = source.replace(
        overlay_anchor,
        "              if (_layoutDragRegion() case final region?) region,\n"
        "              ..._objectDragRegions(),\n" + overlay_anchor,
        1,
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
if "class _RoomDragClipper" not in source:
    anchor = "class _ToolRail extends StatelessWidget {\n"
    assert anchor in source
    source = source.replace(anchor, clipper + anchor, 1)

for required in (
    "PlanDirectInteraction.moveObjectByMm",
    "PlanDirectInteraction.shiftFloorLayout",
    "..._objectDragRegions(),",
    "class _RoomDragClipper",
):
    assert required in source, required

path.write_text(source, encoding='utf-8')
print('Recovered direct plan interaction.')
