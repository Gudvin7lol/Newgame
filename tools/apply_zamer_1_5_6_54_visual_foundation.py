from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'zamer-app'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    return text.replace(old, new, 1)


def replace_between(text: str, start: str, end: str, new_block: str, label: str) -> str:
    a = text.find(start)
    if a < 0:
        raise SystemExit(f'{label}: start marker not found')
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f'{label}: end marker not found')
    return text[:a] + new_block + text[b:]


pubspec_path = APP / 'pubspec.yaml'
pubspec = pubspec_path.read_text()
if 'version: 1.5.6+54' in pubspec:
    print('1.5.6+54 visual foundation already applied')
    raise SystemExit(0)
if 'version: 1.5.6+53' not in pubspec:
    raise SystemExit('unexpected app version; refusing automatic +54 patch')

# ---------------------------------------------------------------------------
# Floor tile grout becomes a first-class project value.
# ---------------------------------------------------------------------------
models_path = APP / 'lib/models/models.dart'
models = models_path.read_text()
models = replace_once(
    models,
    """    this.tileOffsetXMm = 0,
    this.tileOffsetYMm = 0,
    this.tileMinCutMm = 120,
""",
    """    this.tileOffsetXMm = 0,
    this.tileOffsetYMm = 0,
    this.floorTileGroutMm = 2,
    this.tileMinCutMm = 120,
""",
    'floor grout constructor default',
)
models = replace_once(
    models,
    """  double tileOffsetXMm;
  double tileOffsetYMm;
  double tileMinCutMm;
""",
    """  double tileOffsetXMm;
  double tileOffsetYMm;
  double floorTileGroutMm;
  double tileMinCutMm;
""",
    'floor grout field',
)
models = replace_once(
    models,
    """    tileWidthMm = valid(tileWidthMm, 20, 600);
    tileHeightMm = valid(tileHeightMm, 20, 600);
""",
    """    tileWidthMm = valid(tileWidthMm, 20, 600);
    tileHeightMm = valid(tileHeightMm, 20, 600);
    floorTileGroutMm = valid(floorTileGroutMm, 0.5, 2);
""",
    'normalize floor grout',
)
models = replace_once(
    models,
    """    'tileOffsetXMm': tileOffsetXMm,
    'tileOffsetYMm': tileOffsetYMm,
    'tileMinCutMm': tileMinCutMm,
""",
    """    'tileOffsetXMm': tileOffsetXMm,
    'tileOffsetYMm': tileOffsetYMm,
    'floorTileGroutMm': floorTileGroutMm,
    'tileMinCutMm': tileMinCutMm,
""",
    'serialize floor grout',
)
models = replace_once(
    models,
    """    tileOffsetXMm: (json['tileOffsetXMm'] as num?)?.toDouble() ?? 0,
    tileOffsetYMm: (json['tileOffsetYMm'] as num?)?.toDouble() ?? 0,
    tileMinCutMm: (json['tileMinCutMm'] as num?)?.toDouble() ?? 120,
""",
    """    tileOffsetXMm: (json['tileOffsetXMm'] as num?)?.toDouble() ?? 0,
    tileOffsetYMm: (json['tileOffsetYMm'] as num?)?.toDouble() ?? 0,
    floorTileGroutMm: (json['floorTileGroutMm'] as num?)?.toDouble() ?? 2,
    tileMinCutMm: (json['tileMinCutMm'] as num?)?.toDouble() ?? 120,
""",
    'deserialize floor grout',
)
models_path.write_text(models)

layout_service_path = APP / 'lib/services/layout_service.dart'
layout_service = layout_service_path.read_text()
layout_service = replace_once(
    layout_service,
    """    to.tileOffsetXMm = from.tileOffsetXMm;
    to.tileOffsetYMm = from.tileOffsetYMm;
""",
    """    to.tileOffsetXMm = from.tileOffsetXMm;
    to.tileOffsetYMm = from.tileOffsetYMm;
    to.floorTileGroutMm = from.floorTileGroutMm;
""",
    'copy floor grout with carpet pattern',
)
layout_service_path.write_text(layout_service)

# ---------------------------------------------------------------------------
# 2D layout uses the configured physical grout width instead of a fixed pixel.
# ---------------------------------------------------------------------------
painter_path = APP / 'lib/widgets/floor_layout_painter.dart'
painter = painter_path.read_text()
painter = replace_once(
    painter,
    """    final stroke = Paint()
      ..color = const Color(0xFF8E99A5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
""",
    """    final stroke = Paint()
      ..color = const Color(0xFF8E99A5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.55, settings.floorTileGroutMm * scale);
""",
    '2d physical grout width',
)
painter_path.write_text(painter)

