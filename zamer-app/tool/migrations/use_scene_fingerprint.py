from pathlib import Path

PATH = Path('zamer-app/lib/renderer3d/zamer_gpu_viewport.dart')
text = PATH.read_text(encoding='utf-8')

import_anchor = "import 'model_lod_policy.dart';\n"
import_line = "import 'scene_fingerprint.dart';\n"
if import_line not in text:
    if import_anchor not in text:
        raise SystemExit('model_lod_policy import anchor not found')
    text = text.replace(import_anchor, import_anchor + import_line, 1)

replacement = '  int _floorFingerprint() => ZamerSceneFingerprint.of(widget.floor);'
if replacement not in text:
    start_marker = '  int _floorFingerprint() {'
    end_marker = '\n\n  Future<void> _initialize()'
    start = text.find(start_marker)
    end = text.find(end_marker, start)
    if start < 0 or end < 0:
        raise SystemExit('floor fingerprint method anchors not found')
    text = text[:start] + replacement + text[end:]

PATH.write_text(text, encoding='utf-8')
print('Scene fingerprint integration applied.')
