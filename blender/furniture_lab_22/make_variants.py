"""Furniture Lab 2.2: deterministic selective PBR colorway variation.
Keeps the official licensed Poly Haven CC0 GLB geometry, UVs, normal and ORM
byte-identical. No AI mesh or arbitrary mesh scaling. A recolor, not a scan.
"""
import io,os,json,struct,hashlib
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
root=Path(os.environ.get("FURNITURE22_OUT","out/furniture22"))
root.mkdir(parents=True,exist_ok=True)
sources=root/"source"
palette={
 "sofa_01":{"linen_warm":(176,164,147),"sage_upholstery":(121,139,125)},
 "drawer_cabinet":{"smoked_walnut":(109,78,56),"pale_oak":(185,160,128)}
}
baseline={"sofa_01":np.array((149.72,139.73,129.76)),
          "drawer_cabinet":np.array((175.5,133.05,91.29))}
def parse_glb(p):
    b=p.read_bytes();assert b[:4]==b'glTF' and struct.unpack_from('<I',b,8)[0]==len(b)
    n,t=struct.unpack_from('<II',b,12);assert t==0x4E4F534A
    doc=json.loads(b[20:20+n]);a=20+n
    q,k=struct.unpack_from('<II',b,a);assert k==0x004E4942
    return doc,b[a+8:a+8+q]
def write_glb(doc,blob,path):
    blob+=b'\0'*((-len(blob))%4)
    doc["buffers"][0]["byteLength"]=len(blob)
    js=json.dumps(doc,separators=(",",":"),ensure_ascii=False).encode('utf8')
    js+=b' '*((-len(js))%4)
    b=b'glTF'+struct.pack('<II',2,12+8+len(js)+8+len(blob))
    b+=struct.pack('<II',len(js),0x4E4F534A)+js
    b+=struct.pack('<II',len(blob),0x004E4942)+blob
    path.write_bytes(b)
def smooth(v):
    v=np.clip(v,0,1)
    return v*v*(3-2*v)
report={"source":"Poly Haven CC0 via previous verified 2.1 release",
  "technique":"Selectively recolor original BaseColor texture atlas",
  "geometry_rebuilt":False,"new_3D_generated":False,
  "normal_and_roughness_bytes_unchanged":True,"android_viewer_tested":False,
  "variants":{}}
sheet=Image.new("RGB",(1260,980),(35,35,38))
draw=ImageDraw.Draw(sheet)
for ri,kind in enumerate(palette):
    file=sources/(kind+"_mobile_1k.glb")
    doc,blob=parse_glb(file)
    baseid=doc["textures"][doc["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]
    meta=doc["images"][baseid];view=doc["bufferViews"][meta["bufferView"]]
    st=view.get("byteOffset",0);n=view["byteLength"]
    old=Image.open(io.BytesIO(blob[st:st+n])).convert("RGB")
    rgb=np.asarray(old).astype(np.float32)
    lum=.2126*rgb[:,:,0]+.7152*rgb[:,:,1]+.0722*rgb[:,:,2]
    if kind=="sofa_01":
        mask=smooth((lum-72)/43)
    else:
        mask=smooth((lum-43)/37)*smooth(((rgb[:,:,0]-rgb[:,:,2])-14)/29)
    assert .20<float(mask.mean())<.90,"Unexpected selected texture region"
    entries=[("ORIGINAL",old)]
    for color,target in palette[kind].items():
        ratios=np.array(target,dtype=np.float32)/baseline[kind]
        newrgb=np.clip(rgb*(1-mask[:,:,None])+np.clip(rgb*ratios,0,255)*mask[:,:,None],0,255).astype("uint8")
        new=Image.fromarray(newrgb,"RGB")
        targetdir=root/kind;targetdir.mkdir(parents=True,exist_ok=True)
        new.save(targetdir/(color+"_basecolor.png"),optimize=True)
        entries.append((color,new))
        outdoc=json.loads(json.dumps(doc))
        targetimg=io.BytesIO()
        new.save(targetimg,format="JPEG",quality=93,optimize=True,subsampling=0)
        data=bytearray(blob)
        data.extend(b'\0'*((-len(data))%4))
        pos=len(data);data.extend(targetimg.getvalue())
        outdoc["bufferViews"].append({"buffer":0,"byteOffset":pos,"byteLength":len(targetimg.getvalue())})
        outdoc["images"][baseid]["bufferView"]=len(outdoc["bufferViews"])-1
        outdoc["images"][baseid]["mimeType"]="image/jpeg"
        outdoc["images"][baseid]["name"]=kind+"_"+color+"_BaseColor"
        outdoc["materials"][0]["name"]=kind+" "+color+" / original PBR"
        path=targetdir/(kind+"_"+color+"_1k.glb")
        write_glb(outdoc,bytes(data),path)
        check,check_blob=parse_glb(path)
        assert check["meshes"]==doc["meshes"] and check["accessors"]==doc["accessors"]
        assert check_blob[:len(blob)]==blob,"Original GLB binary altered"
        assert check["materials"][0]["normalTexture"]==doc["materials"][0]["normalTexture"]
        assert (check["materials"][0]["pbrMetallicRoughness"]["metallicRoughnessTexture"]==
                doc["materials"][0]["pbrMetallicRoughness"]["metallicRoughnessTexture"])
        report["variants"][kind+"_"+color]={"file":str(path.relative_to(root)),
          "size_bytes":path.stat().st_size,"mask_mean":round(float(mask.mean()),3),
          "original_bin_sha256":hashlib.sha256(blob).hexdigest(),"geometry_unchanged":True,
          "original_normal_orm_retained":True}
        print("COLORWAY_GLTF_OK",kind,color,path.stat().st_size,flush=True)
    for ci,(label,im) in enumerate(entries):
        sheet.paste(im.resize((392,392),Image.Resampling.LANCZOS),(ci*420+15,ri*480+48))
        draw.text((ci*420+20,ri*480+20),kind+" "+label,fill=(240,240,240))
sheet.save(root/"atlas_contact_sheet.png")
(root/"variants_qa.json").write_text(json.dumps(report,ensure_ascii=False,indent=2))
print("VARIANT_LIBRARY_22_OK",len(report["variants"]),flush=True)
