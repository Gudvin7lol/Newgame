from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'zamer-app'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    return text.replace(old, new, 1)


def replace_count(text: str, old: str, new: str, expected: int, label: str) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{label}: expected {expected} matches, found {count}')
    return text.replace(old, new)


pubspec_path = APP / 'pubspec.yaml'
pubspec = pubspec_path.read_text()
if 'version: 1.5.6+50' in pubspec:
    print('1.5.6+50 interaction/tile patch already applied')
    raise SystemExit(0)
if 'version: 1.5.6+49' not in pubspec:
    raise SystemExit('unexpected app version; refusing automatic +50 patch')

# Object catalogue: magnetic 90-degree snap and real GLB thumbnail previews.
planning_path = APP / 'lib/screens/planning_objects_screen.dart'
planning = planning_path.read_text()
planning = replace_once(
    planning,
    "import '../models/models.dart';\nimport '../services/object_catalog.dart';",
    "import '../models/models.dart';\nimport '../services/angle_snap_service.dart';\nimport '../services/object_catalog.dart';",
    'planning angle snap import',
)
planning = replace_once(
    planning,
    "import '../services/space_check_service.dart';",
    "import '../services/space_check_service.dart';\nimport '../widgets/model_thumbnail.dart';",
    'planning thumbnail import',
)
planning = replace_once(
    planning,
    "    if (d.pointerCount >= 2) {\n      o.rotationDeg = _gestureBaseRotation + d.rotation * 180 / math.pi;\n    } else {",
    "    if (d.pointerCount >= 2) {\n      final rawRotation = _gestureBaseRotation + d.rotation * 180 / math.pi;\n      o.rotationDeg = AngleSnapService.snapQuarterTurn(rawRotation);\n    } else {",
    'planning quarter turn snap',
)
old_preview = """  Widget _modelPreview(ObjectCatalogItem item, double size) {
    final preview = FloorPlan(
      id: 'preview',
      name: 'preview',
      planObjects: [
        PlanObject(
          id: item.id,
          type: item.type,
          xMm: 0,
          yMm: 0,
          widthMm: item.widthMm,
          depthMm: item.depthMm,
          heightMm: item.heightMm,
          catalogId: item.id,
        ),
      ],
    );
    final scale = math.min(
      (size - 12) / item.widthMm,
      (size - 12) / item.depthMm,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _PlanningPainter(
            floor: preview,
            scale: scale,
            origin: Offset(size / 2, size / 2),
            darkPreview: true,
          ),
        ),
      ),
    );
  }
"""
new_preview = """  Widget _modelPreview(ObjectCatalogItem item, double size) {
    final preview = FloorPlan(
      id: 'preview',
      name: 'preview',
      planObjects: [
        PlanObject(
          id: item.id,
          type: item.type,
          xMm: 0,
          yMm: 0,
          widthMm: item.widthMm,
          depthMm: item.depthMm,
          heightMm: item.heightMm,
          catalogId: item.id,
        ),
      ],
    );
    final scale = math.min(
      (size - 12) / item.widthMm,
      (size - 12) / item.depthMm,
    );
    final fallback = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _PlanningPainter(
            floor: preview,
            scale: scale,
            origin: Offset(size / 2, size / 2),
            darkPreview: true,
          ),
        ),
      ),
    );
    return ZamerModelThumbnail(
      catalogId: item.id,
      size: size,
      fallback: fallback,
    );
  }
"""
planning = replace_once(planning, old_preview, new_preview, 'real GLB catalogue preview')
planning_path.write_text(planning)

