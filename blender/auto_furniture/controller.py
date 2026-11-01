#!/usr/bin/env python3
"""Automatic Blender asset trial planner and quality gate.

No paid APIs, no ungrounded claims of photorealism.
Scores are measurable technical proxies; aesthetic review remains separate.
Previous best candidate is persisted across GitHub runs via Actions cache.
"""
import argparse, json, math, shutil, struct, statistics
from pathlib import Path
from PIL import Image, ImageStat, ImageFilter, ImageDraw, ImageFont

DEFAULT={"normal_strength":0.75, "texture_tile_m":0.30, "shape_looseness":1.0, "best_score":None,
         "successful_runs":0, "history":[]}
LABELS=("low", "reference", "high")

def load_state(path):
    if not path.exists():return dict(DEFAULT)
    try:
        state=json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(state,dict):return dict(DEFAULT)
        return {**DEFAULT,**state}
    except (ValueError,OSError):
        return dict(DEFAULT)

def plan(root,statefile):
    root.mkdir(parents=True,exist_ok=True)
    state=load_state(statefile)
    normal=max(0.40,min(1.20,float(state["normal_strength"])))
    tile=max(0.18,min(0.45,float(state["texture_tile_m"])))
    softness=max(.75,min(1.25,float(state.get("shape_looseness",1.0))))
    # Search actual shape differences, not tiny imperceptible PBR tweaks.
    trials=[
        ("low",round(normal,3),round(tile,3),round(max(.55,softness-.28),3)),
        ("reference",round(normal,3),round(tile,3),round(softness,3)),
        ("high",round(normal,3),round(tile,3),round(min(1.65,softness+.28),3))
    ]
    (root/"plan.tsv").write_text("\n".join(f"{name} {n} {t} {sh}" for name,n,t,sh in trials)+"\n",encoding="utf-8")
    (root/"plan.json").write_text(json.dumps({
        "baseline":state,"trials":[{"name":x,"normal_strength":y,"texture_tile_m":z,"shape_looseness":sh}
          for x,y,z,sh in trials]},indent=2),encoding="utf-8")
    print("TRIAL_PLAN",trials)

def glb_check(path):
    buf=path.read_bytes()
    assert len(buf)>20 and buf[:4]==b"glTF","Invalid GLB magic"
    version,length=struct.unpack_from("<II",buf,4)
    assert version==2 and length==len(buf),"Invalid GLB version or length"
    jlen,jkind=struct.unpack_from("<II",buf,12)
    assert jkind==0x4E4F534A,"Missing JSON chunk"
    data=json.loads(buf[20:20+jlen])
    assert len(data.get("meshes",[]))>=2,"Missing cushion shell and piping"
    assert len(data.get("images",[]))>=3,"Insufficient embedded textures"
    textures=data.get("textures",[])
    found=[]
    for m in data.get("materials",[]):
        p=m.get("pbrMetallicRoughness",{})
        if not all((p.get("baseColorTexture"),p.get("metallicRoughnessTexture"),
                    m.get("normalTexture"))):continue
        scale=float(m["normalTexture"].get("scale",1))
        assert 0.35<=scale<=1.25,"Bad normal map scale"
        for tex in (p["baseColorTexture"],p["metallicRoughnessTexture"],m["normalTexture"]):
            idx=tex["index"]
            assert 0<=idx<len(textures),"Texture index invalid"
        assert "TEXCOORD_0" in data.get("accessors",{}) or any(
            "TEXCOORD_0" in pr.get("attributes",{})
            for me in data["meshes"] for pr in me.get("primitives",[])), "No UV0"
        found.append((m.get("name",""),scale))
    assert found,"No fully mapped PBR material"
    return {"meshes":len(data["meshes"]),"embedded_images":len(data["images"]),
            "pbr_materials":found,"file_bytes":len(buf)}

