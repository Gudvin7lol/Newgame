import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lazy cache for raster top-view assets generated from production geometry.
///
/// The CAD renderer keeps deterministic vector symbols underneath these
/// images, so a missing optional preview never makes an object disappear.
class ImportedTopViewAssets extends ChangeNotifier {
  ImportedTopViewAssets._();

  static final ImportedTopViewAssets instance = ImportedTopViewAssets._();

  static const _root = 'assets/topview/imported_2026_10_02';
  static const _assetByCatalogId = <String, String>{
    // +107: these views are rendered from the same LOD0 GLBs used in 3D.
    'sofa-3': 'featured_sofa_3',
    // +126 uses the same licensed model geometry for both sizes.
    'bed-160': 'featured_bed_180',
    'bed-180': 'featured_bed_180',
    'armchair': 'featured_armchair',
    'coffee-table': 'featured_coffee_table',
    'tv-console-1600': 'featured_tv_console',
    'wardrobe-sliding-2000': 'featured_wardrobe',
    'washer': 'featured_washer',
    'toilet': 'featured_toilet',
    'chandelier-ring': 'featured_chandelier',
    'rug-2000x1400': 'featured_rug',
    'wall-sconce-updown': 'featured_sconce',

    // Existing pack entries retained where no same-geometry replacement exists.
    'table-round': 'table_round_900',
    'dining-table-1800': 'dining_table_1600x1300',
    'dining-table-6': 'dining_table_1600x1300',
    'wardrobe-3': 'wardrobe_1800x600',
    'sink': 'sink_600x500',
    'bath': 'bath_1700x700',
    'shower': 'shower_900x900',
    'radiator': 'radiator_1000x120',
    'radiator-600': 'radiator_1000x120',

    // +107 kitchen views are rendered from the exact same HQ geometry that is
    // copied into the 3D catalogue, so 2D and 3D cannot silently drift.
    'kitchen-drawers-600': 'kitchen_drawers',
    'kitchen-sink-600-pro': 'kitchen_sink',
    'kitchen-cooktop-600': 'kitchen_cooktop',
    'kitchen-corner-900': 'kitchen_corner',
    'kitchen-pantry-600': 'kitchen_pantry',
    'fridge-built-in-610': 'kitchen_fridge',
  };

  final Map<String, ui.Image> _images = <String, ui.Image>{};
  ui.Image? _approvedAtlas;

  // +131: one compressed WebP atlas for all approved furniture categories.
  ui.Image? _curated131Atlas;
  static const curated131Rects = <String, ui.Rect>{
    'sofa-3': ui.Rect.fromLTRB(8, 8, 274, 107),
    'sofa-2': ui.Rect.fromLTRB(284, 8, 439, 116),
    'sofa-modular': ui.Rect.fromLTRB(449, 8, 654, 114),
    'sofa-olive': ui.Rect.fromLTRB(664, 8, 879, 108),
    'armchair': ui.Rect.fromLTRB(889, 8, 966, 98),
    'lounge-chair': ui.Rect.fromLTRB(976, 8, 1060, 99),
    'ottoman': ui.Rect.fromLTRB(1070, 8, 1127, 67),
    'ottoman-round': ui.Rect.fromLTRB(1137, 8, 1191, 63),
    'coffee-table': ui.Rect.fromLTRB(1201, 8, 1264, 92),
    'coffee-table-marble': ui.Rect.fromLTRB(8, 126, 105, 209),
    'coffee-table-oval': ui.Rect.fromLTRB(115, 126, 211, 208),
    'coffee-table-dark': ui.Rect.fromLTRB(221, 126, 308, 216),
    'table-rect': ui.Rect.fromLTRB(318, 126, 450, 203),
    'table-round': ui.Rect.fromLTRB(460, 126, 547, 214),
    'dining-table-1800': ui.Rect.fromLTRB(557, 126, 659, 227),
    'bed-160': ui.Rect.fromLTRB(669, 126, 815, 320),
    'bed-180': ui.Rect.fromLTRB(825, 126, 953, 321),
    'bed-child': ui.Rect.fromLTRB(963, 126, 1063, 321),
    'bath': ui.Rect.fromLTRB(1073, 126, 1153, 291),
    'shower': ui.Rect.fromLTRB(1163, 126, 1259, 295),
    'toilet': ui.Rect.fromLTRB(8, 331, 64, 423),
    'sink': ui.Rect.fromLTRB(74, 331, 161, 391),
    'bidet': ui.Rect.fromLTRB(171, 331, 212, 403),
    'vanity-800': ui.Rect.fromLTRB(222, 331, 312, 364),
    'basin-round': ui.Rect.fromLTRB(322, 331, 381, 397),
    'rug-2000x1400': ui.Rect.fromLTRB(391, 331, 522, 435),
    'rug-gray': ui.Rect.fromLTRB(532, 331, 670, 436),
    'rug-pattern': ui.Rect.fromLTRB(680, 331, 842, 438),
    'rug-round': ui.Rect.fromLTRB(852, 331, 960, 443),
  };

  ui.Image? get curated131Atlas => _curated131Atlas;
  ui.Rect? curated131RectForCatalog(String id) => curated131Rects[id];

  /// Physical silhouettes cropped from the transparent 640px +130 atlas.
  /// One decoder and one GPU texture are shared by the four catalog IDs.
  static const approvedRects = <String, ui.Rect>{
    'sofa-3': ui.Rect.fromLTRB(9, 94, 312, 229),
    'sofa-corner': ui.Rect.fromLTRB(326, 51, 632, 269),
    'armchair': ui.Rect.fromLTRB(6, 335, 314, 620),
    'nightstand': ui.Rect.fromLTRB(335, 342, 624, 599),
  };

  ui.Image? get approvedAtlas => _approvedAtlas;
  ui.Rect? approvedRectForCatalog(String id) => approvedRects[id];
  Future<void>? _loadFuture;

  ui.Image? imageForCatalog(String catalogId) => _images[catalogId];

  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    var loadedAny = false;

    // Load approved 2D art once. Failure never hides an object: the +130
    // atlas, production previews and vector fallbacks remain available.
    try {
      final data = await rootBundle.load('$_root/approved_131_atlas.webp');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      try {
        _curated131Atlas = (await codec.getNextFrame()).image;
        loadedAny = true;
        notifyListeners();
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // No asset pack on legacy installations: retain deterministic fallback.
    }

    try {
      final data = await rootBundle.load('$_root/approved_130_atlas.webp');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        _approvedAtlas = (await codec.getNextFrame()).image;
        loadedAny = true;
        notifyListeners();
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // An older asset pack can still use the existing raster/vector fallback.
    }
    // Some catalogue IDs intentionally share one physically identical model.
    // Decode each WebP once to avoid duplicate GPU images and wasted memory.
    final decodedByFile = <String, ui.Image>{};
    for (final entry in _assetByCatalogId.entries) {
      final cached = decodedByFile[entry.value];
      if (cached != null) {
        _images[entry.key] = cached;
        continue;
      }
      try {
        final data = await rootBundle.load('$_root/${entry.value}.webp');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final codec = await ui.instantiateImageCodec(bytes);
        try {
          final frame = await codec.getNextFrame();
          decodedByFile[entry.value] = frame.image;
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
