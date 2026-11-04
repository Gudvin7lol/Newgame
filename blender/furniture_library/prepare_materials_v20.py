"""Prepare two real CC0 scanned PBR materials for automated furniture models.
Sources: Poly Haven Rough Linen (cloth), Oak Veneer 01 (wood).
No procedural fake woven grid; preserve natural scanned albedo/normal variation.
"""
import os,json,time
from pathlib import Path
from urllib.request import urlretrieve
from PIL import Image, ImageStat
import numpy as np
OUT=Path(os.environ.get("FURNITURE_OUT","out/furniture20")).resolve()
OUT.mkdir(parents=True,exist_ok=True)
source={
 "linen":("rough_linen",0.30),
 "oak":("oak_veneer_01",1.80),
}
for kind,(slug,physical_m) in source.items():
    folder=OUT/kind
    folder.mkdir(parents=True,exist_ok=True)
    stem=f"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/{slug}/{slug}_"
    files={"base":"diff_1k.jpg","normal":"nor_gl_1k.jpg","rough":"rough_1k.jpg"}
    for k,suffix in files.items():
        target=folder/(slug+"_"+suffix)
        for attempt in range(3):
            try:
                urlretrieve(stem+suffix,target)
                with Image.open(target) as im:
                    im.verify()
                assert target.stat().st_size>15000,"Download missing/too small"
                break
            except Exception as exc:
                print("DOWNLOAD_RETRY",kind,k,attempt,str(exc),flush=True)
                if attempt==2:raise
                time.sleep(1.5)
        print("SCAN_OK",kind,k,target.stat().st_size,flush=True)
    diffuse=Image.open(folder/(slug+"_diff_1k.jpg")).convert("RGB")
    normal=Image.open(folder/(slug+"_nor_gl_1k.jpg")).convert("RGB")
    rawrough=Image.open(folder/(slug+"_rough_1k.jpg")).convert("L")
    d=np.asarray(diffuse,dtype=np.float32)
    if kind=="linen":
        # Keep scanned spatial detail but recolor original blue-ish albedo to warm grey.
        lum=(d[:,:,0]*.2126+d[:,:,1]*.7152+d[:,:,2]*.0722)/255.
        mean=float(lum.mean())
        brightness=np.clip(1.+(lum-mean)*1.12,.66,1.35)
        base=np.clip(brightness[:,:,None]*np.array([167,151,131],dtype=np.float32),0,255).astype(np.uint8)
    else:
        base=np.asarray(diffuse,dtype=np.uint8)
    Image.fromarray(base,"RGB").save(folder/"basecolor.png",optimize=True)
    normal.save(folder/"normal.png",optimize=True)
    rough=np.asarray(rawrough,dtype=np.float32)/255.
    if kind=="linen":
        rough=np.clip(.79+(rough-float(rough.mean()))*.45,.66,.94)
    else:
        rough=np.clip(.66+(rough-float(rough.mean()))*.65,.43,.89)
    Image.fromarray((rough*255).astype(np.uint8),"L").save(folder/"roughness.png",optimize=True)
    orm=np.zeros((*rough.shape,4),dtype=np.uint8)
    orm[:,:,0]=255;orm[:,:,1]=(rough*255).astype(np.uint8);orm[:,:,2]=0;orm[:,:,3]=255
    Image.fromarray(orm,"RGBA").save(folder/"orm.png",optimize=True)
    report={"name":slug,"source":f"https://polyhaven.com/a/{slug}","license":"CC0",
            "scan_physical_width_m":physical_m,"normal":"OpenGL","orm_channels":"R=AO G=roughness B=metallic",
            "resolution":diffuse.size,
            "roughness_mean":float(rough.mean()),
            "normal_std":ImageStat.Stat(normal).stddev}
    (folder/"material.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    print("MATERIAL_READY",kind,report,flush=True)