# Persist a real per-wall 0/90 degree tile orientation.
models_path = APP / 'lib/models/models.dart'
models = models_path.read_text()
models = replace_once(
    models,
    "    Map<String, bool>? wallTileRunEnabled,\n    Map<String, bool>? wallTileRunMirrored,\n  }) : wallTileRunOffsetX = wallTileRunOffsetX ?? {},\n       wallTileRunOffsetY = wallTileRunOffsetY ?? {},\n       wallTileRunEnabled = wallTileRunEnabled ?? {},\n       wallTileRunMirrored = wallTileRunMirrored ?? {};",
    "    Map<String, bool>? wallTileRunEnabled,\n    Map<String, bool>? wallTileRunMirrored,\n    Map<String, bool>? wallTileRunRotated,\n  }) : wallTileRunOffsetX = wallTileRunOffsetX ?? {},\n       wallTileRunOffsetY = wallTileRunOffsetY ?? {},\n       wallTileRunEnabled = wallTileRunEnabled ?? {},\n       wallTileRunMirrored = wallTileRunMirrored ?? {},\n       wallTileRunRotated = wallTileRunRotated ?? {};",
    'wall tile rotated constructor',
)
models = replace_once(
    models,
    "  final Map<String, bool> wallTileRunEnabled;\n  final Map<String, bool> wallTileRunMirrored;",
    "  final Map<String, bool> wallTileRunEnabled;\n  final Map<String, bool> wallTileRunMirrored;\n  final Map<String, bool> wallTileRunRotated;",
    'wall tile rotated field',
)
models = replace_once(
    models,
    "  bool wallTileMirroredFor(String runId) =>\n      wallTileRunMirrored[runId] ?? false;",
    "  bool wallTileMirroredFor(String runId) =>\n      wallTileRunMirrored[runId] ?? false;\n  bool wallTileRotatedFor(String runId) => wallTileRunRotated[runId] ?? false;\n  double wallTileWidthFor(String runId) =>\n      wallTileRotatedFor(runId) ? wallTileHeightMm : wallTileWidthMm;\n  double wallTileHeightFor(String runId) =>\n      wallTileRotatedFor(runId) ? wallTileWidthMm : wallTileHeightMm;",
    'wall tile rotated helpers',
)
models = replace_once(
    models,
    "    'wallTileRunEnabled': wallTileRunEnabled,\n    'wallTileRunMirrored': wallTileRunMirrored,",
    "    'wallTileRunEnabled': wallTileRunEnabled,\n    'wallTileRunMirrored': wallTileRunMirrored,\n    'wallTileRunRotated': wallTileRunRotated,",
    'wall tile rotated json write',
)
models = replace_once(
    models,
    "    wallTileRunMirrored: ((json['wallTileRunMirrored'] as Map?) ?? const {}).map(\n      (k, v) => MapEntry(k.toString(), v as bool),\n    ),\n  );",
    "    wallTileRunMirrored: ((json['wallTileRunMirrored'] as Map?) ?? const {}).map(\n      (k, v) => MapEntry(k.toString(), v as bool),\n    ),\n    wallTileRunRotated: ((json['wallTileRunRotated'] as Map?) ?? const {}).map(\n      (k, v) => MapEntry(k.toString(), v as bool),\n    ),\n  );",
    'wall tile rotated json read',
)
models_path.write_text(models)

# Scene geometry: carry rotation and the original wall-space X origin through
# every split segment around windows and doors.
geometry_path = APP / 'lib/renderer3d/zamer_scene_geometry.dart'
geometry = geometry_path.read_text()
geometry = replace_count(
    geometry,
    "          tileMirrored: settings.wallTileMirroredFor(runId),\n          groutMm: settings.wallTileGroutMm,",
    "          tileMirrored: settings.wallTileMirroredFor(runId),\n          tileRotated: settings.wallTileRotatedFor(runId),\n          groutMm: settings.wallTileGroutMm,",
    2,
    'scene wall tile rotated layers',
)
geometry = replace_once(
    geometry,
    "    required this.tileMirrored,\n    required this.groutMm,",
    "    required this.tileMirrored,\n    required this.tileRotated,\n    required this.groutMm,",
    'wall finish rotated constructor',
)
geometry = replace_once(
    geometry,
    "  final bool tileEnabled, tileMirrored;",
    "  final bool tileEnabled, tileMirrored, tileRotated;",
    'wall finish rotated field',
)
geometry = replace_once(
    geometry,
    "    required this.lengthMm,\n    required this.thicknessMm,\n    required this.bottomMm,\n    required this.heightMm,",
    "    required this.lengthMm,\n    required this.thicknessMm,\n    required this.bottomMm,\n    required this.heightMm,\n    this.textureStartMm = 0,",
    'wall piece texture start constructor',
)
geometry = replace_once(
    geometry,
    "  final double lengthMm, thicknessMm, bottomMm, heightMm;",
    "  final double lengthMm, thicknessMm, bottomMm, heightMm;\n  final double textureStartMm;",
    'wall piece texture start field',
)
geometry = replace_once(
    geometry,
    "          bottomMm: bottom,\n          heightMm: height,\n          materialId: finish.wallMaterialId,",
    "          bottomMm: bottom,\n          heightMm: height,\n          textureStartMm: safeFrom,\n          materialId: finish.wallMaterialId,",
    'straight wall piece texture origin',
)
geometry_path.write_text(geometry)

