"""Furniture Lab 2.1 GLB / topology / mobile PBR audit.

Only proves structural and material linkage, not perceptual photorealism.
"""
import json,struct,os
from pathlib import Path
from PIL import Image,ImageStat
ROOT=Path(os.environ.get("FURNITURE21_OUT","out/furniture21")).resolve()
MODELS=("sofa_01","drawer_cabinet")
TIERS=("reference_2k","mobile_1k","lite_512")
FORBIDDEN={"KHR_draco_mesh_compression","EXT_meshopt_compression",
           "EXT_texture_webp","KHR_texture_basisu"}
def read_glb(path):
    blob=path.read_bytes()
    assert blob[:4]==b"glTF" and struct.unpack_from("<I",blob,8)[0]==len(blob),(path,"invalid GLB")
    length,kind=struct.unpack_from("<II",blob,12)
    assert kind==0x4E4F534A
    return json.loads(blob[20:20+length]),len(blob)
def signature(doc):
    sig=[]
    for mesh in doc["meshes"]:
        for p in mesh["primitives"]:
            acc=doc["accessors"][p["attributes"]["POSITION"]]
            idx=doc["accessors"][p["indices"]] if "indices" in p else None
            sig.append((acc["count"],idx["count"] if idx else 0,p.get("mode",4),
                        tuple(round(float(v),4) for v in acc.get("min",[])),
                        tuple(round(float(v),4) for v in acc.get("max",[]))))
    return sorted(sig)
result={}
for name in MODELS:
    folder=ROOT/name
    data={};original=None
    for tier in TIERS:
        doc,bytecount=read_glb(folder/(name+"_"+tier+".glb"))
        sig=signature(doc)
        if original is None:original=sig
        assert original==sig,(name,tier,"changed geometry")
        assert len(doc.get("meshes",[]))>=1 and len(doc.get("images",[]))>=2
        assert not set(doc.get("extensionsRequired",[])) & FORBIDDEN
        assert all("POSITION" in p["attributes"] for m in doc["meshes"] for p in m["primitives"])
        base=[m for m in doc.get("materials",[]) if m.get("pbrMetallicRoughness",{}).get("baseColorTexture")]
        assert base,(name,tier,"no base color map")
        rich=[m for m in base if m.get("normalTexture") and m["pbrMetallicRoughness"].get("metallicRoughnessTexture")]
        data[tier]={"bytes":bytecount,"meshes":len(doc["meshes"]),
                    "materials":len(doc.get("materials",[])),"images":len(doc["images"]),
                    "base_color_materials":len(base),"fully_mapped_PBR":len(rich),
                    "primitive_count":len(sig),
                    "vertex_count":sum(x[0] for x in sig),
                    "triangles":sum(x[1]//3 if x[1] else x[0]//3 for x in sig)}
        print("GLB_QA_OK",name,tier,data[tier],flush=True)
    assert data["mobile_1k"]["bytes"]<data["reference_2k"]["bytes"],name
    assert data["lite_512"]["bytes"]<=data["mobile_1k"]["bytes"],name
    for image in ("cycles_review.png","cycles_back.png"):
        with Image.open(folder/image) as im:
            assert im.width>=600 and im.height>=400,(name,image)
            assert ImageStat.Stat(im.convert("L")).stddev[0]>9,(name,"blank preview")
    provenance=json.loads((folder/"provenance.json").read_text(encoding="utf-8"))
    assert provenance["license"]=="CC0"
    data["savings_1k_pct"]=round(100*(1-data["mobile_1k"]["bytes"]/data["reference_2k"]["bytes"]),1)
    data["provenance"]=provenance
    result[name]=data
summary={"pipeline":"Furniture Lab 2.1",
    "geometry":"Official Poly Haven source, not model-generated",
    "license":"CC0","image_to_3d_tested":False,"android_viewer_verified":False,
    "photorealism_verified":False,"models":result}
(ROOT/"comparison_qa.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding="utf-8")
lines=["# Furniture Lab 2.1","",
       "2K source, 1K Mobile and 512 Lite preserve geometry, UVs and PBR material links.",
       "These tests do not establish visual realism in Android GLB Viewer.","",
       "| Asset | 2K MiB | 1K MiB | 512 MiB | Reduction 1K | Triangles |",
       "|---|---:|---:|---:|---:|---:|"]
for name,data in result.items():
    lines.append("| {} | {:.2f} | {:.2f} | {:.2f} | {}% | {} |".format(name,
        *(data[t]["bytes"]/1048576 for t in TIERS),
        data["savings_1k_pct"],data["reference_2k"]["triangles"]))
(ROOT/"comparison_qa.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
print("FURNITURE_21_FINAL_QA_OK",json.dumps({k:v["savings_1k_pct"] for k,v in result.items()}),flush=True)
