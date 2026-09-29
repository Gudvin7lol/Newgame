# Zamer 3D Asset Pipeline

This directory defines the production pipeline for 3D assets used by Zamer.

## Goal

Convert generated or sourced 3D objects into predictable mobile-ready GLB assets without requiring a local Blender installation.

## Pipeline

1. Reference image(s) or text description
2. Image-to-3D / text-to-3D generation
3. Mesh cleanup and repair
4. Scale normalization to real-world dimensions
5. Pivot/origin normalization
6. UV and PBR material validation
7. Triangle-budget optimization
8. Collision proxy generation
9. GLB export
10. Metadata generation
11. Validation before committing to `assets/models`

## Zamer asset rules

- Runtime format: GLB / glTF 2.0
- Real-world scale: metres in the GLB scene
- Up axis: Y-up at runtime boundary
- Pivot: floor-centred unless the placement type requires wall/ceiling anchoring
- Embedded or explicitly packaged PBR textures
- No missing external texture references
- No negative or unapplied transforms in the final export
- Collision geometry should be simpler than render geometry
- Asset metadata must conform to `asset_spec.schema.json`

## Recommended triangle budgets

- Small props: 2k-15k triangles
- Furniture: 10k-40k triangles
- Large hero objects: up to 60k triangles when justified
- LOD1 target: about 50% of LOD0
- LOD2 target: about 20-25% of LOD0

## Production texture profiles

The current production furniture set uses embedded textures so Android does not depend on external texture files at runtime.

- LOD0: 512px BaseColor + Normal + Metallic/Roughness maps
- LOD1: 256px BaseColor + Normal + Metallic/Roughness maps
- LOD2: 128px BaseColor only; roughness and metallic remain scalar PBR values
- LOD2 intentionally drops tangent-space detail maps because it is selected for the heaviest/distant mobile scenes, where those maps cost memory but contribute little visible detail
- `bake_production_pbr.py` is repeat-safe: when an asset is already textured, it recovers the source colour from the embedded BaseColor map rather than rebaking from a white PBR factor
- Every bake verifies that triangle counts and model bounds are unchanged before the GLB is accepted
- `validate_asset.dart` verifies the resulting GLB/LOD metadata before the workflow commits binary assets

## Runtime LOD policy

Production models expose LOD0, LOD1 and LOD2 to the GPU viewport.

- Orbit view: LOD0 below 10 visible objects, LOD1 from 10 to 27, LOD2 from 28
- Walk mode: LOD1 by default, LOD2 from 18 visible objects
- Photo/HD/2K/4K export always rebuilds the model scene with LOD0 before rendering
- After photo export, the viewport returns to its adaptive interactive LOD
- Legacy catalogue assets without a complete LOD chain safely fall back to their base GLB

## Texture targets for future hero assets

The production mobile profiles above are deliberately conservative. Curated hero assets may use larger material sets where the visual gain justifies memory and APK size.

- Default curated material source: up to 2048x2048
- Hero/detail source: up to 4096x4096 only when visible quality justifies memory cost
- Prefer BaseColor, Normal, Roughness, Metallic and AO where applicable
- Downsample or repack those source maps into the runtime LOD profiles during the asset build

## Placement types

- `floor`
- `wall`
- `ceiling`
- `opening`
- `free`

## Automation

Generation, GLB validation and PBR baking run on GitHub Actions. The pipeline is designed so Blender can also run headlessly on a remote runner when later assets require operations that Trimesh cannot provide. Generation and post-processing providers can change without changing the asset contract used by the app.
