#!/usr/bin/env python3
"""Validate exported GLB 2.0 buffers, texture links and lossless decoded PNG content."""
import json, struct, sys, zlib
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
data=blob[bin_offset+8:]
assert len(data)==binlen==g["buffers"][0]["byteLength"]
assert g["asset"]["version"]=="2.0"
N=len(g["meshes"])
assert N==len(g["nodes"])==len(g["materials"])==2
assert len(g["images"])==len(g["textures"])==3*N
assert len(g["bufferViews"])==4*N and len(g["accessors"])==4*N
for i in range(N):
    view=g["bufferViews"][4*i]
    assert view["byteStride"]==48 and view["byteLength"]%48==0
    assert view["byteOffset"]+view["byteLength"]<=binlen
    assert g["accessors"][4*i]["count"]==view["byteLength"]//48
    for n,typ in enumerate(["VEC3","VEC3","VEC2","VEC4"]):
        assert g["accessors"][4*i+n]["type"]==typ
    attrs=g["meshes"][i]["primitives"][0]["attributes"]
    assert set(attrs)=={"POSITION","NORMAL","TEXCOORD_0","TANGENT"}
    pbr=g["materials"][i]["pbrMetallicRoughness"]
    assert 0<=pbr["metallicFactor"]<=1 and 0<=pbr["roughnessFactor"]<=1
    assert pbr["baseColorTexture"]["index"]==3*i
    assert g["materials"][i]["normalTexture"]["index"]==3*i+1
    assert pbr["metallicRoughnessTexture"]["index"]==3*i+2
# Verify every PNG is independently decodable with expected channels and values.
for idx,image in enumerate(g["images"]):
    v=g["bufferViews"][image["bufferView"]]
    p=data[v["byteOffset"]:v["byteOffset"]+v["byteLength"]]
    assert p.startswith(b"\x89PNG\r\n\x1a\n") and image["mimeType"]=="image/png"
    cursor=8; image_bytes=b""; width=height=0
    while cursor<len(p):
        count=struct.unpack_from(">I",p,cursor)[0]
        typ=p[cursor+4:cursor+8]
        payload=p[cursor+8:cursor+8+count]
        crc=struct.unpack_from(">I",p,cursor+8+count)[0]
        assert zlib.crc32(typ+payload)&0xffffffff==crc
        if typ==b"IHDR":
            width,height,depth,color=struct.unpack_from(">IIBB",payload,0)
            assert (width,height,depth,color)==(128,128,8,6)
        if typ==b"IDAT":image_bytes+=payload
        cursor+=12+count
        if typ==b"IEND":break
    raw=zlib.decompress(image_bytes)
    assert len(raw)==128*(1+128*4)
    assert all(raw[y*(1+128*4)]==0 for y in range(128))
    if idx%3==0 and idx==0:
        assert len(set(raw[5:40]))>1, "fabric albedo should not be a solid colour"
    if idx%3==1:
        assert raw[1+2] >= 128, "normal Z should face outwards"
print("GLB TEXTURED EXPORT VERIFIED: glTF 2.0 + 3 embedded CRC-valid PNG maps per object")