def image_check(path):
    with Image.open(path) as im:
        im.load()
        assert im.width>=600 and im.height>=450,"Preview too small"
        # Judge central region to reduce the background's effect.
        x0,y0=int(im.width*.16),int(im.height*.16)
        x1,y1=int(im.width*.84),int(im.height*.86)
        crop=im.convert("RGB").crop((x0,y0,x1,y1))
        gray=crop.convert("L")
        stat=ImageStat.Stat(gray)
        mean=stat.mean[0];contrast=stat.stddev[0]
        hist=gray.histogram()
        total=sum(hist)
        blown=sum(hist[245:])/total
        crushed=sum(hist[:13])/total
        # Tiny sensor detail and fiber contrast without rewarding extreme sharpened edges.
        small=crop.resize((240,170),Image.Resampling.BICUBIC)
        edges=ImageStat.Stat(small.convert("L").filter(ImageFilter.FIND_EDGES())).mean[0]
        assert math.isfinite(mean+contrast+edges)
        # Weak perceptual heuristic. No claim of photorealism.
        score=100.0
        score-=min(35.,blown*210.)
        score-=min(25.,crushed*85.)
        score-=min(25.,abs(mean-128.)*.18)
        score-=min(15.,abs(contrast-48.)*.25)
        score-=min(12.,abs(edges-17.)*.4)
        return {"mean_luma":round(mean,2),"contrast":round(contrast,2),
                "highlight_clipping_ratio":round(blown,5),
                "shadow_clipping_ratio":round(crushed,5),
                "edge_proxy":round(edges,2),
                "technical_score":round(max(0.,score),2)}

def check_scans(root):
    scan=root/"scan_v13"
    for name in ("linen_scan_beige_basecolor.png","linen_scan_normal_gl.png",
                 "linen_scan_roughness.png","linen_scan_orm.png"):
        img=scan/name
        assert img.is_file(),f"Missing source texture: {img}"
        with Image.open(img) as im:
            assert min(im.size)>=1024,f"Source {name} too low-resolution"
            if name.endswith("normal_gl.png"):
                rgb=im.convert("RGB")
                st=ImageStat.Stat(rgb)
                assert st.stddev[0]>3 and st.stddev[1]>3,"Normal is almost flat"
            if name.endswith("_roughness.png"):
                s=ImageStat.Stat(im.convert("L"))
                assert s.stddev[0]>2,"Roughness lacks variation"

