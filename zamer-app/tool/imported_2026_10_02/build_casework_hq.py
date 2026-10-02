from __future__ import annotations

import argparse
import io
import json
import os
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

parser = argparse.ArgumentParser()
parser.add_argument('kind', choices=['tv', 'wardrobe'])
parser.add_argument('detail', type=float)
parser.add_argument('output')
args = parser.parse_args()

SCRIPT_DIR = Path(__file__).resolve().parent
APP_ROOT = SCRIPT_DIR.parent.parent
ROOT = SCRIPT_DIR / 'kitchen'
os.environ['SOFA_DETAIL'] = str(max(.25, args.detail))
exec((ROOT / 'source/mesh_helpers.py').read_text())

S = 1024 if args.detail >= .75 else (512 if args.detail >= .4 else 256)
rng = np.random.default_rng(170 + int(args.detail * 100))
base_path = APP_ROOT / 'assets/textures/imported_2026_10_02/oak_natural_1200mm_basecolor.webp'
if base_path.exists():
    ref = np.asarray(
        Image.open(base_path).convert('RGB').resize((S, S), Image.Resampling.LANCZOS)
    ).astype(np.float32)
else:
    ref = np.zeros((S, S, 3), np.float32) + np.array([158, 118, 76], np.float32)

y, x = np.mgrid[:S, :S]
u = x / S
v = y / S
warp = .032 * np.sin(v * 2 * np.pi) + .010 * np.sin(v * 13 * np.pi)
grain = 4.5 * np.sin((u * 6.5 + warp) * 2 * np.pi) + 1.4 * np.sin(
    (u * 20 + warp) * 2 * np.pi
)
pores = gaussian_filter(rng.normal(0, 1, (S, S)), .5) * 3.4
oak = np.clip(
    ref * .9 + np.array([4, 1, -3]) + (grain + pores)[:, :, None], 0, 255
).astype(np.uint8)


def png(array):
    buf = io.BytesIO()
    Image.fromarray(array).save(buf, format='PNG', optimize=True)
    return buf.getvalue()


tex = png(oak)
gray = oak.mean(2).astype(np.float32) / 255
gy, gx = np.gradient(gaussian_filter(gray, .55))
normal = np.zeros((S, S, 3), np.uint8)
normal[:, :, 0] = np.clip(128 - gx * 1600, 0, 255)
normal[:, :, 1] = np.clip(128 - gy * 1600, 0, 255)
normal[:, :, 2] = 248
ntex = png(normal)
rough = np.zeros((S, S, 3), np.uint8)
rough[:, :, 0] = 255
rough[:, :, 1] = np.clip(
    (.50 + gaussian_filter(rng.normal(0, .025, (S, S)), 1)) * 255, 95, 175
).astype(np.uint8)
rtex = png(rough)

materials = [
    {
        'name': 'Natural oak HQ',
        'pbrMetallicRoughness': {
            'baseColorTexture': {'index': 0},
            'metallicRoughnessTexture': {'index': 2},
            'metallicFactor': 0,
            'roughnessFactor': 1,
        },
        'normalTexture': {'index': 1, 'scale': .20},
    },
    {
        'name': 'Matte black',
        'pbrMetallicRoughness': {
            'baseColorFactor': [.018, .020, .022, 1],
            'metallicFactor': .25,
            'roughnessFactor': .34,
        },
    },
    {
        'name': 'Dark interior',
        'pbrMetallicRoughness': {
            'baseColorFactor': [.055, .050, .045, 1],
            'metallicFactor': 0,
            'roughnessFactor': .72,
        },
    },
    {
        'name': 'Brushed dark metal',
        'pbrMetallicRoughness': {
            'baseColorFactor': [.12, .12, .115, 1],
            'metallicFactor': .90,
            'roughnessFactor': .25,
        },
    },
]


def box(name, size, pos, mat=0, r=.004, n=8):
    softbox(
        name,
        size,
        pos,
        min(r, min(size) / 3),
        mat=mat,
        N=max(4, round(n * args.detail)),
    )


parts = []
if args.kind == 'tv':
    width, depth, height = 1.60, .40, .55
    box('black_plinth', (1.48, .34, .065), (0, .015, .0325), 1, r=.008)
    box('bottom', (width, depth, .030), (0, 0, .095), r=.003, n=7)
    box('top', (width, depth, .040), (0, 0, height - .020), r=.006, n=10)
    box('left_side', (.030, depth, height - .115), (-width / 2 + .015, 0, .31))
    box('right_side', (.030, depth, height - .115), (width / 2 - .015, 0, .31))
    box('rear', (width - .06, .018, height - .13), (0, depth / 2 - .012, .31), 2)
    front_y = -depth / 2 - .012
    door_w = .48
    door_h = .36
    for x0, name in [(-.545, 'left_door'), (.545, 'right_door')]:
        box(name, (door_w, .024, door_h), (x0, front_y, .31), r=.006, n=10)
        box(
            name + '_handle',
            (.20, .016, .018),
            (x0, front_y - .017, .435),
            3,
            r=.005,
        )
    box('center_shelf', (.56, depth - .05, .024), (0, .010, .205), r=.003, n=6)
    box('center_back', (.56, .016, .315), (0, depth / 2 - .018, .345), 2)
else:
    width, depth, height = 2.0, .65, 2.40
    box('base_rail', (width, .055, .060), (0, -depth / 2 + .025, .030), 1, r=.008)
    box('top_panel', (width, depth, .035), (0, 0, height - .0175))
    box('bottom_panel', (width, depth, .035), (0, 0, .0775))
    box('left_side', (.035, depth, height - .07), (-width / 2 + .0175, 0, height / 2))
    box('right_side', (.035, depth, height - .07), (width / 2 - .0175, 0, height / 2))
    box('rear', (width - .07, .018, height - .10), (0, depth / 2 - .012, height / 2), 2)
    front_y = -depth / 2 - .016
    leaf_w = 1.015
    box('left_slider', (leaf_w, .026, height - .13), (-.49, front_y - .008, height / 2), r=.005, n=10)
    box('right_slider', (leaf_w, .026, height - .13), (.49, front_y + .008, height / 2), r=.005, n=10)
    box('bottom_track', (width - .04, .030, .025), (0, front_y - .005, .105), 3)
    box('top_track', (width - .04, .030, .025), (0, front_y - .005, height - .07), 3)
    box('left_recessed_handle', (.025, .018, .34), (-.91, front_y - .035, 1.20), 3, r=.005)
    box('right_recessed_handle', (.025, .018, .34), (.91, front_y - .018, 1.20), 3, r=.005)

output = Path(args.output)
output.parent.mkdir(parents=True, exist_ok=True)
P = str(output.parent)
MODEL_NAME = output.stem
DETAIL = args.detail
MATERIAL_NAME = 'Natural oak HQ'
NORMAL_SCALE = .20
source = (ROOT / 'source/export_template.py').read_text()
source = source.replace(
    "j=json.dumps(g,separators=(',',':')).encode()",
    "g['materials']=materials\nj=json.dumps(g,separators=(',',':')).encode()",
)
exec(source, globals())
print(
    json.dumps(
        {
            'kind': args.kind,
            'detail': args.detail,
            'texture': S,
            'output': str(output),
            'bytes': output.stat().st_size,
        },
        ensure_ascii=False,
    )
)
