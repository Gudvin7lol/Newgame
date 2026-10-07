# Zamer external 3D asset sources

The final furniture library must use assets whose redistribution and commercial-use rights are explicit.

## Current CI-fetched CC0 assets

| Zamer ID | Source | Licence | Notes |
| --- | --- | --- | --- |
| `bed-160` | 3DAssets.dev — King bed with upholstered headboard, asset 25738 | CC0 1.0 Universal | Piped divan, crowned mattress, duvet, four pillows, bolster, foot runner and upholstered headboard |
| `bed-180` | Same source as `bed-160`, normalized by the renderer to the catalogue size | CC0 1.0 Universal | Temporary shared geometry until a separate 180 cm hero asset is approved |
| `sofa-3` | 3DAssets.dev — Lobby sofa, asset 25866 | CC0 1.0 Universal | Three piped seat cushions, three welted back pads, bolster arms |

Source pages:
- https://3dassets.dev/assets/hotel-and-resort-operations-bed-king-upholstered-819ff50d
- https://3dassets.dev/assets/hotel-and-resort-operations-lobby-sofa-79174bf1

## Quality policy

These CC0 models prove the external-asset pipeline and replace the old procedural placeholders. They are not the final Photo benchmark.

Target for approved hero furniture:
- correct real-world scale and +Y up;
- clean UVs;
- PBR BaseColor / Normal / Roughness / AO, Metallic where relevant;
- LOD0 for Photo, LOD1 for Quality, LOD2 for Performance;
- soft furniture must have believable seams, piping, folds and cushion deformation;
- the renderer must normalize vendor geometry from its actual imported bounds rather than trusting filename metadata.

Do not ship assets with unclear redistribution rights.
