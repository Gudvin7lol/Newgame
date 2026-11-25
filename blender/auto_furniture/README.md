# Autonomous Furniture Lab (technical prototype)

**Goal:** make reproducible, inspectable GLB furniture assets on GitHub Actions without owning a PC. The system does **not** train ChatGPT weights or prove that an asset looks photorealistic. It can iterate numeric material parameters, generate actual 3D assets, validate PBR data and lighting, and preserve its best technical settings between runs.

## Implemented, unattended CPU pipeline

Workflow: `.github/workflows/auto-furniture.yml`, running on branch `feat/blender-furniture-lab`.

1. Download licensed **CC0 Rough Linen** scan from Poly Haven with `scan_fabric_v13.py`.
2. Use `controller.py plan` to plan three variants around previous best values (UV scale, normal intensity).
3. Use **real Blender Cloth** mesh from `build_candidate.py`, not AI image stand-ins. Shape generator now varies a gently asymmetrical cutline, reduced foam dome height, side band compression and millimetre-scale seam folds. Cloth top perimeter is pinned, **not physically sewn with sewing springs**.
4. Export real `.blend` editable scene, textured `.glb`, and two Cycles camera angles.
5. Parse the GLB and require actual base-color, normal and metallic-roughness texture links and UVs.
6. Check image clipping/contrast and source texture variability, then choose **technical baseline**. Margins smaller than 1.5 points are treated as inconclusive and the reference candidate is retained. This is a proxy, not an aesthetic judgement.
7. Upload comparison PNG, best GLB, best BLEND, objective QA report and settings state as GitHub Actions artifacts.
8. Carry best settings to later workflows through GitHub Actions Cache.

This workflow can run on pushes to the lab branch, and after merge to `main` also runs weekly on Monday. GitHub scheduler only fires from the default branch, so schedule does not currently run for this branch.

## Manual inspection required for photorealism

Machine-checked: GLB validity, PBR wiring, model mesh presence, PNG integrity, render clipping and contrast.

Not yet solved automatically: real sewing constraints, seat-foam compression, UV seam distortion, accurate real-world material scanning scale, visually correct wrinkles, viewer-specific shading, subjective realism. **A technically valid model can still look like plastic.**

Always inspect the `best_furniture.glb` on the actual Android GLB Viewer before publishing in ZAMER.

## Future remote-GPU lane

StableGen 0.4.0 is already compatible with cloud Blender 4.5.15 LTS, but PBR inference is **not configured**. To enable unsupervised neural texture creation, a user-controlled GPU/ComfyUI endpoint and credentials must be connected securely. ComfyUI workflows require compatible custom nodes, model downloads, VRAM, storage and applicable model licensing. Never place API tokens in GitHub source or ChatGPT messages.

The remote GPU should send generated images/maps to the same Blender-side validator used in the CPU pipeline. No cloud GPU spending is initiated by the current workflow. This is an outstanding integration, not a finished feature.

## Developing further

The best baseline stays in Actions Cache. Objective scores are technical proxies and may be gamed by artificial sharpening, so they are constrained. For meaningful aesthetic progress, compare multiple angles against photographic references, collect human/vision-model review, revise geometry/material priors, and reject models failing mobile verification. An AI reviewer and editable sewing-pattern solver are planned but not yet implemented.

Existing model generation code: `blender/cushion_scan_v14.py` and `blender/auto_furniture/build_candidate.py`.

## Verified geometry run, 2026-11-01

[Autonomous Furniture Lab successful run #7](https://github.com/Gudvin7lol/Newgame/actions/runs/41309521377) built three softness settings 0.72/1.00/1.28, checked closed shell with zero nonmanifold edges, and exported mapped GLBs. Seam relief is 3.30/4.58/5.86 mm, cloth relaxation 8.88-10.36 mm depending on setting. Automated technical scores 88.71/88.72/88.74 are visually too close; baseline retained at 1.00 rather than claiming that 0.02-point gain is learning. Model still visually too regular and is **not** considered photorealistic.
