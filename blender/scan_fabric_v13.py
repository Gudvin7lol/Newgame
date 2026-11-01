"""Download real CC0 scanned linen PBR textures from Poly Haven.
Source: https://polyhaven.com/a/rough_linen ; license CC0.
"""
from pathlib import Path
from urllib.request import urlretrieve
import json, os
from PIL import Image, ImageEnhance, ImageOps
import numpy as np

folder=Path(os.environ.get("BLENDER_OUT","out/blender")).resolve()/"scan_v13"
folder.mkdir(parents=True,exist_ok=True)
base="https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/rough_linen/"
maps={"diff":"rough_linen_diff_1k.jpg","nor_gl":"rough_linen_nor_gl_1k.jpg","rough":"rough_linen_rough_1k.jpg"}
for key,name in maps.items():
    out=folder/name
    print("GET",base+name,flush=True)
    urlretrieve(base+name,out)
    with Image.open(out) as im:
        im.verify()
    print("FILE_OK",name,out.stat().st_size,flush=True)
    assert out.stat().st_size>25000,"Unexpected tiny scan asset"
# Recolor only diffuse: retain photographed low-frequency color/brightness,
# but target warm beige rather than original blue.
rgb=np.asarray(Image.open(folder/maps["diff"]).convert("RGB")).astype(np.float32)/255.
luma=.2126*rgb[:,:,0]+.7152*rgb[:,:,1]+.0722*rgb[:,:,2]
mean=float(np.mean(luma))
r=np.clip((luma-mean)*.97+1.,.64,1.36)
warm=np.array([163,146,127],dtype=np.float32)
albedo=np.clip(warm[None,None,:]*r[:,:,None],0,255).astype(np.uint8)
Image.fromarray(albedo,"RGB").save(folder/"linen_scan_beige_basecolor.png",optimize=True)
Image.open(folder/maps["nor_gl"]).convert("RGB").save(folder/"linen_scan_normal_gl.png",optimize=True)
rough=np.asarray(Image.open(folder/maps["rough"]).convert("L")).astype(np.float32)/255.
# Preserve roughness variation, ensure no plastic gloss. This map uses actual scanned data.
rough=.80 + (rough-float(np.mean(rough)))*.48
rough=np.clip(rough,.66,.94)
Image.fromarray((rough*255).astype(np.uint8),"L").save(folder/"linen_scan_roughness.png",optimize=True)
mr=np.zeros((*rough.shape,4),dtype=np.uint8)
mr[:,:,0]=255;mr[:,:,1]=(rough*255).astype(np.uint8);mr[:,:,2]=0;mr[:,:,3]=255
Image.fromarray(mr,"RGBA").save(folder/"linen_scan_orm.png",optimize=True)
stats={"material":"Poly Haven Rough Linen, scanned PBR, warm natural beige calibration","license":"CC0","source":"https://polyhaven.com/a/rough_linen","texture_physical_height_m":0.3,
       "normal_source":"normal OpenGL","roughness_mean":round(float(np.mean(rough)),3),
       "resolution":Image.open(folder/"linen_scan_normal_gl.png").size}
(folder/"texture_report.json").write_text(json.dumps(stats,indent=2),encoding="utf-8")
print("SCAN_V13_OK",stats,flush=True)
