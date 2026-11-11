"""Query Poly Haven official CC0 model download metadata. No guessed asset URLs."""
import json, os, urllib.request
from pathlib import Path
out=Path(os.environ.get("ASSET_OUT","out/reference_chair"));out.mkdir(parents=True,exist_ok=True)
url="https://api.polyhaven.com/files/modern_arm_chair_01"
req=urllib.request.Request(url,headers={"User-Agent":"Zamer-Furniture-Lab/1.0 (GitHub Actions research)"})
with urllib.request.urlopen(req,timeout=45) as r: data=json.load(r)
(out/"polyhaven_manifest.json").write_text(json.dumps(data,indent=2),encoding="utf-8")
def browse(obj,prefix=""):
    if isinstance(obj,dict):
        if "url" in obj:
            print("ASSET",prefix, "size",obj.get("size"), "url",obj["url"], "dependencies",list(obj.get("include",{}))[:10],flush=True)
        else:
            for k,v in obj.items():browse(v,prefix+"/"+str(k))
browse(data)
print("ASSET_MANIFEST_OK",list(data.keys()),flush=True)
