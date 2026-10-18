#!/usr/bin/env python3
"""Validate the actual embedded GLES shaders, failing before Android packaging."""
import pathlib
import re
import subprocess
import tempfile
source = pathlib.Path("zamer-native/app/src/main/cpp/native_renderer.cpp").read_text()
shaders = re.findall(r'const char\*\s+\w+Shader\s*=\s*R"shader\((.*?)\)shader";', source, re.S)
assert len(shaders) == 2, f"Expected 2 shaders, found {len(shaders)}"
for code, stage in zip(shaders, ("vert", "frag")):
    with tempfile.TemporaryDirectory() as tmp:
        path = pathlib.Path(tmp) / f"native.{stage}"
        path.write_text(code)
        result = subprocess.run(["glslangValidator", "-S", stage, str(path)], text=True, capture_output=True)
        if result.returncode != 0:
            raise SystemExit(f"Invalid GLSL {stage}:\n{result.stdout}\n{result.stderr}")
        print(f"GLSL {stage} syntax validated")