# ---------------------------------------------------------------------------
# Tile controls expose grout exactly like the page 7 master concept.
# ---------------------------------------------------------------------------
layouts_path = APP / 'lib/screens/layouts_screen.dart'
layouts = layouts_path.read_text()
layouts = replace_once(
    layouts,
    """    if (field == 'minCut')
      v = await _number(
        'Минимальная желательная подрезка',
        s.tileMinCutMm,
        'мм',
      );
""",
    """    if (field == 'grout')
      v = await _number('Ширина плиточного шва', s.floorTileGroutMm, 'мм');
    if (field == 'minCut')
      v = await _number(
        'Минимальная желательная подрезка',
        s.tileMinCutMm,
        'мм',
      );
""",
    'edit floor grout',
)
layouts = replace_once(
    layouts,
    """    if (field == 'offX') s.tileOffsetXMm = v;
    if (field == 'offY') s.tileOffsetYMm = v;
    if (field == 'minCut') s.tileMinCutMm = v;
""",
    """    if (field == 'offX') s.tileOffsetXMm = v;
    if (field == 'offY') s.tileOffsetYMm = v;
    if (field == 'grout') s.floorTileGroutMm = v.clamp(0.5, 50);
    if (field == 'minCut') s.tileMinCutMm = v;
""",
    'assign floor grout',
)
layouts = replace_once(
    layouts,
    """                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _autoBalance(face, s),
                                icon: const Icon(Icons.center_focus_strong),
                                label: const Text('Авто без узких'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _edit(s, 'minCut'),
                              child: Text('Мин. ${s.tileMinCutMm.round()}'),
                            ),
                          ],
                        ),
""",
    """                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _autoBalance(face, s),
                              icon: const Icon(Icons.center_focus_strong),
                              label: const Text('Авто без узких'),
                            ),
                            OutlinedButton(
                              onPressed: () => _edit(s, 'grout'),
                              child: Text(
                                'Шов ${s.floorTileGroutMm.toStringAsFixed(s.floorTileGroutMm % 1 == 0 ? 0 : 1)} мм',
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => _edit(s, 'minCut'),
                              child: Text('Мин. ${s.tileMinCutMm.round()}'),
                            ),
                          ],
                        ),
""",
    'tile grout control',
)
layouts_path.write_text(layouts)

# ---------------------------------------------------------------------------
# 3D gets the same shared anchor as 2D for continuous multi-room layouts.
# ---------------------------------------------------------------------------
scene_path = APP / 'lib/renderer3d/zamer_scene_geometry.dart'
scene = scene_path.read_text()
scene = replace_once(
    scene,
    """      final meta = floor.roomMetaByKey(face.key);
      final settings = meta?.materials ?? RoomMaterialSettings();
      floorSurfaces.add(
""",
    """      final meta = floor.roomMetaByKey(face.key);
      final settings = meta?.materials ?? RoomMaterialSettings();
      final sharedFloorAnchor =
          meta != null &&
          floor.carpetRoomIds.length > 1 &&
          floor.carpetRoomIds.contains(meta.id);
      floorSurfaces.add(
""",
    'shared floor anchor flag',
)
scene = replace_once(
    scene,
    """          tileOffsetXMm: settings.tileOffsetXMm,
          tileOffsetYMm: settings.tileOffsetYMm,
          anchorXMm: face.centroid.x,
          anchorYMm: face.centroid.y,
""",
    """          tileOffsetXMm: settings.tileOffsetXMm,
          tileOffsetYMm: settings.tileOffsetYMm,
          groutMm: settings.floorTileGroutMm,
          anchorXMm: sharedFloorAnchor
              ? floor.carpetAnchorX
              : face.centroid.x,
          anchorYMm: sharedFloorAnchor
              ? floor.carpetAnchorY
              : face.centroid.y,
""",
    'scene floor grout and shared anchor',
)
scene = replace_once(
    scene,
    """    required this.tileOffsetXMm,
    required this.tileOffsetYMm,
    required this.anchorXMm,
""",
    """    required this.tileOffsetXMm,
    required this.tileOffsetYMm,
    required this.groutMm,
    required this.anchorXMm,
""",
    'floor surface grout constructor',
)
scene = replace_once(
    scene,
    """  final double tileOffsetXMm, tileOffsetYMm;
  final double anchorXMm, anchorYMm;
""",
    """  final double tileOffsetXMm, tileOffsetYMm, groutMm;
  final double anchorXMm, anchorYMm;
""",
    'floor surface grout field',
)
scene_path.write_text(scene)

