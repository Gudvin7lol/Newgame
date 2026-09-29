from pathlib import Path

path = Path(__file__).resolve().parents[1] / 'zamer-app/lib/renderer3d/zamer_scene_geometry.dart'
text = path.read_text()
old = "            tileMirrored: settings.wallTileMirroredFor(runId),\n            groutMm: settings.wallTileGroutMm,"
new = "          tileMirrored: settings.wallTileMirroredFor(runId),\n          groutMm: settings.wallTileGroutMm,"
if old in text:
    text = text.replace(old, new, 1)
    path.write_text(text)
    print('Normalized fallback wall-finish indentation for guarded +50 patch')
else:
    print('Fallback wall-finish indentation already normalized or +50 already applied')
