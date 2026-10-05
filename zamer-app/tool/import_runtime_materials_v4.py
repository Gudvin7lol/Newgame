#!/usr/bin/env python3
"""Import ZAMER Materials v4 Runtime 2K into Flutter assets.

Usage:
    python tool/import_runtime_materials_v4.py /path/to/Zamer_Materials_v4_Runtime_2K.zip

The importer validates the production contract, extracts only runtime material
files, and generates glTF-style metallic-roughness textures where G=roughness
and B=metallic (0 for this pack). Original Roughness, Height and AO maps are
kept as well.
"""

from __future__ import annotations

import argparse
import io
import json
import shutil
import sys
import zipfile
from pathlib import Path, PurePosixPath

try:
    from PIL import Image
except ImportError as exc:  # pragma: no cover - tool dependency guard
    raise SystemExit(
        "Pillow is required: python -m pip install Pillow"
    ) from exc

EXPECTED_PACKAGE = "Zamer Materials v4 Runtime 2K"
EXPECTED_VERSION = "4.0"
EXPECTED_MATERIALS = {
    "Wall_Brick_Red_01": ("walls", "seamless_surface"),
    "Wall_GypsumPlaster_White_01": ("walls", "seamless_surface"),
    "Wall_Paint_MatteWhite_01": ("walls", "seamless_surface"),
    "Tile_ConcreteLight_01": ("tiles", "procedural_tile_surface"),
    "Tile_MarbleLight_01": ("tiles", "procedural_tile_surface"),
    "Tile_TerrazzoLight_01": ("tiles", "procedural_tile_surface"),
    "Laminate_OakLight_01": ("laminate", "plank_collection"),
    "Laminate_OakSmoked_01": ("laminate", "plank_collection"),
    "Laminate_WalnutWarm_01": ("laminate", "plank_collection"),
}
SURFACE_MAPS = ("basecolor.webp", "normal.png", "roughness.png", "height.png", "ao.png")
PLANK_MAPS = SURFACE_MAPS


def _safe_member(name: str) -> PurePosixPath:
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError(f"Unsafe archive path: {name}")
    return path


def _read_json(archive: zipfile.ZipFile, name: str) -> dict:
    return json.loads(archive.read(name).decode("utf-8"))


def _image_size(archive: zipfile.ZipFile, name: str) -> tuple[int, int]:
    with Image.open(io.BytesIO(archive.read(name))) as image:
        return image.size


def _write_member(archive: zipfile.ZipFile, member: str, output: Path) -> None:
    _safe_member(member)
    output.parent.mkdir(parents=True, exist_ok=True)
    with archive.open(member) as source, output.open("wb") as target:
        shutil.copyfileobj(source, target)


def _write_metallic_roughness(archive: zipfile.ZipFile, roughness_member: str, output: Path) -> None:
    with Image.open(io.BytesIO(archive.read(roughness_member))).convert("L") as roughness:
        zero = Image.new("L", roughness.size, 0)
        unused = Image.new("L", roughness.size, 255)
        packed = Image.merge("RGB", (unused, roughness, zero))
        output.parent.mkdir(parents=True, exist_ok=True)
        packed.save(output, format="PNG", optimize=True)


def _validate_manifest(manifest: dict) -> list[dict]:
    if manifest.get("package") != EXPECTED_PACKAGE:
        raise ValueError(f"Unexpected package: {manifest.get('package')!r}")
    if str(manifest.get("version")) != EXPECTED_VERSION:
        raise ValueError(f"Unexpected version: {manifest.get('version')!r}")
    if manifest.get("status") != "runtime":
        raise ValueError("Material pack is not marked as runtime")
    if manifest.get("materialCount") != 9:
        raise ValueError("Runtime v4 must contain exactly 9 materials")
    runtime = manifest.get("runtime") or {}
    if runtime.get("metallic") != 0:
        raise ValueError("Runtime v4 contract requires metallic=0")
    if runtime.get("normalConvention") != "OpenGL_Y+":
        raise ValueError("Runtime v4 normals must use OpenGL Y+")

    materials = manifest.get("materials") or []
    ids = {item.get("id") for item in materials}
    if ids != set(EXPECTED_MATERIALS):
        missing = sorted(set(EXPECTED_MATERIALS) - ids)
        extra = sorted(ids - set(EXPECTED_MATERIALS))
        raise ValueError(f"Material IDs differ; missing={missing}, extra={extra}")
    return materials


