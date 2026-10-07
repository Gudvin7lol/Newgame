#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
CATALOG_DIR="$APP_ROOT/assets/models/zamer_catalog"
TOPVIEW_DIR="$APP_ROOT/assets/topview/imported_2026_10_02"
mkdir -p "$CATALOG_DIR" "$TOPVIEW_DIR"

fetch_glb() {
  local id="$1"
  local url="$2"
  local tmp
  tmp="$(mktemp)"
  echo "[cc0-furniture] fetching $id"
  curl --fail --location --silent --show-error \
    --retry 4 --retry-delay 2 --connect-timeout 20 --max-time 180 \
    "$url" -o "$tmp"
  test -s "$tmp"
  mv "$tmp" "$CATALOG_DIR/$id.glb"
}

normalize_glb_bounds() {
  local file="$1"
  local target_w="$2"
  local target_h="$3"
  local target_d="$4"

  python3 - "$file" "$target_w" "$target_h" "$target_d" <<'PY'
import json, math, struct, sys
from pathlib import Path

path = Path(sys.argv[1])
target = [float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])]
data = path.read_bytes()

magic, version, total = struct.unpack_from("<III", data, 0)
if magic != 0x46546C67 or version != 2:
    raise SystemExit(f"{path}: expected GLB v2")

chunks = []
off = 12
gltf = None
while off + 8 <= total:
    length, kind = struct.unpack_from("<II", data, off)
    start = off + 8
    end = start + length
    payload = data[start:end]
    chunks.append([kind, payload])
    if kind == 0x4E4F534A:
        gltf = json.loads(payload.decode("utf-8").rstrip(" \t\r\n\0"))
    off = end

if gltf is None:
    raise SystemExit(f"{path}: missing JSON chunk")

def ident():
    return [
        [1.0,0.0,0.0,0.0],
        [0.0,1.0,0.0,0.0],
        [0.0,0.0,1.0,0.0],
        [0.0,0.0,0.0,1.0],
    ]

