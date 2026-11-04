"""Furniture Lab 2.1: licensed professional reference import from Poly Haven API.

Official glTF assets and every dependency are downloaded without guessing URLs.
Checks declared sizes and checksums when the API provides them.
"""
from pathlib import Path
from urllib.request import Request,urlopen
import hashlib,json,os,time

ROOT=Path(os.environ.get("FURNITURE21_OUT","out/furniture21")).resolve()
ROOT.mkdir(parents=True,exist_ok=True)
ASSETS={"sofa_01":"Sofa_01","drawer_cabinet":"drawer_cabinet"}
def load_url(uri):
    with urlopen(Request(uri,headers={"User-Agent":"Zamer-GLB-Lab/2.1 (Poly Haven CC0 research)"}),timeout=110) as r:
        return r.read()
def download(uri,path,record):
    path.parent.mkdir(parents=True,exist_ok=True)
    for attempt in range(4):
        try:
            contents=load_url(uri)
            if record.get("size") is not None:
                assert len(contents)==int(record["size"]),(uri,len(contents),record.get("size"))
            if record.get("md5"):
                assert hashlib.md5(contents).hexdigest().lower()==str(record["md5"]).lower(),"MD5 mismatch "+uri
            path.write_bytes(contents)
            print("DOWNLOAD_OK",path.name,len(contents),flush=True)
            return
        except Exception as e:
            print("DOWNLOAD_RETRY",attempt,str(e),flush=True)
            if attempt==3:raise
            time.sleep(2+attempt*2)
for key,asset in ASSETS.items():
    root=ROOT/key
    base=root/"source"
    base.mkdir(parents=True,exist_ok=True)
    files=json.loads(load_url("https://api.polyhaven.com/files/"+asset))
    assert "gltf" in files, "Asset has no glTF: "+asset
    resolution="2k" if "2k" in files["gltf"] else "1k"
    gltf_entry=files["gltf"][resolution]["gltf"]
    file_name=asset+"_"+resolution+".gltf"
    download(gltf_entry["url"],base/file_name,gltf_entry)
    dependencies=gltf_entry.get("include",{})
    for relative,rec in dependencies.items():
        rel=Path(relative)
        assert not rel.is_absolute() and ".." not in rel.parts
        download(rec["url"],base/rel,rec)
    doc=json.loads((base/file_name).read_text(encoding="utf-8"))
    for record in doc.get("images",[])+doc.get("buffers",[]):
        rel=record.get("uri")
        if rel and not rel.startswith("data:"):
            assert (base/rel).exists(),"Missing glTF dependent resource "+rel
    provenance={"id":asset,"slug":key,"source":"https://polyhaven.com/a/"+asset,
                "license":"CC0","downloaded_gltf_resolution":resolution,
                "file_name":file_name,
                "dependencies_verified":len(dependencies),
                "mesh_count":len(doc.get("meshes",[])),
                "materials":len(doc.get("materials",[])),
                "images":len(doc.get("images",[])),
                "geometry_origin":"Poly Haven official 3D model; not AI generated"}
    (root/"provenance.json").write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding="utf-8")
    print("PROFESSIONAL_REFERENCE_OK",json.dumps(provenance),flush=True)
