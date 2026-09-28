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

## Texture targets

- Default: 2048x2048 maximum per primary material set
- Hero/detail assets: 4096x4096 only when visible quality justifies memory cost
- Prefer BaseColor, Normal, Roughness, Metallic and AO where applicable

## Placement types

- `floor`
- `wall`
- `ceiling`
- `opening`
- `free`

## Planned automation

The pipeline is designed so Blender can run headlessly on a remote runner. Generation and post-processing providers can change without changing the asset contract used by the app.