def mul(a,b):
    return [[sum(a[r][k]*b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]

def mat_node(n):
    if isinstance(n.get("matrix"), list) and len(n["matrix"]) == 16:
        v=[float(x) for x in n["matrix"]]
        return [[v[c*4+r] for c in range(4)] for r in range(4)]
    t=[float(x) for x in n.get("translation",[0,0,0])]
    s=[float(x) for x in n.get("scale",[1,1,1])]
    q=[float(x) for x in n.get("rotation",[0,0,0,1])]
    x,y,z,w=q
    xx,yy,zz=x*x,y*y,z*z
    xy,xz,yz=x*y,x*z,y*z
    wx,wy,wz=w*x,w*y,w*z
    r=[
      [1-2*(yy+zz), 2*(xy-wz), 2*(xz+wy), 0],
      [2*(xy+wz), 1-2*(xx+zz), 2*(yz-wx), 0],
      [2*(xz-wy), 2*(yz+wx), 1-2*(xx+yy), 0],
      [0,0,0,1],
    ]
    sm=[[s[0],0,0,0],[0,s[1],0,0],[0,0,s[2],0],[0,0,0,1]]
    tm=ident()
    tm[0][3],tm[1][3],tm[2][3]=t
    return mul(tm,mul(r,sm))

def point(m,p):
    v=[p[0],p[1],p[2],1.0]
    out=[sum(m[r][k]*v[k] for k in range(4)) for r in range(4)]
    return out[:3]

nodes=gltf.get("nodes",[])
meshes=gltf.get("meshes",[])
accessors=gltf.get("accessors",[])
scenes=gltf.get("scenes",[])
scene_index=int(gltf.get("scene",0)) if scenes else 0

if scenes:
    roots=list(scenes[scene_index].get("nodes",[]))
else:
    children={int(c) for n in nodes for c in n.get("children",[])}
    roots=[i for i in range(len(nodes)) if i not in children]

lo=[math.inf,math.inf,math.inf]
hi=[-math.inf,-math.inf,-math.inf]

def include(p):
    for i in range(3):
        lo[i]=min(lo[i],p[i]); hi[i]=max(hi[i],p[i])

def visit(idx,parent):
    n=nodes[idx]
    world=mul(parent,mat_node(n))
    mi=n.get("mesh")
    if isinstance(mi,int):
        for prim in meshes[mi].get("primitives",[]):
            ai=prim.get("attributes",{}).get("POSITION")
            if isinstance(ai,int):
                acc=accessors[ai]
                amin=acc.get("min"); amax=acc.get("max")
                if amin is None or amax is None:
                    raise SystemExit(f"{path}: POSITION accessor lacks min/max")
                for x in (float(amin[0]),float(amax[0])):
                    for y in (float(amin[1]),float(amax[1])):
                        for z in (float(amin[2]),float(amax[2])):
                            include(point(world,[x,y,z]))
    for child in n.get("children",[]):
        visit(int(child),world)

for root in roots:
    visit(int(root),ident())

size=[hi[i]-lo[i] for i in range(3)]
if any((not math.isfinite(v) or v <= 1e-9) for v in size):
    raise SystemExit(f"{path}: invalid bounds {size}")

scale=[target[i]/size[i] for i in range(3)]
parent={"name":"ZamerBoundsNormalize","scale":scale,"children":roots}
nodes.append(parent)
parent_index=len(nodes)-1
gltf["nodes"]=nodes
if scenes:
    scenes[scene_index]["nodes"]=[parent_index]
    gltf["scenes"]=scenes
else:
    gltf["scenes"]=[{"nodes":[parent_index]}]
    gltf["scene"]=0

json_bytes=json.dumps(gltf,separators=(",",":"),ensure_ascii=False).encode("utf-8")
json_bytes += b" " * ((4 - len(json_bytes)%4)%4)

new_chunks=[]
for kind,payload in chunks:
    if kind == 0x4E4F534A:
        payload=json_bytes
    new_chunks.append(struct.pack("<II",len(payload),kind)+payload)

out=struct.pack("<III",0x46546C67,2,12+sum(len(c) for c in new_chunks))+b"".join(new_chunks)
path.write_bytes(out)
print(f"[cc0-furniture] normalized {path.name}: {size} -> {target}")
PY
}

install_all_lods() {
  local id="$1"
  cp "$CATALOG_DIR/$id.glb" "$CATALOG_DIR/${id}_lod1.glb"
  cp "$CATALOG_DIR/$id.glb" "$CATALOG_DIR/${id}_lod2.glb"
}

# CC0 1.0 Universal.
# Source: https://3dassets.dev/assets/hotel-and-resort-operations-bed-king-upholstered-819ff50d
fetch_glb "bed-160" "https://cdn.3dassets.dev/assets/25738/v1/model.glb"
normalize_glb_bounds "$CATALOG_DIR/bed-160.glb" 1.80 1.05 2.15
install_all_lods "bed-160"

cp "$CATALOG_DIR/bed-160.glb" "$CATALOG_DIR/bed-180.glb"
normalize_glb_bounds "$CATALOG_DIR/bed-180.glb" 1.80 1.13 2.20
install_all_lods "bed-180"

# CC0 1.0 Universal.
# Source: https://3dassets.dev/assets/hotel-and-resort-operations-lobby-sofa-79174bf1
fetch_glb "sofa-3" "https://cdn.3dassets.dev/assets/25866/v1/model.glb"
normalize_glb_bounds "$CATALOG_DIR/sofa-3.glb" 2.20 0.85 0.95
install_all_lods "sofa-3"

# Keep the 2D equipment preview derived from the exact GLB used in 3D.
if [ -f "$APP_ROOT/tool/featured_models/render_glb_topview.py" ]; then
  python3 "$APP_ROOT/tool/featured_models/render_glb_topview.py" \
    "$CATALOG_DIR/bed-180.glb" "$TOPVIEW_DIR/featured_bed_180.webp" --size 512
  python3 "$APP_ROOT/tool/featured_models/render_glb_topview.py" \
    "$CATALOG_DIR/sofa-3.glb" "$TOPVIEW_DIR/featured_sofa_3.webp" --size 512
fi

echo "[cc0-furniture] installed normalized bed-160, bed-180 and sofa-3"
