import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lazy cache for the approved raster top-view pack.
///
/// The CAD renderer keeps deterministic vector symbols underneath these
/// images, so a missing optional preview never makes an object disappear.
class ImportedTopViewAssets extends ChangeNotifier {
  ImportedTopViewAssets._();

  static final ImportedTopViewAssets instance = ImportedTopViewAssets._();

  static const _root = 'assets/topview/imported_2026_10_02';
  static const _assetByCatalogId = <String, String>{
    'sofa-3': 'sofa_2400x950',
    'bed-180': 'bed_1800x2200',
    'armchair': 'armchair_900x900',
    'table-round': 'table_round_900',
    'dining-table-1800': 'dining_table_1600x1300',
    'dining-table-6': 'dining_table_1600x1300',
    'wardrobe-sliding-2000': 'wardrobe_1800x600',
    'wardrobe-3': 'wardrobe_1800x600',
    'toilet': 'toilet_380x650',
    'sink': 'sink_600x500',
    'bath': 'bath_1700x700',
    'shower': 'shower_900x900',
    'radiator': 'radiator_1000x120',
    'radiator-600': 'radiator_1000x120',

    // +107 kitchen views are rendered from the exact same HQ geometry that is
    // copied into the 3D catalogue, so 2D and 3D can no longer silently drift.
    'kitchen-drawers-600': 'kitchen_drawers',
    'kitchen-sink-600-pro': 'kitchen_sink',
    'kitchen-cooktop-600': 'kitchen_cooktop',
    'kitchen-corner-900': 'kitchen_corner',
    'kitchen-pantry-600': 'kitchen_pantry',
    'fridge-built-in-610': 'kitchen_fridge',
  };

  final Map<String, ui.Image> _images = <String, ui.Image>{};
  Future<void>? _loadFuture;

  ui.Image? imageForCatalog(String catalogId) => _images[catalogId];

  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    var loadedAny = false;
    for (final entry in _assetByCatalogId.entries) {
      try {
        final data = await rootBundle.load('$_root/${entry.value}.webp');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final codec = await ui.instantiateImageCodec(bytes);
        try {
          final frame = await codec.getNextFrame();
          _images[entry.key] = frame.image;
          loadedAny = true;
        } finally {
          codec.dispose();
        }
      } catch (_) {
        // Keep the vector fallback visible when an optional raster fails.
      }
    }
    if (loadedAny) notifyListeners();
  }
}
