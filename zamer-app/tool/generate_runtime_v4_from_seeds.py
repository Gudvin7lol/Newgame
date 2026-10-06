from __future__ import annotations

import argparse
import base64
import io
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

MATERIALS = {
    'Wall_Brick_Red_01': dict(kind='surface', scale=1000, rough=0.78, normal=2.8),
    'Wall_GypsumPlaster_White_01': dict(kind='surface', scale=1000, rough=0.88, normal=0.9),
    'Wall_Paint_MatteWhite_01': dict(kind='surface', scale=1000, rough=0.90, normal=0.35),
    'Tile_ConcreteLight_01': dict(kind='surface', scale=600, rough=0.58, normal=0.9),
    'Tile_MarbleLight_01': dict(kind='surface', scale=600, rough=0.32, normal=0.45),
    'Tile_TerrazzoLight_01': dict(kind='surface', scale=600, rough=0.46, normal=0.55),
    'Laminate_OakLight_01': dict(kind='laminate', scale=1380, rough=0.58, normal=1.0),
    'Laminate_OakSmoked_01': dict(kind='laminate', scale=1380, rough=0.58, normal=1.0),
    'Laminate_WalnutWarm_01': dict(kind='laminate', scale=1380, rough=0.52, normal=1.05),
}


def _read_seed(seed_dir: Path, material_id: str) -> Image.Image:
    encoded = (seed_dir / f'{material_id}.webp.b64').read_text(encoding='ascii')
    return Image.open(io.BytesIO(base64.b64decode(encoded))).convert('RGB')


def _height(rgb: Image.Image) -> Image.Image:
    lum = rgb.convert('L')
    a = np.asarray(lum, dtype=np.float32) / 255.0
    base = np.asarray(lum.filter(ImageFilter.GaussianBlur(2.2)), dtype=np.float32) / 255.0
    local = a - np.asarray(lum.filter(ImageFilter.GaussianBlur(10.0)), dtype=np.float32) / 255.0
    h = 0.68 * base + 0.32 * (0.5 + local * 1.8)
    lo, hi = np.percentile(h, [1.5, 98.5])
    h = np.clip((h - lo) / max(1e-5, hi - lo), 0, 1)
    return Image.fromarray(np.uint8(h * 255), 'L')


def _normal(height: Image.Image, strength: float) -> Image.Image:
    h = np.asarray(height, dtype=np.float32) / 255.0
    gy, gx = np.gradient(h)
    nx = -gx * strength * 8.0
    ny = -gy * strength * 8.0
    nz = np.ones_like(h)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.dstack((nx / norm, ny / norm, nz / norm))
    return Image.fromarray(np.uint8(np.clip((n * 0.5 + 0.5) * 255.0, 0, 255)), 'RGB')


def _roughness(height: Image.Image, mean: float) -> Image.Image:
    h = np.asarray(height, dtype=np.float32) / 255.0
    r = np.clip(mean + (h - 0.5) * 0.14, 0.18, 0.96)
    return Image.fromarray(np.uint8(r * 255), 'L')


def _ao(height: Image.Image) -> Image.Image:
    h = np.asarray(height, dtype=np.float32) / 255.0
    return Image.fromarray(np.uint8(np.clip(0.78 + h * 0.22, 0, 1) * 255), 'L')


def _mr(roughness: Image.Image) -> Image.Image:
    r = np.asarray(roughness, dtype=np.uint8)
    return Image.fromarray(
        np.dstack((np.full_like(r, 255), r, np.zeros_like(r))),
        'RGB',
    )


def _save(im: Image.Image, path: Path, quality: int = 82) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, 'WEBP', quality=quality, method=4)


def _surface(seed: Image.Image, cfg: dict, out: Path, material_id: str) -> None:
    base = seed.resize((2048, 2048), Image.Resampling.LANCZOS)
    height = _height(base)
    roughness = _roughness(height, cfg['rough'])
    _save(base, out / f'{material_id}_basecolor.webp', 82)
    _save(_normal(height, cfg['normal']), out / f'{material_id}_normal.webp', 86)
    _save(height, out / f'{material_id}_height.webp', 78)
    _save(_ao(height), out / f'{material_id}_ao.webp', 78)
    _save(_mr(roughness), out / f'{material_id}_metallic_roughness.webp', 80)


