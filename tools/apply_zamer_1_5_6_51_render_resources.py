from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'zamer-app'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    return text.replace(old, new, 1)


pubspec_path = APP / 'pubspec.yaml'
pubspec = pubspec_path.read_text()
if 'version: 1.5.6+51' in pubspec:
    print('1.5.6+51 render-resource patch already applied')
    raise SystemExit(0)
if 'version: 1.5.6+50' not in pubspec:
    raise SystemExit('unexpected app version; refusing automatic +51 patch')

# Keep only the model-template LODs used by the current scene. Photo exports
# temporarily use LOD0; restoring interactive mode then drops those heavy
# templates so repeated 4K renders do not accumulate every LOD in memory.
renderer_path = APP / 'lib/renderer3d/zamer_gpu_viewport.dart'
renderer = renderer_path.read_text()
renderer = replace_once(
    renderer,
    "    final floorMaterialCache = <String, PhysicallyBasedMaterial>{};\n",
    "    final floorMaterialCache = <String, PhysicallyBasedMaterial>{};\n    final activeModelPaths = <String>{};\n",
    'renderer active model path set',
)
renderer = replace_once(
    renderer,
    "        visibleObjectCount: geometry.objects.length,\n        photoQuality: photoQuality,\n      );",
    "        visibleObjectCount: geometry.objects.length,\n        photoQuality: photoQuality,\n        activeModelPaths: activeModelPaths,\n      );",
    'renderer pass active model paths',
)
renderer = replace_once(
    renderer,
    "    if (!mounted || generation != _buildGeneration) return;\n    setState(() => _ready = true);",
    "    if (!mounted || generation != _buildGeneration) return;\n    // Templates are only construction caches. Scene clones already own the\n    // nodes they need, so retaining inactive LODs after a rebuild wastes GPU\n    // and Dart memory. This is especially important after a true 4K export,\n    // which temporarily forces every production asset to full LOD0.\n    _modelTemplates.removeWhere((path, _) => !activeModelPaths.contains(path));\n    setState(() => _ready = true);",
    'renderer prune inactive model templates',
)
renderer = replace_once(
    renderer,
    "    required int visibleObjectCount,\n    bool photoQuality = false,\n  }) async {",
    "    required int visibleObjectCount,\n    bool photoQuality = false,\n    required Set<String> activeModelPaths,\n  }) async {",
    'renderer object builder active paths argument',
)
renderer = replace_once(
    renderer,
    "        final modelPath = ZamerModelLodPolicy.pathFor(\n          asset: asset,\n          visibleObjectCount: visibleObjectCount,\n          photoQuality: photoQuality,\n          walkMode: widget.walkMode,\n        );\n        final template = _modelTemplates[modelPath] ??= await Node.fromGlbAsset(\n",
    "        final modelPath = ZamerModelLodPolicy.pathFor(\n          asset: asset,\n          visibleObjectCount: visibleObjectCount,\n          photoQuality: photoQuality,\n          walkMode: widget.walkMode,\n        );\n        activeModelPaths.add(modelPath);\n        final template = _modelTemplates[modelPath] ??= await Node.fromGlbAsset(\n",
    'renderer track selected model path',
)
renderer_path.write_text(renderer)