def import_pack(zip_path: Path, output_root: Path, clean: bool) -> None:
    if clean and output_root.exists():
        shutil.rmtree(output_root)
    output_root.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(zip_path) as archive:
        manifest = _read_json(archive, "manifest.json")
        materials = _validate_manifest(manifest)
        members = set(archive.namelist())

        for item in materials:
            material_id = item["id"]
            category, expected_type = EXPECTED_MATERIALS[material_id]
            if item.get("category") != category or item.get("type") != expected_type:
                raise ValueError(f"Manifest type/category mismatch for {material_id}")

            source_root = item["path"].rstrip("/")
            metadata_name = f"{source_root}/material.json"
            if metadata_name not in members:
                raise ValueError(f"Missing {metadata_name}")
            metadata = _read_json(archive, metadata_name)
            target_root = output_root / source_root
            target_root.mkdir(parents=True, exist_ok=True)
            (target_root / "material.json").write_text(
                json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )

            preview = f"{source_root}/preview.webp"
            if preview in members:
                _write_member(archive, preview, target_root / "preview.webp")

            if expected_type == "plank_collection":
                if metadata.get("plankCount") != 16:
                    raise ValueError(f"{material_id}: expected 16 planks")
                if metadata.get("plankResolution") != [2048, 286]:
                    raise ValueError(f"{material_id}: expected 2048x286 planks")
                if metadata.get("physicalPlankMm") != [1380, 193]:
                    raise ValueError(f"{material_id}: expected 1380x193 mm planks")

                for index in range(1, 17):
                    plank = f"{index:02d}"
                    source_plank = f"{source_root}/planks/{plank}"
                    target_plank = target_root / "planks" / plank
                    for map_name in PLANK_MAPS:
                        member = f"{source_plank}/{map_name}"
                        if member not in members:
                            raise ValueError(f"Missing {member}")
                        expected_size = (2048, 286)
                        if _image_size(archive, member) != expected_size:
                            raise ValueError(f"{member}: expected {expected_size}")
                        _write_member(archive, member, target_plank / map_name)
                    _write_metallic_roughness(
                        archive,
                        f"{source_plank}/roughness.png",
                        target_plank / "metallic_roughness.png",
                    )
            else:
                if metadata.get("resolution") != [2048, 2048]:
                    raise ValueError(f"{material_id}: expected 2048x2048 maps")
                for map_name in SURFACE_MAPS:
                    member = f"{source_root}/{map_name}"
                    if member not in members:
                        raise ValueError(f"Missing {member}")
                    expected_size = (2048, 2048)
                    if _image_size(archive, member) != expected_size:
                        raise ValueError(f"{member}: expected {expected_size}")
                    _write_member(archive, member, target_root / map_name)
                _write_metallic_roughness(
                    archive,
                    f"{source_root}/roughness.png",
                    target_root / "metallic_roughness.png",
                )

        runtime_manifest = dict(manifest)
        runtime_manifest["importedAssetRoot"] = "assets/textures/runtime_v4"
        runtime_manifest["packedMetallicRoughness"] = {
            "red": "unused_255",
            "green": "roughness",
            "blue": "metallic_0",
        }
        (output_root / "manifest.json").write_text(
            json.dumps(runtime_manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    print(f"Imported Runtime v4 material pack to {output_root}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("zip_path", type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("assets/textures/runtime_v4"),
    )
    parser.add_argument("--no-clean", action="store_true")
    args = parser.parse_args()

    try:
        import_pack(args.zip_path, args.output, clean=not args.no_clean)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, json.JSONDecodeError) as exc:
        print(f"Runtime v4 import failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
