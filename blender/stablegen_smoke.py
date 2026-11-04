"""StableGen compatibility smoke test without a GPU or ComfyUI.
Run inside portable Blender 4.5 LTS with the official Linux add-on ZIP installed.
This script only verifies addon registration; it does NOT run AI inference.
"""
import bpy
import importlib
import json
import os
import sys
from pathlib import Path

print("BLENDER_VERSION", bpy.app.version_string)
assert (4, 2, 0) <= bpy.app.version < (5, 0, 0), "Unexpected Blender version"
print("ADDON_INSTALL_REPO", bpy.utils.user_resource("EXTENSIONS"))
mods=("bl_ext.user_default.stablegen", "stablegen")
selected=None
errors={}
for module_name in mods:
    try:
        bpy.ops.preferences.addon_enable(module=module_name)
        if module_name not in bpy.context.preferences.addons:
            raise RuntimeError("Addon operator did not register module")
        selected=module_name
        print("STABLEGEN_REGISTERED",module_name)
        break
    except Exception as exc:
        errors[module_name]=repr(exc)
        print("STABLEGEN_PROBE_FAILED",module_name,repr(exc))
assert selected is not None, "StableGen did not register: "+str(errors)
addon=importlib.import_module(selected)
print("STABLEGEN_VERSION",getattr(addon,"bl_info",{}).get("version"))
print("COMFYUI_INFERENCE", "NOT_RUN_NO_GPU_OR_SERVER")
out=Path(os.environ.get("SMOKE_OUT","out/stablegen"))
out.mkdir(parents=True,exist_ok=True)
(out/"compatibility.json").write_text(json.dumps({
 "blender":bpy.app.version_string,
 "addon":selected,
 "addon_version":getattr(addon,"bl_info",{}).get("version"),
 "registered":True,
 "comfyui_inference_tested":False,
 "gpu_inference_tested":False,
},ensure_ascii=False,indent=2,default=str),encoding="utf-8")
print("STABLEGEN_SMOKE_OK")
