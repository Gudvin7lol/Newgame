from pathlib import Path

root = Path(__file__).resolve().parents[1]
viewport_path = root / 'lib/renderer3d/zamer_gpu_viewport.dart'
pubspec_path = root / 'pubspec.yaml'

source = viewport_path.read_text(encoding='utf-8')

import_anchor = "import 'model_lod_policy.dart';\n"
visibility_import = "import 'model_visibility_policy.dart';\n"
if visibility_import not in source:
    if import_anchor not in source:
        raise SystemExit('model visibility import anchor not found')
    source = source.replace(import_anchor, import_anchor + visibility_import, 1)

root_anchor = """    final asset = ZamerModelAssetCatalog.byId(object.catalogId);\n    final root = Node(name: 'object:${object.id}:${object.catalogId}');\n    var importedModel = false;\n"""
root_replacement = """    final asset = ZamerModelAssetCatalog.byId(object.catalogId);\n    final root = Node(name: 'object:${object.id}:${object.catalogId}')\n      ..frustumCulled = ZamerModelVisibilityPolicy.frustumCulled(\n        performanceMode: widget.performanceMode,\n        photoQuality: photoQuality,\n        visibleObjectCount: visibleObjectCount,\n      );\n    var importedModel = false;\n"""
if root_replacement not in source:
    if root_anchor not in source:
        raise SystemExit('object root anchor not found')
    source = source.replace(root_anchor, root_replacement, 1)

model_anchor = """        if (localBounds != null) {\n          // Every plan object uses its footprint centre as the X/Y anchor.\n"""
# Keep the existing block intact; explicitly invalidate the model bounds after
# authored transforms are applied and before it becomes part of the object root.
add_anchor = """        }\n        root.add(model);\n      } catch (_) {\n"""
add_replacement = """        }\n        model.markBoundsDirty();\n        root.add(model);\n      } catch (_) {\n"""
if add_replacement not in source:
    if add_anchor not in source:
        raise SystemExit('model add anchor not found')
    source = source.replace(add_anchor, add_replacement, 1)

return_anchor = """    _markStatic(root);\n    return root;\n  }\n\n  void _attachLightEmitter(\n"""
return_replacement = """    _markStatic(root);\n    // Light emitters and imported GLB transforms are attached after the root is\n    // created. Refresh the subtree bounds once so the renderer never reuses a\n    // stale box when frustum culling is enabled for dense/performance scenes.\n    root.markBoundsDirty();\n    return root;\n  }\n\n  void _attachLightEmitter(\n"""
if return_replacement not in source:
    if return_anchor not in source:
        raise SystemExit('object return anchor not found')
    source = source.replace(return_anchor, return_replacement, 1)

viewport_path.write_text(source, encoding='utf-8')

pubspec = pubspec_path.read_text(encoding='utf-8')
old_version = 'version: 1.5.6+113'
new_version = 'version: 1.5.6+114'
if new_version not in pubspec:
    if old_version not in pubspec:
        raise SystemExit('expected +113 pubspec version not found')
    pubspec = pubspec.replace(old_version, new_version, 1)
    pubspec_path.write_text(pubspec, encoding='utf-8')

print('Applied Zamer 1.5.6+114 model visibility stability integration.')