# Curved walls are tessellated into many short pieces. Keep one continuous wall
# coordinate across those pieces so tile/brick UVs do not restart every 90 mm.
geometry_path = APP / 'lib/renderer3d/zamer_scene_geometry.dart'
geometry = geometry_path.read_text()
geometry = replace_once(
    geometry,
    "          final sample = groupWalls.isEmpty ? wall : groupWalls.first;\n          final height = sample.heightOverrideMm ?? floor.defaultHeightMm;\n          for (var i = 0; i < points.length - 1; i++) {",
    "          final sample = groupWalls.isEmpty ? wall : groupWalls.first;\n          final height = sample.heightOverrideMm ?? floor.defaultHeightMm;\n          var textureCursorMm = 0.0;\n          for (var i = 0; i < points.length - 1; i++) {",
    'curve texture cursor',
)
geometry = replace_once(
    geometry,
    "                bottomMm: 0,\n                heightMm: height,\n                materialId: finish.wallMaterialId,",
    "                bottomMm: 0,\n                heightMm: height,\n                textureStartMm: textureCursorMm,\n                materialId: finish.wallMaterialId,",
    'curve texture start',
)
geometry = replace_once(
    geometry,
    "              ),\n            );\n          }\n        }\n        continue;",
    "              ),\n            );\n            textureCursorMm += len;\n          }\n        }\n        continue;",
    'curve texture cursor advance',
)
geometry_path.write_text(geometry)

# Catalogue thumbnails: serialize tiny offscreen GPU renders and give them a
# deterministic neutral light rig. Six simultaneous Scene renders in a grid are
# unnecessary contention on mid-range Android GPUs.
thumbnail_path = APP / 'lib/widgets/model_thumbnail.dart'
thumbnail = thumbnail_path.read_text()
thumbnail = replace_once(
    thumbnail,
    "import 'dart:typed_data';\n",
    "import 'dart:async';\nimport 'dart:typed_data';\n",
    'thumbnail async import',
)
thumbnail = replace_once(
    thumbnail,
    "  static final Map<String, Future<Uint8List?>> _cache =\n      <String, Future<Uint8List?>>{};\n\n  static Future<Uint8List?> _render(String catalogId) async {",
    "  static final Map<String, Future<Uint8List?>> _cache =\n      <String, Future<Uint8List?>>{};\n  static Future<void> _renderQueue = Future<void>.value();\n\n  static Future<Uint8List?> _enqueueRender(String catalogId) {\n    final result = Completer<Uint8List?>();\n    _renderQueue = _renderQueue.then((_) async {\n      result.complete(await _render(catalogId));\n    });\n    return result.future;\n  }\n\n  static Future<Uint8List?> _render(String catalogId) async {",
    'thumbnail serial render queue',
)
thumbnail = replace_once(
    thumbnail,
    "      final scene = Scene();\n      final model = await Node.fromGlbAsset(\n",
    "      final scene = Scene();\n      scene.environmentSettings = EnvironmentSettings(\n        toneMapping: ToneMappingMode.pbrNeutral,\n        environmentIntensity: 0.92,\n        exposure: 1.0,\n        ambientOcclusionEnabled: false,\n        screenSpaceReflectionsEnabled: false,\n        bloomEnabled: false,\n        vignetteEnabled: false,\n        autoExposureEnabled: false,\n      );\n      scene.antiAliasingMode = AntiAliasingMode.auto;\n      scene.environmentIntensity = 0.92;\n      scene.directionalLight = DirectionalLight(\n        direction: vm.Vector3(-0.45, -1.0, -0.35)..normalize(),\n        color: vm.Vector3(1.0, 0.97, 0.92),\n        intensity: 2.35,\n        castsShadow: false,\n        cacheStaticShadows: false,\n        shadowMapResolution: 256,\n        shadowMaxDistance: 10,\n        shadowSoftness: 0.16,\n      );\n      final model = await Node.fromGlbAsset(\n",
    'thumbnail light rig',
)
thumbnail = replace_once(
    thumbnail,
    "    final future = _cache.putIfAbsent(catalogId, () => _render(catalogId));",
    "    final future = _cache.putIfAbsent(\n      catalogId,\n      () => _enqueueRender(catalogId),\n    );",
    'thumbnail queued cache',
)
thumbnail_path.write_text(thumbnail)

