#!/usr/bin/env python3
"""Generate the bundled ZAMER Runtime v4 material set from committed PBR sources.

The production APK must not depend on a developer-local ZIP. This tool builds
the runtime assets deterministically from the compact PBR sources already kept
in the repository.

Only channels consumed by the current Flutter renderer are bundled:
BaseColor, Normal and packed MetallicRoughness (G=roughness, B=metallic=0).
Height/AO stay source/offline data until the renderer has dedicated channels
for them, avoiding a large APK penalty for maps it cannot display yet.

Laminate collections also receive 16 deterministic plank-face variants packed
into one 4x4 atlas per PBR channel. The atlas keeps the variation addressable
without forcing Android to load 48 individual textures for one floor.
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

from PIL import Image, ImageFile

# Several legacy generated JPEGs predate the current asset pipeline and miss
# a clean end-of-stream marker even though their decoded pixels are intact.
# Pillow is stricter than Flutter here. Allow those legacy sources to decode,
# then write fresh, fully valid Runtime v4 files and validate the outputs.
ImageFile.LOAD_TRUNCATED_IMAGES = True

APP_ROOT = Path(__file__).resolve().parents[1]
TEXTURES = APP_ROOT / "assets" / "textures"
GENERATED = TEXTURES / "generated_v1"
OUTPUT = TEXTURES / "runtime_v4"

SURFACE_SIZE = (2048, 2048)
PLANK_COUNT = 16
PLANK_ATLAS_COLUMNS = 4
PLANK_ATLAS_ROWS = 4
PLANK_ATLAS_CELL_SIZE = (1024, 143)
PLANK_ATLAS_SIZE = (
    PLANK_ATLAS_CELL_SIZE[0] * PLANK_ATLAS_COLUMNS,
    PLANK_ATLAS_CELL_SIZE[1] * PLANK_ATLAS_ROWS,
)

MATERIALS = {
    "Wall_Brick_Red_01": {
        "kind": "surface",
        "base": GENERATED / "wall_red_clay.jpg",
        "normal": GENERATED / "wall_red_clay_normal.png",
        "mr": GENERATED / "wall_red_clay_metallic_roughness.png",
    },
    "Wall_GypsumPlaster_White_01": {
        "kind": "surface",
        "base": TEXTURES / "plaster_warm.png",
        "normal": GENERATED / "wall_lime_normal.png",
        "mr": GENERATED / "wall_lime_metallic_roughness.png",
    },
    "Wall_Paint_MatteWhite_01": {
        "kind": "surface",
        "base": GENERATED / "wall_paint.jpg",
        "normal": GENERATED / "wall_paint_normal.png",
        "mr": GENERATED / "wall_paint_metallic_roughness.png",
    },
    "Tile_ConcreteLight_01": {
        "kind": "surface",
        "base": TEXTURES / "tile_concrete.png",
        "normal": GENERATED / "wall_microcement_normal.png",
        "mr": GENERATED / "wall_microcement_metallic_roughness.png",
    },
    "Tile_MarbleLight_01": {
        "kind": "surface",
        "base": TEXTURES / "tile_marble.png",
        "normal": GENERATED / "travertine_normal.png",
        "mr": GENERATED / "travertine_metallic_roughness.png",
    },
    "Tile_TerrazzoLight_01": {
        "kind": "surface",
        "base": GENERATED / "terrazzo.jpg",
        "normal": GENERATED / "terrazzo_normal.png",
        "mr": GENERATED / "terrazzo_metallic_roughness.png",
    },
    "Laminate_OakLight_01": {
        "kind": "planks",
        "base": GENERATED / "white_oak.jpg",
        "normal": GENERATED / "white_oak_normal.png",
        "mr": GENERATED / "white_oak_metallic_roughness.png",
    },
    "Laminate_OakSmoked_01": {
        "kind": "planks",
        "base": GENERATED / "dark_oak.jpg",
        "normal": GENERATED / "dark_oak_normal.png",
        "mr": GENERATED / "dark_oak_metallic_roughness.png",
    },
    "Laminate_WalnutWarm_01": {
        "kind": "planks",
        "base": TEXTURES / "floor_walnut.png",
        "normal": GENERATED / "dark_oak_normal.png",
        "mr": GENERATED / "dark_oak_metallic_roughness.png",
    },
}


def _resample(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return image.resize(size, Image.Resampling.LANCZOS)


def _load_rgb(path: Path, size: tuple[int, int]) -> Image.Image:
    if not path.is_file():
        raise FileNotFoundError(path)
    try:
        with Image.open(path) as source:
            decoded = source.convert("RGB")
    except OSError as exc:
        raise OSError(f"Could not decode material source {path}: {exc}") from exc
    if decoded.width < 8 or decoded.height < 8:
        raise ValueError(
            f"Material source is implausibly small: {path} "
            f"({decoded.width}x{decoded.height})"
        )
    return _resample(decoded, size)


def _pack_metallic_roughness(source: Image.Image) -> Image.Image:
    rgb = source.convert("RGB")
    roughness = rgb.getchannel("G")
    unused = Image.new("L", rgb.size, 255)
    metallic = Image.new("L", rgb.size, 0)
    return Image.merge("RGB", (unused, roughness, metallic))


def _save_webp(image: Image.Image, path: Path) -> None:
    image.save(path, "WEBP", quality=86, method=4)


def _save_png(image: Image.Image, path: Path) -> None:
    image.save(path, "PNG", optimize=False, compress_level=4)


def _validate_written_image(path: Path, expected_size: tuple[int, int]) -> None:
    if not path.is_file() or path.stat().st_size <= 0:
        raise RuntimeError(f"Runtime texture was not written: {path}")
    with Image.open(path) as image:
        image.load()
        if image.size != expected_size:
            raise RuntimeError(
                f"Runtime texture has wrong size: {path} "
                f"{image.size} != {expected_size}"
            )


def _wrapped_crop(image: Image.Image, x: int, y: int, width: int, height: int) -> Image.Image:
    source = image
    w, h = source.size
    x %= w
    y %= h

    tiled = Image.new(source.mode, (w * 2, h * 2))
    tiled.paste(source, (0, 0))
    tiled.paste(source, (w, 0))
    tiled.paste(source, (0, h))
    tiled.paste(source, (w, h))
    return tiled.crop((x, y, x + width, y + height))


def _generate_surface(material_id: str, spec: dict[str, object]) -> list[str]:
    base = _load_rgb(Path(spec["base"]), SURFACE_SIZE)
    normal = _load_rgb(Path(spec["normal"]), SURFACE_SIZE)
    mr_source = _load_rgb(Path(spec["mr"]), SURFACE_SIZE)
    packed = _pack_metallic_roughness(mr_source)

    files = [
        f"{material_id}_basecolor.webp",
        f"{material_id}_normal.png",
        f"{material_id}_metallic_roughness.png",
    ]
    _save_webp(base, OUTPUT / files[0])
    _save_png(normal, OUTPUT / files[1])
    _save_png(packed, OUTPUT / files[2])
    for name in files:
        _validate_written_image(OUTPUT / name, SURFACE_SIZE)
    return files


def _generate_planks(material_id: str, spec: dict[str, object]) -> list[str]:
    files = _generate_surface(material_id, spec)

    base = _load_rgb(Path(spec["base"]), SURFACE_SIZE)
    normal = _load_rgb(Path(spec["normal"]), SURFACE_SIZE)
    mr_source = _load_rgb(Path(spec["mr"]), SURFACE_SIZE)
    packed = _pack_metallic_roughness(mr_source)

    sources = {
        "basecolor.webp": base,
        "normal.png": normal,
        "metallic_roughness.png": packed,
    }
    atlases = {
        suffix: Image.new("RGB", PLANK_ATLAS_SIZE)
        for suffix in sources
    }

    for index in range(PLANK_COUNT):
        # Prime-ish offsets distribute samples over the source without random
        # state, keeping builds byte-for-byte deterministic.
        sample = index + 1
        x = (sample * 307) % SURFACE_SIZE[0]
        y = (sample * 181) % SURFACE_SIZE[1]
        atlas_x = (index % PLANK_ATLAS_COLUMNS) * PLANK_ATLAS_CELL_SIZE[0]
        atlas_y = (index // PLANK_ATLAS_COLUMNS) * PLANK_ATLAS_CELL_SIZE[1]

        for suffix, source in sources.items():
            plank = _wrapped_crop(
                source,
                x=x,
                y=y,
                width=PLANK_ATLAS_CELL_SIZE[0],
                height=PLANK_ATLAS_CELL_SIZE[1],
            )
            atlases[suffix].paste(plank, (atlas_x, atlas_y))

    for suffix, atlas in atlases.items():
        name = f"{material_id}_plank_atlas_{suffix}"
        if suffix.endswith(".webp"):
            _save_webp(atlas, OUTPUT / name)
        else:
            _save_png(atlas, OUTPUT / name)
        _validate_written_image(OUTPUT / name, PLANK_ATLAS_SIZE)
        files.append(name)

    return files


def generate(clean: bool = True) -> dict[str, object]:
    if clean and OUTPUT.exists():
        for child in OUTPUT.iterdir():
            if child.name == "README.txt":
                continue
            if child.is_dir():
                shutil.rmtree(child)
            else:
                child.unlink()
    OUTPUT.mkdir(parents=True, exist_ok=True)

    generated: dict[str, list[str]] = {}
    for material_id, spec in MATERIALS.items():
        if spec["kind"] == "planks":
            generated[material_id] = _generate_planks(material_id, spec)
        else:
            generated[material_id] = _generate_surface(material_id, spec)

    manifest = {
        "package": "Zamer Materials v4 Runtime 2K",
        "version": "4.1-bundled",
        "generatedFromCommittedSources": True,
        "surfaceResolution": list(SURFACE_SIZE),
        "plankCount": PLANK_COUNT,
        "plankAtlas": {
            "columns": PLANK_ATLAS_COLUMNS,
            "rows": PLANK_ATLAS_ROWS,
            "cellResolution": list(PLANK_ATLAS_CELL_SIZE),
            "atlasResolution": list(PLANK_ATLAS_SIZE),
        },
        "runtimeChannels": [
            "basecolor.webp",
            "normal.png",
            "metallic_roughness.png",
        ],
        "materials": generated,
    }
    (OUTPUT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-clean", action="store_true")
    args = parser.parse_args()
    manifest = generate(clean=not args.no_clean)
    material_count = len(manifest["materials"])
    file_count = sum(len(items) for items in manifest["materials"].values())
    print(f"Generated {material_count} Runtime v4 materials ({file_count} texture files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
