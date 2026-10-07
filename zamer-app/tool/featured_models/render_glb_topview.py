from __future__ import annotations

import argparse
import io
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

COMPONENT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
COMPONENTS = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}


def load_glb(path: Path):
    data = path.read_bytes()
    magic, version, total = struct.unpack_from('<III', data, 0)
    if magic != 0x46546C67 or version != 2:
        raise ValueError(f'{path} is not a GLB v2 file')
    offset = 12
    doc = None
    binary = None
    while offset < total:
        length, chunk_type = struct.unpack_from('<II', data, offset)
        offset += 8
        chunk = data[offset : offset + length]
        offset += length
        if chunk_type == 0x4E4F534A:
            doc = json.loads(chunk.rstrip(b'\x00 ').decode())
        elif chunk_type == 0x004E4942:
            binary = chunk
    if doc is None or binary is None:
        raise ValueError(f'{path} misses JSON or BIN chunk')
    return doc, binary


def accessor(doc, binary, index):
    spec = doc['accessors'][index]
    view = doc['bufferViews'][spec['bufferView']]
    dtype = np.dtype(COMPONENT[spec['componentType']]).newbyteorder('<')
    count = spec['count']
    width = COMPONENTS[spec['type']]
    offset = view.get('byteOffset', 0) + spec.get('byteOffset', 0)
    stride = view.get('byteStride', dtype.itemsize * width)
    if stride == dtype.itemsize * width:
        arr = np.frombuffer(binary, dtype=dtype, count=count * width, offset=offset)
        arr = arr.reshape(count, width) if width > 1 else arr
    else:
        arr = np.empty((count, width), dtype=dtype)
        for row in range(count):
            arr[row] = np.frombuffer(
                binary,
                dtype=dtype,
                count=width,
                offset=offset + row * stride,
            )

    # glTF commonly packs normals and texture coordinates into normalized
    # signed/unsigned integer accessors. Convert them to their floating-point
    # semantic range so external assets render correctly in catalogue previews.
    if spec.get('normalized'):
        kind = spec['componentType']
        arr = arr.astype(np.float32)
        if kind == 5120:
            arr = np.maximum(arr / 127.0, -1.0)
        elif kind == 5121:
            arr = arr / 255.0
        elif kind == 5122:
            arr = np.maximum(arr / 32767.0, -1.0)
        elif kind == 5123:
            arr = arr / 65535.0
    return arr


def embedded_images(doc, binary):
    result = []
    for image in doc.get('images', []):
        if 'bufferView' not in image:
            result.append(None)
            continue
        view = doc['bufferViews'][image['bufferView']]
        start = view.get('byteOffset', 0)
        raw = binary[start : start + view['byteLength']]
        result.append(Image.open(io.BytesIO(raw)).convert('RGB'))
    return result


def triangle_color(doc, images, material_index, uvs):
    materials = doc.get('materials', [])
    if material_index is None or material_index >= len(materials):
        return np.array([185.0, 180.0, 172.0])
    pbr = materials[material_index].get('pbrMetallicRoughness', {})
    factor = np.array(pbr.get('baseColorFactor', [1, 1, 1, 1])[:3], dtype=float)
    texture_index = pbr.get('baseColorTexture', {}).get('index')
    if texture_index is not None and texture_index < len(doc.get('textures', [])):
        source = doc['textures'][texture_index].get('source')
        if source is not None and source < len(images) and images[source] is not None:
            image = images[source]
            uv = np.mean(uvs, axis=0)
            u = float(uv[0] % 1)
            v = float(uv[1] % 1)
            pixel = image.getpixel(
                (
                    min(image.width - 1, int(u * image.width)),
                    min(image.height - 1, int((1 - v) * image.height)),
                )
            )
            return np.array(pixel, dtype=float) * factor
    return 255 * factor


def render(input_path: Path, output_path: Path, size: int = 512, padding: float = .07):
    doc, binary = load_glb(input_path)
    images = embedded_images(doc, binary)
    triangles = []
    all_positions = []
    light = np.array([-.35, .86, .36])
    light /= np.linalg.norm(light)

    for mesh in doc.get('meshes', []):
        for primitive in mesh.get('primitives', []):
            attrs = primitive.get('attributes', {})
            positions = accessor(doc, binary, attrs['POSITION']).astype(float)
            all_positions.append(positions)
            normals = (
                accessor(doc, binary, attrs['NORMAL']).astype(float)
                if 'NORMAL' in attrs
                else np.tile([0, 1, 0.0], (len(positions), 1))
            )
            uvs = (
                accessor(doc, binary, attrs['TEXCOORD_0']).astype(float)
                if 'TEXCOORD_0' in attrs
                else np.zeros((len(positions), 2))
            )
            indices = (
                accessor(doc, binary, primitive['indices']).reshape(-1, 3)
                if 'indices' in primitive
                else np.arange(len(positions)).reshape(-1, 3)
            )
            material = primitive.get('material')
            for face in indices:
                p = positions[face]
                n = normals[face].mean(axis=0)
                n /= max(np.linalg.norm(n), 1e-9)
                shade = .66 + .34 * max(0.0, float(np.dot(n, light)))
                color = np.clip(
                    triangle_color(doc, images, material, uvs[face]) * shade,
                    0,
                    255,
                ).astype(np.uint8)
                # GLB uses Y-up: project X/Z and painter-sort by elevation Y.
                triangles.append(
                    (float(p[:, 1].mean()), p[:, [0, 2]], tuple(int(x) for x in color))
                )

    positions = np.concatenate(all_positions)
    x0, x1 = positions[:, 0].min(), positions[:, 0].max()
    z0, z1 = positions[:, 2].min(), positions[:, 2].max()
    width = max(x1 - x0, 1e-6)
    depth = max(z1 - z0, 1e-6)
    scale_factor = 2
    canvas_size = size * scale_factor
    usable = size * (1 - 2 * padding)
    scale = min(usable / width, usable / depth) * scale_factor
    cx = (x0 + x1) / 2
    cz = (z0 + z1) / 2

    def project(points):
        return [
            (
                canvas_size / 2 + (float(x) - cx) * scale,
                canvas_size / 2 - (float(z) - cz) * scale,
            )
            for x, z in points
        ]

    image = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, 'RGBA')
    for _, points, color in sorted(triangles, key=lambda item: item[0]):
        draw.polygon(project(points), fill=(*color, 255))

    alpha = image.getchannel('A')
    blurred = alpha.filter(ImageFilter.GaussianBlur(radius=5 * scale_factor))
    shadow_alpha = blurred.point(lambda value: int(value * .22))
    shadow_shape = Image.new('RGBA', image.size, (0, 0, 0, 0))
    shadow_shape.putalpha(shadow_alpha)
    composed = Image.new('RGBA', image.size, (0, 0, 0, 0))
    composed.alpha_composite(shadow_shape, (4 * scale_factor, 5 * scale_factor))
    composed.alpha_composite(image)
    composed = composed.resize((size, size), Image.Resampling.LANCZOS)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    composed.save(output_path, 'WEBP', quality=94, method=6)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('input')
    parser.add_argument('output')
    parser.add_argument('--size', type=int, default=512)
    args = parser.parse_args()
    render(Path(args.input), Path(args.output), args.size)