# ---------------------------------------------------------------------------
# GPU: fix the offset sign, include grout in rebuilds and draw real mm seams.
# ---------------------------------------------------------------------------
gpu_path = APP / 'lib/renderer3d/zamer_gpu_viewport.dart'
gpu = gpu_path.read_text()
gpu = replace_once(
    gpu,
    """import '../widgets/floor_3d_painter.dart';
import 'model_asset_catalog.dart';
""",
    """import '../widgets/floor_3d_painter.dart';
import 'floor_grout_geometry.dart';
import 'model_asset_catalog.dart';
""",
    'import floor grout geometry',
)
gpu = replace_once(
    gpu,
    """        m.tileOffsetXMm,
        m.tileOffsetYMm,
        m.laminatePlankLengthMm,
""",
    """        m.tileOffsetXMm,
        m.tileOffsetYMm,
        m.floorTileGroutMm,
        m.laminatePlankLengthMm,
""",
    'grout rebuild fingerprint',
)
start = "  Node? _buildFloorNode(\n"
end = "  PhysicallyBasedMaterial _floorMaterial(ZamerFloorSurface surface) {\n"
new_floor = r'''  Node? _buildFloorNode(
    ZamerFloorSurface surface,
    ZamerSceneBounds bounds,
    Map<String, PhysicallyBasedMaterial> materialCache,
  ) {
    if (surface.polygonMm.length < 3) return null;
    final indices = _triangulate(surface.polygonMm);
    if (indices.isEmpty) return null;

    final uvScale = _floorUvScaleMm(surface);
    final isTile =
        surface.materialMode.toLowerCase().contains('tile') ||
        MaterialCatalog.byId(surface.materialId).pattern == 'tile';
    final effectiveDirection = isTile
        ? surface.directionDeg + (surface.tilePattern == 'diagonal' ? 45 : 0)
        : surface.directionDeg;
    final angle = effectiveDirection * math.pi / 180;
    final ca = math.cos(angle), sa = math.sin(angle);
    final offX = isTile ? surface.tileOffsetXMm : surface.laminateOffsetXMm;
    final offY = isTile ? surface.tileOffsetYMm : surface.laminateOffsetYMm;
    final builder = GeometryBuilder(deduplicate: false)
      ..normal(vm.Vector3(0, 1, 0));
    for (final point in surface.polygonMm) {
      final dx = point.x - surface.anchorXMm;
      final dy = point.y - surface.anchorYMm;
      // 2D places a seam at n*module + offset. Therefore the texture-space
      // coordinate must subtract that offset. The old +offset made the GPU
      // layout move in the opposite direction from the 2D editor.
      final rx = dx * ca + dy * sa - offX;
      final ry = -dx * sa + dy * ca - offY;
      builder
        ..texCoord(vm.Vector2(rx / uvScale.$1, ry / uvScale.$2))
        ..addVertex(
          vm.Vector3(_mx(point.x, bounds), 0.006, _mz(point.y, bounds)),
        );
    }
    final floorIndices = floorFacingTriangleIndices(indices);
    for (var i = 0; i < floorIndices.length; i += 3) {
      builder.addTriangle(
        floorIndices[i],
        floorIndices[i + 1],
        floorIndices[i + 2],
      );
    }

    final key =
        '${surface.materialMode}:${surface.materialId}:${surface.laminatePattern}:${surface.laminateOffsetMode}:${surface.tilePattern}';
    final material = materialCache.putIfAbsent(
      key,
      () => _floorMaterial(surface),
    );
    final root = Node(name: 'floor-root:${surface.roomKey}');
    root.add(
      Node(
          name: 'floor:${surface.roomKey}',
          mesh: Mesh(builder.build(), material),
        )
        ..castsShadows = false
        ..shadowStatic = true,
    );
    if (isTile && surface.groutMm > 0) {
      final grout = _buildFloorGroutNode(surface, bounds, effectiveDirection);
      if (grout != null) root.add(grout);
    }
    return root;
  }

  Node? _buildFloorGroutNode(
    ZamerFloorSurface surface,
    ZamerSceneBounds bounds,
    double effectiveDirection,
  ) {
    final quads = buildFloorTileGroutQuads(
      polygonMm: surface.polygonMm,
      anchorXMm: surface.anchorXMm,
      anchorYMm: surface.anchorYMm,
      directionDeg: effectiveDirection,
      tileWidthMm: surface.tileWidthMm,
      tileHeightMm: surface.tileHeightMm,
      offsetXMm: surface.tileOffsetXMm,
      offsetYMm: surface.tileOffsetYMm,
      groutMm: surface.groutMm,
      pattern: surface.tilePattern,
    );
    if (quads.isEmpty) return null;

    final builder = GeometryBuilder(deduplicate: false)
      ..normal(vm.Vector3(0, 1, 0));
    var vertex = 0;
    for (final quad in quads) {
      if (quad.pointsMm.length != 4) continue;
      for (final point in quad.pointsMm) {
        builder
          ..texCoord(vm.Vector2.zero())
          ..addVertex(
            vm.Vector3(_mx(point.x, bounds), 0.0068, _mz(point.y, bounds)),
          );
      }
      // XY plan -> XZ scene flips handedness, so reverse the triangle order
      // to keep the physical grout face pointing upward.
      builder
        ..addTriangle(vertex, vertex + 2, vertex + 1)
        ..addTriangle(vertex, vertex + 3, vertex + 2);
      vertex += 4;
    }
    if (vertex == 0) return null;
    final material = _pbr(
      vm.Vector4(0.68, 0.69, 0.68, 1),
      roughness: 0.94,
    )..doubleSided = false;
    return Node(
        name: 'floor-grout:${surface.roomKey}',
        mesh: Mesh(builder.build(), material),
      )
      ..castsShadows = false
      ..shadowStatic = true;
  }

'''
gpu = replace_between(gpu, start, end, new_floor, 'replace gpu floor builder')
gpu_path.write_text(gpu)

