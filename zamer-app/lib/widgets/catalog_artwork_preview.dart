import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../services/imported_top_view_assets.dart';
import '../services/object_catalog.dart';
import '../models/models.dart';
import 'top_view_object_renderer.dart';

/// One production 2D artwork preview, used by the equipment catalogue.
///
/// Uses the same decoded 2D assets as CAD: curated #131 atlas first, then
/// generated GLB top-views, then approved #130 atlas. Only missing artwork
/// falls back to the more expensive 3D snapshot renderer. This prevents the
/// grid from showing dozens of identical blank placeholder icons.
class ZamerCatalogArtwork extends StatefulWidget {
  const ZamerCatalogArtwork({
    super.key,
    required this.catalogId,
    required this.fallback,
    this.loadingFallback,
  });

  final String catalogId;
  final Widget fallback;
  /// Lightweight CAD silhouette shown immediately while the atlas loads.
  /// This does not enqueue one GPU scene renderer per visible catalogue cell.
  final Widget? loadingFallback;

  @override
  State<ZamerCatalogArtwork> createState() => _ZamerCatalogArtworkState();
}

class _ZamerCatalogArtworkState extends State<ZamerCatalogArtwork> {
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    // Safe to call from hundreds of cards: ensureLoaded coalesces to one
    // asynchronous decode shared with the plan renderer.
    ImportedTopViewAssets.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _resolved = true);
    }).catchError((Object _) {
      if (mounted) setState(() => _resolved = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final assets = ImportedTopViewAssets.instance;
    return AnimatedBuilder(
      animation: assets,
      builder: (context, _) {
        ui.Image? image;
        ui.Rect? source;
        final rect131 = assets.curated131RectForCatalog(widget.catalogId);
        if (rect131 != null && assets.curated131Atlas != null) {
          image = assets.curated131Atlas;
          source = rect131;
        } else {
          image = assets.imageForCatalog(widget.catalogId);
          if (image == null) {
            final rect130 = assets.approvedRectForCatalog(widget.catalogId);
            if (rect130 != null && assets.approvedAtlas != null) {
              image = assets.approvedAtlas;
              source = rect130;
            }
          }
        }
        if (image != null) {
          return CustomPaint(
            key: ValueKey('catalog-artwork-${widget.catalogId}'),
            painter: _CatalogArtworkPainter(image: image, crop: source),
            child: const SizedBox.expand(),
          );
        }
        // While the shared atlas decodes, don't queue costly GLB render jobs.
        return _resolved
            ? widget.fallback
            : (widget.loadingFallback ?? widget.fallback);
      },
    );
  }
}

class _CatalogArtworkPainter extends CustomPainter {
  const _CatalogArtworkPainter({required this.image, this.crop});

  final ui.Image image;
  final ui.Rect? crop;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final source = crop ??
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    if (source.width <= 0 || source.height <= 0) return;
    final available = Size(math.max(1, size.width - 14),
        math.max(1, size.height - 14));
    final ratio = math.min(available.width / source.width,
        available.height / source.height);
    final output = Size(source.width * ratio, source.height * ratio);
    final target = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: output.width,
      height: output.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(9)),
      Paint()..color = ZamerColors.surfaceHigh,
    );
    canvas.drawImageRect(image, source, target,
      Paint()..filterQuality = FilterQuality.high
             ..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant _CatalogArtworkPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.crop != crop;
}

/// Deterministic 2D preview whenever optional GLB/atlas artwork is missing.
/// Unlike a generic chair icon, the preview retains the real model footprint,
/// catalogue identity and recognisable top-view shape.
class ZamerCatalogVectorFallback extends StatelessWidget {
  const ZamerCatalogVectorFallback({super.key, required this.item});

  final ObjectCatalogItem item;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CatalogVectorPainter(item),
    child: const SizedBox.expand(),
  );
}

class _CatalogVectorPainter extends CustomPainter {
  const _CatalogVectorPainter(this.item);
  final ObjectCatalogItem item;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size,
        const Radius.circular(9)),
      Paint()..color = ZamerColors.surfaceHigh,
    );
    final usableSide = math.max(1.0, math.min(size.width, size.height) - 18);
    final object = PlanObject(
      id: 'catalog-preview',
      catalogId: item.id,
      type: item.type,
      xMm: 0, yMm: 0,
      widthMm: item.widthMm,
      depthMm: item.depthMm,
      heightMm: item.heightMm,
    );
    final mmToPx = usableSide /
      math.max(1.0, math.max(item.widthMm, item.depthMm));
    TopViewObjectRenderer.draw(
      canvas, object, center: size.center(Offset.zero), mmToPx: mmToPx);
  }

  @override
  bool shouldRepaint(covariant _CatalogVectorPainter old) =>
      old.item.id != item.id ||
      old.item.widthMm != item.widthMm ||
      old.item.depthMm != item.depthMm;
}
