import 'package:flutter/material.dart';

import '../services/generated_pbr_finish_catalog.dart';
import '../services/material_catalog.dart';

/// Compact material preview used by finish pickers.
///
/// Textured presets show their actual base-color asset rather than a flat
/// fallback color. Generated PBR finishes also get a small visual marker so
/// users can distinguish the richer material pack without exposing renderer
/// implementation details in the picker copy.
class MaterialFinishSwatch extends StatelessWidget {
  const MaterialFinishSwatch({
    super.key,
    required this.material,
    this.size = 24,
    this.borderRadius = 6,
  });

  final VisualMaterialPreset material;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final pbr = GeneratedPbrFinishCatalog.byId(material.id);
    final texture = material.textureAsset;

    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (texture == null)
              ColoredBox(color: material.color)
            else
              Image.asset(
                texture,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => ColoredBox(color: material.color),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x33000000)),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            if (pbr != null)
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: size * 0.34,
                  height: size * 0.34,
                  margin: EdgeInsets.all(size * 0.07),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MaterialPbrSummary extends StatelessWidget {
  const MaterialPbrSummary({
    super.key,
    required this.material,
    this.compact = false,
  });

  final VisualMaterialPreset material;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pbr = GeneratedPbrFinishCatalog.byId(material.id);
    if (pbr == null) return const SizedBox.shrink();

    final repeat = pbr.realWorldTileMm >= 1000
        ? '${(pbr.realWorldTileMm / 1000).toStringAsFixed(pbr.realWorldTileMm % 1000 == 0 ? 0 : 1)} м'
        : '${pbr.realWorldTileMm.toStringAsFixed(0)} мм';
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.layers_outlined,
          size: compact ? 13 : 15,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            compact ? 'PBR · $repeat' : 'PBR · рельеф · масштаб $repeat',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