# ---------------------------------------------------------------------------
# Catalogue card proportions follow page 4 of the master concept more closely.
# ---------------------------------------------------------------------------
objects_path = APP / 'lib/screens/planning_objects_screen.dart'
objects = objects_path.read_text()
objects = replace_once(objects, '                                  width: 118,\n', '                                  width: 96,\n', 'catalog sidebar width')
objects = replace_once(objects, '                                                childAspectRatio: .88,\n', '                                                childAspectRatio: .64,\n', 'catalog card aspect')
objects = replace_once(objects, '                                                          108,\n', '                                                          118,\n', 'catalog thumbnail size')
objects = replace_once(objects, '                                            ? const Color(0xFF24483D)\n', '                                            ? const Color(0xFF3B3028)\n', 'catalog selected background')
objects = replace_once(objects, '                                                            0xFF79E1B9,\n', '                                                            0xFFF1C79E,\n', 'catalog selected text')
objects = replace_once(objects, '                                                            0xFF56D6A3,\n', '                                                            0xFFF1C79E,\n', 'catalog selected border')
objects_path.write_text(objects)

# ---------------------------------------------------------------------------
# Version + changelog.
# ---------------------------------------------------------------------------
pubspec_path.write_text(pubspec.replace('version: 1.5.6+53', 'version: 1.5.6+54', 1))

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = """## 1.5.6+54 — Visual Foundation

- Мастер-концепт ZAMER 01–10 принят как визуальный стандарт: базовая тема переведена на тёплый песочный акцент, более плотные тёмные поверхности, единые радиусы и контраст.
- Оснащение: GLB-превью автоматически кадрируются по реальным bounds модели; низкая мебель больше не превращается в узкую полоску сверху карточки. Карточки каталога стали выше, а боковая категория уже — ближе к странице 4 мастер-концепта.
- Пол: исправлен знак X/Y-смещения в GPU, поэтому фазовый сдвиг раскладки теперь совпадает с 2D-редактором.
- Единый ковёр: 3D использует тот же общий anchor, что и 2D, вместо отдельного центра каждой комнаты.
- Напольная плитка: добавлен отдельный параметр `floorTileGroutMm`, сохраняемый в проекте и копируемый между помещениями единой раскладки.
- Плиточный шов в 3D строится отдельной геометрией реальной ширины в миллиметрах, включая прямую, диагональную раскладку и 1/2.
- В 2D ширина шва также зависит от настроенного миллиметрового значения; на экране раскладки добавлена явная настройка «Шов».
- Добавлены тесты физической ширины шва и смещения вертикальных швов для схемы 1/2.

"""
if not changelog.startswith('## 1.5.6+54'):
    changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+54 visual foundation patch')