# GPU: include rotation in the scene fingerprint and make texture repeats use
# physical tile dimensions even on tiny wall pieces above/beside openings.
renderer_path = APP / 'lib/renderer3d/zamer_gpu_viewport.dart'
renderer = renderer_path.read_text()
renderer = replace_once(
    renderer,
    "        ...m.wallTileRunEnabled.keys,\n        ...m.wallTileRunMirrored.keys,",
    "        ...m.wallTileRunEnabled.keys,\n        ...m.wallTileRunMirrored.keys,\n        ...m.wallTileRunRotated.keys,",
    'rotated keys in GPU fingerprint',
)
renderer = replace_once(
    renderer,
    "          m.wallTileRunEnabled[runId],\n          m.wallTileRunMirrored[runId],",
    "          m.wallTileRunEnabled[runId],\n          m.wallTileRunMirrored[runId],\n          m.wallTileRunRotated[runId],",
    'rotated value in GPU fingerprint',
)
old_transform = """    if (finish.tileEnabled && texture != null) {
      final tileW = math.max(20.0, finish.tileWidthMm);
      final tileH = math.max(20.0, finish.tileHeightMm);
      material.baseColorTextureTransform = TextureTransform(
        scale: vm.Vector2(
          (finish.tileMirrored ? -1.0 : 1.0) *
              math.max(1.0, wall.lengthMm / tileW),
          math.max(1.0, wall.heightMm / tileH),
        ),
        offset: vm.Vector2(
          finish.tileMirrored
              ? 1.0 - finish.tileOffsetXMm / tileW
              : finish.tileOffsetXMm / tileW,
          -finish.tileOffsetYMm / tileH,
        ),
      );
    }
"""
new_transform = """    if (finish.tileEnabled && texture != null) {
      final sourceTileW = math.max(20.0, finish.tileWidthMm);
      final sourceTileH = math.max(20.0, finish.tileHeightMm);
      final tileW = finish.tileRotated ? sourceTileH : sourceTileW;
      final tileH = finish.tileRotated ? sourceTileW : sourceTileH;
      final repeatX = math.max(0.001, wall.lengthMm / tileW);
      final repeatY = math.max(0.001, wall.heightMm / tileH);
      final wallU = (wall.textureStartMm + finish.tileOffsetXMm) / tileW;
      final wallV = (wall.bottomMm - finish.tileOffsetYMm) / tileH;
      material.baseColorTextureTransform = TextureTransform(
        scale: vm.Vector2(
          (finish.tileMirrored ? -1.0 : 1.0) * repeatX,
          repeatY,
        ),
        offset: vm.Vector2(
          finish.tileMirrored ? 1.0 - wallU : wallU,
          wallV,
        ),
        rotation: finish.tileRotated ? math.pi / 2 : 0,
      );
    }
"""
renderer = replace_once(renderer, old_transform, new_transform, 'continuous wall tile UV')
renderer_path.write_text(renderer)

# Elevation preview and controls use the same effective 0/90 tile size.
elevation_painter_path = APP / 'lib/widgets/elevation_painter.dart'
elevation_painter = elevation_painter_path.read_text()
elevation_painter = replace_once(
    elevation_painter,
    "    final tw = math.max(1.0, settings.wallTileWidthMm * scale);\n    final th = math.max(1.0, settings.wallTileHeightMm * scale);\n    final offX =\n        (settings.wallTileXFor(run.id) % settings.wallTileWidthMm) * scale;\n    final offY =\n        (settings.wallTileYFor(run.id) % settings.wallTileHeightMm) * scale;",
    "    final tileWidthMm = settings.wallTileWidthFor(run.id);\n    final tileHeightMm = settings.wallTileHeightFor(run.id);\n    final tw = math.max(1.0, tileWidthMm * scale);\n    final th = math.max(1.0, tileHeightMm * scale);\n    final offX = (settings.wallTileXFor(run.id) % tileWidthMm) * scale;\n    final offY = (settings.wallTileYFor(run.id) % tileHeightMm) * scale;",
    'elevation rotated tile dimensions',
)
elevation_painter_path.write_text(elevation_painter)