def _row_bands(seed: Image.Image) -> list[tuple[int, int]]:
    a = np.asarray(seed.convert('L'))
    mask = (a > 32).mean(axis=1) > 0.65
    bands = []
    start = None
    for i, visible in enumerate(mask):
        if visible and start is None:
            start = i
        if start is not None and (not visible or i == len(mask) - 1):
            end = i if not visible else i + 1
            if end - start >= 12:
                bands.append((start, end))
            start = None
    return bands


def _extract_planks(seed: Image.Image) -> list[Image.Image]:
    bands = _row_bands(seed)
    if len(bands) != 4:
        raise ValueError(f'Expected 4 plank bands, got {bands}')
    planks = []
    for y0, y1 in bands:
        for column in range(4):
            x0 = round(seed.width * column / 4)
            x1 = round(seed.width * (column + 1) / 4)
            planks.append(
                seed.crop((x0, y0, x1, y1)).resize(
                    (2048, 286),
                    Image.Resampling.LANCZOS,
                )
            )
    return planks


def _compose(planks: list[Image.Image], mode: str) -> Image.Image:
    width = height = 2048
    plank_width = round(1380 * 0.58)
    row_height = round(193 * 0.58)
    resized = [
        plank.resize((plank_width, row_height), Image.Resampling.LANCZOS)
        for plank in planks
    ]
    canvas = Image.new('RGB', (width, height))
    index = 0
    for row in range(math.ceil(height / row_height) + 1):
        if mode == 'half':
            shift = (row % 2) * plank_width // 2
        elif mode == 'third':
            shift = (row % 3) * plank_width // 3
        else:
            shift = (row * 307) % plank_width
        x = -shift - plank_width
        while x < width:
            canvas.paste(resized[index % len(resized)], (x, row * row_height))
            index += 5 if mode == 'random' else 1
            x += plank_width
    return canvas


def _laminate(seed: Image.Image, cfg: dict, out: Path, material_id: str) -> None:
    planks = _extract_planks(seed)
    for index, plank in enumerate(planks, 1):
        _save(plank, out / f'{material_id}_plank_{index:02d}_basecolor.webp', 80)

    variants = {
        '': _compose(planks, 'random'),
        '_half': _compose(planks, 'half'),
        '_third': _compose(planks, 'third'),
    }
    for suffix, image in variants.items():
        _save(image, out / f'{material_id}{suffix}.webp', 80)

    base = variants['']
    height = _height(base)
    roughness = _roughness(height, cfg['rough'])
    _save(_normal(height, cfg['normal']), out / f'{material_id}_normal.webp', 86)
    _save(height, out / f'{material_id}_height.webp', 78)
    _save(_ao(height), out / f'{material_id}_ao.webp', 78)
    _save(_mr(roughness), out / f'{material_id}_metallic_roughness.webp', 80)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--seed-dir', type=Path, default=Path('tool/runtime_v4_seeds'))
    parser.add_argument('--output', type=Path, default=Path('assets/textures/runtime_v4'))
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    for old in args.output.glob('*'):
        if old.name != 'README.txt' and old.is_file():
            old.unlink()

    for material_id, cfg in MATERIALS.items():
        seed = _read_seed(args.seed_dir, material_id)
        if cfg['kind'] == 'surface':
            _surface(seed, cfg, args.output, material_id)
        else:
            _laminate(seed, cfg, args.output, material_id)

    manifest = {
        'version': '4.0-generated',
        'materials': list(MATERIALS),
        'source': 'v4 preview seeds',
        'resolution': 2048,
        'plankCount': 16,
        'physicalPlankMm': [1380, 193],
        'normalConvention': 'OpenGL_Y+',
        'metallic': 0,
    }
    (args.output / 'manifest.generated.json').write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + '\n',
        encoding='utf-8',
    )
    total_mb = sum(
        p.stat().st_size for p in args.output.iterdir() if p.is_file()
    ) / 1024 / 1024
    print(f'Generated Runtime v4 assets: {total_mb:.1f} MB')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
