#!/usr/bin/env python3
"""Structural and binary-range smoke validation for GLB 2.0 output."""
import json, struct, sys
from pathlib import Path
blob=Path(sys.argv[1]).read_bytes()
magic,version,length=struct.unpack_from("<III",blob,0)
assert magic==0x46546C67 and version==2 and length==len(blob)
jsonlen,jtype=struct.unpack_from("<II",blob,12)
assert jtype==0x4E4F534A and jsonlen%4==0
g=json.loads(blob[20:20+jsonlen])
bin_offset=20+jsonlen
binlen,btype=struct.unpack_from("<II",blob,bin_offset)
assert btype==0x004E4942 and binlen==len(blob)-bin_offset-8
assert g["asset"]["version"]=="2.0"
assert len(g["nodes"])==len(g["meshes"])==len(g["materials"])==2
assert g["buffers"][0]["byteLength"]==binlen
for idx,v in enumerate(g["bufferViews"]):
    assert v["byteStride"]==32 and v["byteLength"]%32==0
    assert v["byteOffset"]+v["byteLength"]<=binlen
    assert g["accessors"][idx*3]["count"]==v["byteLength"]//32
for m in g["meshes"]:
    a=m["primitives"][0]["attributes"]
    assert set(a)=={"POSITION","NORMAL","TEXCOORD_0"}
for m in g["materials"]:
    p=m["pbrMetallicRoughness"]
    assert 0<=p["roughnessFactor"]<=1
print("GLB SCHEMA VERIFIED: glTF 2.0 layout, 32-byte interleaved positions/normals/UVs")