elevations_path = APP / 'lib/screens/elevations_screen.dart'
elevations = elevations_path.read_text()
elevations = replace_once(
    elevations,
    "    final tileW = math.max(1.0, s.wallTileWidthMm).toDouble();\n    final tileH = math.max(1.0, s.wallTileHeightMm).toDouble();",
    "    final tileW = math.max(1.0, s.wallTileWidthFor(run.id)).toDouble();\n    final tileH = math.max(1.0, s.wallTileHeightFor(run.id)).toDouble();",
    'wall tile drag effective size',
)
elevations = replace_once(
    elevations,
    "                              children: [\n                                OutlinedButton.icon(\n                                  onPressed: () async {\n                                    settings.wallTileRunMirrored[run.id] =",
    "                              children: [\n                                OutlinedButton.icon(\n                                  onPressed: () async {\n                                    settings.wallTileRunRotated[run.id] =\n                                        !settings.wallTileRotatedFor(run.id);\n                                    await widget.onChanged();\n                                    if (mounted) setState(() {});\n                                  },\n                                  icon: const Icon(Icons.rotate_90_degrees_cw),\n                                  label: Text(\n                                    settings.wallTileRotatedFor(run.id)\n                                        ? 'Плитка 90°'\n                                        : 'Повернуть 90°',\n                                  ),\n                                ),\n                                OutlinedButton.icon(\n                                  onPressed: () async {\n                                    settings.wallTileRunMirrored[run.id] =",
    'wall tile 90 button',
)
elevations = replace_once(
    elevations,
    "                                      settings.wallTileWidthMm,\n                                      settings.wallTileHeightMm,",
    "                                      settings.wallTileWidthFor(run.id),\n                                      settings.wallTileHeightFor(run.id),",
    'wall tile balance rotated size',
)
elevations_path.write_text(elevations)

# Walk UI: make look sensitivity explicit and add a subtle aiming reference.
floor3d_path = APP / 'lib/screens/floor_3d_screen.dart'
floor3d = floor3d_path.read_text()
floor3d = replace_once(
    floor3d,
    "  double _walkStepMm = 120;\n  double _walkX = 0, _walkY = 0;",
    "  double _walkStepMm = 120;\n  double _lookSensitivity = 0.010;\n  double _walkX = 0, _walkY = 0;",
    'walk look sensitivity state',
)
floor3d = replace_once(
    floor3d,
    "        final angle = _rotation + d.focalPointDelta.dx * 0.010;\n        _rotation = math.atan2(math.sin(angle), math.cos(angle));\n        _tilt = (_tilt - d.focalPointDelta.dy * 0.006)",
    "        final lookSensitivity = _walkMode ? _lookSensitivity : 0.010;\n        final angle = _rotation + d.focalPointDelta.dx * lookSensitivity;\n        _rotation = math.atan2(math.sin(angle), math.cos(angle));\n        _tilt = (_tilt - d.focalPointDelta.dy * lookSensitivity * 0.6)",
    'walk look sensitivity gesture',
)
old_viewport = """            child: ClipRect(
              child: ZamerGpuViewport(
                key: _gpuKey,
                floor: widget.floor,
                rotation: _rotation,
                tilt: _tilt,
                zoom: _zoom,
                cutaway: !_walkMode && _cutaway,
                pan: _pan,
                walkMode: _walkMode,
                walkX: _walkX,
                walkY: _walkY,
              ),
            ),
"""
new_viewport = """            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ZamerGpuViewport(
                    key: _gpuKey,
                    floor: widget.floor,
                    rotation: _rotation,
                    tilt: _tilt,
                    zoom: _zoom,
                    cutaway: !_walkMode && _cutaway,
                    pan: _pan,
                    walkMode: _walkMode,
                    walkX: _walkX,
                    walkY: _walkY,
                  ),
                  if (_walkMode)
                    const IgnorePointer(
                      child: Center(
                        child: Icon(
                          Icons.add,
                          size: 25,
                          color: Color(0xBFFFFFFF),
                          shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                        ),
                      ),
                    ),
                ],
              ),
            ),
"""
floor3d = replace_once(floor3d, old_viewport, new_viewport, 'walk viewport crosshair')
floor3d = replace_once(
    floor3d,
    "                              'Правая часть сцены — осмотр. Левый стик — плавное движение.',",
    "                              'Стик — движение по направлению камеры. Проведи по сцене — осмотр.',",
    'walk help text',
)
old_speed = """                            Row(
                              children: [
                                const Icon(Icons.speed, size: 18),
                                Expanded(
                                  child: Slider(
                                    value: _walkStepMm,
                                    min: 55,
                                    max: 220,
                                    divisions: 11,
                                    label: '${_walkStepMm.round()} мм',
                                    onChanged: (v) =>
                                        setState(() => _walkStepMm = v),
                                  ),
                                ),
                              ],
                            ),
                            FilledButton.tonalIcon(
"""
new_speed = """                            Row(
                              children: [
                                const Tooltip(
                                  message: 'Скорость движения',
                                  child: Icon(Icons.speed, size: 18),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _walkStepMm,
                                    min: 55,
                                    max: 220,
                                    divisions: 11,
                                    label: '${_walkStepMm.round()} мм',
                                    onChanged: (v) =>
                                        setState(() => _walkStepMm = v),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Tooltip(
                                  message: 'Чувствительность обзора',
                                  child: Icon(Icons.visibility_outlined, size: 18),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _lookSensitivity,
                                    min: 0.005,
                                    max: 0.018,
                                    divisions: 13,
                                    label: '${(_lookSensitivity * 1000).round()}',
                                    onChanged: (v) =>
                                        setState(() => _lookSensitivity = v),
                                  ),
                                ),
                              ],
                            ),
                            FilledButton.tonalIcon(
"""
floor3d = replace_once(floor3d, old_speed, new_speed, 'walk sensitivity control')
floor3d_path.write_text(floor3d)