def rank(root,statefile):
    check_scans(root)
    planfile=json.loads((root/"plan.json").read_text(encoding="utf-8"))
    results=[]
    for trial in planfile["trials"]:
        name=trial["name"]
        folder=root/name
        record={"name":name,**{k:trial[k] for k in ("normal_strength","texture_tile_m","shape_looseness")}}
        try:
            for f in ("cushion_v14.blend","cushion_v14.glb","cushion_v14_cycles.png","cushion_v14_detail.png"):
                assert (folder/f).is_file(),f"Missing file {f}"
            record["gltf"]=glb_check(folder/"cushion_v14.glb")
            record["beauty"]=image_check(folder/"cushion_v14_cycles.png")
            record["detail"]=image_check(folder/"cushion_v14_detail.png")
            record["technical_score"]=round(
                .55*record["beauty"]["technical_score"]+
                .45*record["detail"]["technical_score"],2)
            record["passed"]=True
        except Exception as exc:
            record.update(passed=False,error=str(exc),technical_score=-1)
        results.append(record)
        print("QUALITY",name,"PASS" if record["passed"] else "FAIL",record["technical_score"])
    passing=[x for x in results if x["passed"]]
    report={"purpose":"technical asset validation; NOT automatic proof of photorealism",
            "manual_visual_review_required":True,
            "source_material":"Poly Haven Rough Linen CC0",
            "trials":results,
            "winner":max(passing,key=lambda x:x["technical_score"])["name"] if passing else None}
    (root/"quality_report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
    if not passing:
        raise RuntimeError("All model candidates failed structural/PBR checks")
    raw_best=max(passing,key=lambda x:x["technical_score"])
    raw_worst=min(passing,key=lambda x:x["technical_score"])
    significance=raw_best["technical_score"]-raw_worst["technical_score"]
    # Do not pretend to learn from hundredths of a point of clipping noise.
    centre=next((x for x in passing if x["name"]=="reference"),raw_best)
    winner=raw_best if significance>=1.5 else centre
    report["technical_difference_points"]=round(significance,2)
    report["selection_reason"]=(
        "technical-score margin >=1.5; still requires visual review"
        if significance>=1.5 else
        "score differences too small; keep reference geometry, visual review required")
    report["winner"]=winner["name"]
    (root/"quality_report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
    wdir=root/winner["name"]
    for src,dst in (("cushion_v14.glb","best_furniture.glb"),
                    ("cushion_v14.blend","best_furniture.blend"),
                    ("cushion_v14_cycles.png","best_render.png"),
                    ("cushion_v14_detail.png","best_detail.png")):
        shutil.copyfile(wdir/src,root/dst)
    # Contact sheet consists ONLY of Blender Cycles renders, never AI imagery.
    tw,th=480,360
    board=Image.new("RGB",(3*tw,th+60),(32,34,37))
    draw=ImageDraw.Draw(board)
    for i,entry in enumerate(results):
        im=Image.open(root/entry["name"]/"cushion_v14_cycles.png").convert("RGB")
        im.thumbnail((tw,th))
        bg=Image.new("RGB",(tw,th),(20,22,25))
        bg.paste(im,((tw-im.width)//2,(th-im.height)//2))
        board.paste(bg,(i*tw,60))
        title=f'{entry["name"]} | {entry["technical_score"]:.1f}'
        draw.text((i*tw+16,18),title,fill=(245,245,245))
    board.save(root/"candidates_comparison.png")
    old=load_state(statefile)
    oldscore=old.get("best_score")
    # Persist improvements in technical proxy, not a claim of artistic learning.
    if oldscore is None or (significance>=1.5 and winner["technical_score"]>float(oldscore)+1.5):
        old["normal_strength"]=winner["normal_strength"]
        old["texture_tile_m"]=winner["texture_tile_m"]
        old["shape_looseness"]=winner["shape_looseness"]
        old["best_score"]=winner["technical_score"]
    old["successful_runs"]=int(old.get("successful_runs",0))+1
    old["history"]=(old.get("history",[])+[{"winner":winner["name"],
              "score":winner["technical_score"],
              "source":"technical renderer metrics"}])[-12:]
    statefile.parent.mkdir(parents=True,exist_ok=True)
    statefile.write_text(json.dumps(old,indent=2),encoding="utf-8")
    summary=[
        "# Automated Furniture Lab: technical QA",
        "",
        "This workflow produces actual Blender mesh/material/GLB assets, not AI-rendered illustrations.",
        "**It does not assert photorealism**. Visual evaluation on Android is still necessary.",
        "",
        "| Trial | Shape softness | Normal | UV tile (m) | Technical score | Result |",
        "|---|---:|---:|---:|---:|---|",
    ]
    for x in results:
        summary.append(f'| {x["name"]} | {x["shape_looseness"]} | {x["normal_strength"]} | {x["texture_tile_m"]} | {x["technical_score"]} | {"PASS" if x["passed"] else x.get("error","FAIL")} |')
    summary+=["",f'Chosen technical baseline: **{winner["name"]}**.',
              f'Selection reason: {report["selection_reason"]}.',
              "Quality score covers lighting/clipping/contrast and valid PBR structure, not upholstery realism.",
              "A good score cannot prove lifelike geometry, believable wrinkles, or correct fabric scale.",
              "Settings are carried to the next CI run using cache. Aesthetic user feedback must override this proxy."]
    (root/"quality_report.md").write_text("\n".join(summary)+"\n",encoding="utf-8")
    print("BEST_TECHNICAL_CANDIDATE",winner["name"],winner["technical_score"])

if __name__=="__main__":
    ap=argparse.ArgumentParser()
    ap.add_argument("command",choices=("plan","rank"))
    ap.add_argument("--root",type=Path,default=Path("out/auto"))
    ap.add_argument("--state",type=Path,default=Path("blender/auto_furniture/state.json"))
    args=ap.parse_args()
    (plan if args.command=="plan" else rank)(args.root,args.state)
