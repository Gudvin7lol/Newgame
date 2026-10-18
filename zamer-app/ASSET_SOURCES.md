# Zamer external 3D asset sources

Furniture assets must have explicit commercial-use and redistribution rights.

## +132 deterministic build fallback

By default, CI uses 3D meshes generated from the repository's own featured-model source scripts. These are not labelled or presented as vendor CC0 assets. For compatibility, the `bed-160` GLB and its two LODs temporarily reuse the generated `bed-180` geometry, with the GLB bounds normalized to the `bed-160` catalogue's dimensions for each LOD. The generated `bed-180` and `sofa-3` preserve their own LOD meshes and matching top-view previews.

External CC0 models are optional: set `ZAMER_USE_REMOTE_CC0=1` in a build environment. Only when both external downloads succeed are the generated meshes replaced. If the CDN is unreachable, CI keeps the local models and can still build the APK. This avoids broken builds without misrepresenting asset origin.

## +126 CI-fetched CC0 assets (opt-in for +132)

| Zamer ID | Source | Licence | Notes |
| --- | --- | --- | --- |
| `bed-160` | 3DAssets.dev asset 25738 | CC0 1.0 Universal | Upholstered bed, headboard, duvet, four pillows, bolster and runner |
| `bed-180` | Same geometry as `bed-160`, normalized to catalogue size at runtime | CC0 1.0 Universal | Temporary 180 cm variant |
| `sofa-3` | 3DAssets.dev asset 25866 | CC0 1.0 Universal | Three-seat upholstered lobby sofa |

Source pages:
- https://3dassets.dev/assets/hotel-and-resort-operations-bed-king-upholstered-819ff50d
- https://3dassets.dev/assets/hotel-and-resort-operations-lobby-sofa-79174bf1

## Integration rules

- The live renderer scales vendor GLBs from their actual imported bounds.
- +Y remains the world-up axis in Zamer.
- LOD0/1/2 paths are populated for these first CC0 assets so every graphics mode uses the same verified geometry.
- These models validate the external-asset pipeline. They are not the final Photo-quality ceiling.
- Do not ship assets whose redistribution rights are unclear.