# Add regression tests for magnetic object rotation.
angle_test = APP / 'test/angle_snap_service_test.dart'
angle_test.write_text("""import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/angle_snap_service.dart';

void main() {
  test('quarter-turn snap keeps free angles outside the magnetic threshold', () {
    expect(AngleSnapService.snapQuarterTurn(34), 34);
    expect(AngleSnapService.snapQuarterTurn(54), 54);
    expect(AngleSnapService.snapQuarterTurn(137), 137);
  });

  test('quarter-turn snap catches nearby 0/90/180/270 angles', () {
    expect(AngleSnapService.snapQuarterTurn(6), 0);
    expect(AngleSnapService.snapQuarterTurn(83), 90);
    expect(AngleSnapService.snapQuarterTurn(187), 180);
    expect(AngleSnapService.snapQuarterTurn(263), 270);
    expect(AngleSnapService.snapQuarterTurn(-87), -90);
    expect(AngleSnapService.snapQuarterTurn(354), 360);
  });

  test('custom snap threshold is respected', () {
    expect(AngleSnapService.snapQuarterTurn(84, thresholdDeg: 5), 84);
    expect(AngleSnapService.snapQuarterTurn(86, thresholdDeg: 5), 90);
  });
}
""")

# Version/changelog.
pubspec_path.write_text(pubspec.replace('version: 1.5.6+49', 'version: 1.5.6+50', 1))
changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = """## 1.5.6+50

- Walk Mode синхронизирован с направлением GPU-камеры: «вперёд» теперь всегда совпадает с тем, куда смотрит пользователь; стартовый азимут использует ту же систему координат.
- В оснащении добавлен магнитный snap свободного поворота к 0/90/180/270° в пределах 8°, без потери плавного вращения вне порога.
- Карточки оснащения получают кэшируемое превью из реального LOD2 GLB; 2D-иконка остаётся безопасным fallback для старых или проблемных моделей.
- Настенная плитка получила отдельный поворот 0/90° по каждой стене с сохранением в проекте и обновлением GPU-сцены.
- Исправлен масштаб/фаза плитки вокруг окон и дверей: короткие куски стены больше не растягивают полный тайл на свой размер, а UV продолжается от исходной координаты стены и высоты сегмента.
- В режиме прогулки добавлены регулируемая чувствительность обзора, центральный ориентир и более ясные подсказки управления.

"""
changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+50 interaction/tile/preview patch')
