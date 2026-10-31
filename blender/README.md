# Blender Furniture Lab (Android → GitHub Actions → Blender)

This folder is **independent of the Flutter app**. No changes to `lib/`, Android, or release APK jobs are needed.

## First test

1. A push to `feat/blender-furniture-lab` starts the Blender workflow automatically if GitHub Actions is enabled.
2. Open **Actions → Blender furniture lab → most recent run**.
3. After a green run, open **Artifacts → blender-smoke-artifacts**.
4. Unzip the result on Android. It contains:
   - `pillow_study.blend`: editable Blender scene, including camera and lights.
   - `pillow_study.glb`: actual 3D object for GLB Viewer / ZAMER.
   - `pillow_render.png`: image rendered **by Blender Cycles**.
   - `linen_basecolor.png` and `linen_normal.png`: embedded texture sources.

The `workflow_dispatch` manual button becomes available after the workflow file is added to the default branch (`main`), per GitHub Actions rules. Until then, use the branch push run.

## Scope and limitations

The test object is intentionally simple. It verifies Blender installation, scene saving, mesh generation, textured GLB export, and Cycles rendering. It is **not** physically simulated upholstery or a professional final furniture model.

Blender is installed on the GitHub-hosted Ubuntu runner via Ubuntu packages, not on the phone. The version is printed in the run log. GitHub-hosted runners are temporary, and output is retained as a workflow artifact for 7 days.

## Run locally

```bash
sudo apt-get install blender
mkdir -p out/blender
BLENDER_OUT=out/blender blender -b -t 2 --python blender/smoke_test.py
```

## Next milestones

- Validate PBR map scale / UVs against real furniture references.
- Separate foam core and cloth shell.
- Simulate cloth pressure and seam constraints using Blender tools.
- Export high-poly and mobile LOD versions, check on Android.
