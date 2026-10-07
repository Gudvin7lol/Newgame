from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCENE = ROOT / "lib" / "renderer3d" / "zamer_gpu_viewport.dart"

text = SCENE.read_text(encoding="utf-8")

old_floor = "vm.Vector3(_mx(point.x, bounds), 0.006, _mz(point.y, bounds))"
new_floor = "vm.Vector3(\n            _mx(point.x, bounds),\n            zamerFloorSurfaceYM,\n            _mz(point.y, bounds),\n          )"

if old_floor in text:
    text = text.replace(old_floor, new_floor, 1)
elif "zamerFloorSurfaceYM" not in text:
    raise SystemExit("floor grout migration: base floor elevation anchor not found")

old_grout = "vm.Vector3(_mx(point.x, bounds), 0.0068, _mz(point.y, bounds))"
new_grout = "vm.Vector3(\n              _mx(point.x, bounds),\n              zamerFloorGroutYM,\n              _mz(point.y, bounds),\n            )"

if old_grout in text:
    text = text.replace(old_grout, new_grout, 1)
elif "zamerFloorGroutYM" not in text:
    raise SystemExit("floor grout migration: grout elevation anchor not found")

SCENE.write_text(text, encoding="utf-8")
print("floor/grout render depth policy integrated")
