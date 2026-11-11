"""Download official CC0 Poly Haven Modern Arm Chair from files API.

All glTF dependencies are resolved by their ORIGINAL manifest paths and
checked using their official size / MD5. We do not scrape third-party GLBs.
"""
import hashlib,json,os,time,urllib.request
from pathlib import Path

root=Path(os.environ.get("CHAIR_OUT","out/reference_chair")).resolve()
src=root/"source"
src.mkdir(parents=True,exist_ok=True)
UA="Zamer-Furniture-Reference-Lab/1.0 (Poly Haven API)"
def api_json(url):
    with urllib.request.urlopen(urllib.request.Request(url,headers={"User-Agent":UA}),timeout=60) as resp:
        return json.load(resp)
def save(url,path,expected):
    path.parent.mkdir(parents=True,exist_ok=True)
    for attempt in range(4):
        try:
            data=urllib.request.urlopen(urllib.request.Request(url,headers={"User-Agent":UA}),timeout=80).read()
            expected_size=expected.get("size")
            if expected_size is not None and len(data)!=expected_size:
                raise ValueError(f"Wrong size {len(data)} vs {expected_size}")
            expected_md5=expected.get("md5")
            if expected_md5 and hashlib.md5(data).hexdigest().lower()!=expected_md5.lower():
                raise ValueError(f"MD5 mismatch for {path}")
            path.write_bytes(data)
            print("OFFICIAL_ASSET_VERIFIED",str(path.relative_to(root)),len(data),flush=True)
            return
        except Exception as ex:
            print("DOWNLOAD_ATTEMPT_FAILED",attempt,str(ex),flush=True)
            if attempt==3:raise
            time.sleep(2+attempt*2)
manifest=api_json("https://api.polyhaven.com/files/modern_arm_chair_01")
(root/"polyhaven_manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
entry=manifest["gltf"]["2k"]["gltf"]
path=src/"modern_arm_chair_01_2k.gltf"
save(entry["url"],path,entry)
for name,record in entry["include"].items():
    if ".." in Path(name).parts or Path(name).is_absolute():
        raise ValueError("Unsafe referenced path")
    save(record["url"],src/name,record)
gltf=json.loads(path.read_text(encoding="utf-8"))
for buffer in gltf.get("buffers",[]):
    uri=buffer.get("uri","")
    assert uri and (src/uri).is_file(),"Missing glTF binary "+uri
for im in gltf.get("images",[]):
    uri=im.get("uri","")
    assert uri and (src/uri).is_file(),"Missing glTF image "+uri
report={
    "asset_id":"modern_arm_chair_01",
    "source":"https://polyhaven.com/a/modern_arm_chair_01",
    "license":"CC0",
    "attribution_for_live_API":"Powered by Poly Haven",
    "source_resolution":"2k",
    "download_verified_md5":True,
    "dependency_count":len(entry["include"]),
    "gltf_meshes":len(gltf.get("meshes",[])),
    "gltf_materials":len(gltf.get("materials",[])),
    "gltf_images":len(gltf.get("images",[])),
    "ai_generated_comparison":False,
}
(root/"source_provenance.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print("OFFICIAL_MODEL_DOWNLOADED",report,flush=True)