# Regression test: the wall-space texture coordinate must advance monotonically
# along a curved group rather than restarting at zero for each tessellated part.
geometry_test_path = APP / 'test/zamer_scene_geometry_test.dart'
geometry_test = geometry_test_path.read_text()
geometry_test = replace_once(
    geometry_test,
    "import 'package:zamer_app/renderer3d/zamer_scene_geometry.dart';\n",
    "import 'package:zamer_app/renderer3d/zamer_scene_geometry.dart';\nimport 'package:zamer_app/services/geometry_service.dart';\n",
    'geometry test service import',
)
curve_test = r'''

  test('curved wall pieces preserve one continuous texture phase', () {
    final floor = FloorPlan(id: 'arc-uv', name: 'Arc UV')
      ..nodes.add(PlanNode(id: 'a', xMm: 0, yMm: 0));
    GeometryService.addArcWallFromNode(
      floor,
      startNodeId: 'a',
      endPoint: const math.Point<double>(4000, 0),
      sagittaMm: 900,
      type: WallType.exterior,
      thicknessMm: 200,
      material: WallMaterial.gasBlock,
    );

    final scene = ZamerSceneGeometry.fromFloor(floor);
    final pieces = scene.walls;
    expect(pieces.length, greaterThan(4));
    expect(pieces.first.textureStartMm, closeTo(0, 0.001));
    for (var i = 1; i < pieces.length; i++) {
      final previousPhysicalLength = pieces[i - 1].lengthMm - 2;
      expect(
        pieces[i].textureStartMm,
        closeTo(
          pieces[i - 1].textureStartMm + previousPhysicalLength,
          0.5,
        ),
      );
    }
  });
'''
if curve_test.strip() not in geometry_test:
    if not geometry_test.endswith('\n}\n'):
        raise SystemExit('geometry test file has unexpected ending')
    geometry_test = geometry_test[:-3] + curve_test + '}\n'
geometry_test_path.write_text(geometry_test)

# Regression coverage for the LOD policy used by cache pruning and final render.
lod_test_path = APP / 'test/model_lod_policy_test.dart'
lod_test_path.write_text(r'''import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/model_asset_catalog.dart';
import 'package:zamer_app/renderer3d/model_lod_policy.dart';

void main() {
  test('photo render uses LOD0 while dense interactive scenes use lower LODs', () {
    final asset = ZamerModelAssetCatalog.byId('armchair');
    expect(asset, isNotNull);
    final model = asset!;
    expect(model.hasCompleteLodChain, isTrue);

    expect(
      ZamerModelLodPolicy.pathFor(
        asset: model,
        visibleObjectCount: 40,
        photoQuality: true,
        walkMode: false,
      ),
      model.assetPath,
    );
    expect(
      ZamerModelLodPolicy.pathFor(
        asset: model,
        visibleObjectCount: 40,
        photoQuality: false,
        walkMode: false,
      ),
      model.lod2AssetPath,
    );
    expect(
      ZamerModelLodPolicy.pathFor(
        asset: model,
        visibleObjectCount: 12,
        photoQuality: false,
        walkMode: false,
      ),
      model.lod1AssetPath,
    );
  });
}
''')

# Version and changelog.
pubspec_path.write_text(pubspec.replace('version: 1.5.6+50', 'version: 1.5.6+51', 1))
changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = '''## 1.5.6+51

- Кэш GLB-шаблонов теперь ограничен LOD-уровнями, которые реально использует текущая сцена. После финального HD/2K/4K кадра временные тяжёлые LOD0 освобождаются при возврате в интерактивный режим, поэтому серия рендеров не накапливает лишние модели в памяти.
- Радиусные стены получили непрерывную координату UV по длине дуги: плитка и другие повторяемые материалы больше не начинают рисунок заново на каждом коротком сегменте аппроксимации.
- Реальные GLB-превью в каталоге оснащения рендерятся последовательно, а не пачкой одновременно, и получают нейтральный PBR-свет. Это снижает пиковую нагрузку на GPU и делает миниатюры читаемыми вместо тёмных силуэтов.
- Добавлены регрессионные тесты непрерывной фазы материала на радиусной стене и выбора LOD для интерактивной/финальной сцены.

'''
changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+51 render resource patch')
