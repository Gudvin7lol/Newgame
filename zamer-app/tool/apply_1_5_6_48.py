from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


pubspec = Path("pubspec.yaml")
pub = pubspec.read_text()
if "version: 1.5.6+48" in pub:
    print("1.5.6+48 source patch already applied")
    raise SystemExit(0)
if "version: 1.5.6+47" not in pub:
    raise SystemExit("unexpected app version; refusing automatic patch")

renderer_path = Path("lib/renderer3d/zamer_gpu_viewport.dart")
text = renderer_path.read_text()
text = replace_once(text, "      environmentIntensity: 0.90,\n      exposure: 1.0,", "      environmentIntensity: 0.82,\n      exposure: 0.94,", "interactive exposure")
text = replace_once(text, "    scene.environmentIntensity = 0.90;", "    scene.environmentIntensity = 0.82;", "interactive environment")
text = replace_once(text, "      intensity: 2.45,", "      intensity: 1.95,", "interactive sun")
text = replace_once(text, "      environmentIntensity: 1.15,\n      exposure: 1.06,", "      environmentIntensity: 0.92,\n      exposure: 0.94,", "photo exposure")
text = replace_once(text, "      brightness: 1.01,", "      brightness: 1.0,", "photo brightness")
text = replace_once(text, "      screenSpaceReflectionsIntensity: 0.55,", "      screenSpaceReflectionsIntensity: 0.38,", "photo SSR")
text = replace_once(text, "      bloomIntensity: 0.09,", "      bloomIntensity: 0.04,", "photo bloom")
text = replace_once(text, "      autoExposureStrength: 0.45,", "      autoExposureStrength: 0.28,", "auto exposure strength")
text = replace_once(text, "      autoExposureCompensation: 0.15,", "      autoExposureCompensation: -0.20,", "auto exposure compensation")
text = replace_once(text, "      autoExposureMaxEv: 1.8,", "      autoExposureMaxEv: 1.2,", "auto exposure max")
text = replace_once(text, "    scene.environmentIntensity = 1.15;", "    scene.environmentIntensity = 0.92;", "photo environment")
text = replace_once(text, "      intensity: 3.05,", "      intensity: 2.15,", "photo sun")
text = replace_once(
    text,
    "    final key = '${surface.materialMode}:${surface.materialId}';",
    "    final key = '${surface.materialMode}:${surface.materialId}:${surface.laminatePattern}:${surface.laminateOffsetMode}:${surface.tilePattern}';",
    "floor cache key",
)
text = replace_once(
    text,
    "    final tint = texture == null\n        ? _vectorColor(preset.color)\n        : vm.Vector4(0.98, 0.98, 0.98, 1);",
    "    final source = _vectorColor(preset.color);\n    final tint = texture == null\n        ? source\n        : vm.Vector4(\n            0.52 + source.x * 0.48,\n            0.52 + source.y * 0.48,\n            0.52 + source.z * 0.48,\n            1,\n          );",
    "floor texture tint",
)
text = replace_once(
    text,
    "    final key = '${nearest.materialMode}:${nearest.materialId}:under-wall';",
    "    final key = '${nearest.materialMode}:${nearest.materialId}:${nearest.laminatePattern}:${nearest.laminateOffsetMode}:${nearest.tilePattern}:under-wall';",
    "under-wall cache key",
)
text = replace_once(text, "        -object.rotationRad,", "        -object.rotationRad + (asset?.yawCorrectionRad ?? 0),", "object yaw correction")
old_light = """    final intensity = isWall
        ? 9.0
        : isFloor
        ? 7.0
        : isTrack
        ? 22.0
        : isPendant
        ? 28.0
        : isCeiling
        ? 20.0
        : 8.0;
    final range = isWall
        ? 5.0
        : isFloor
        ? 5.5
        : 9.5;"""
new_light = """    final intensity = isWall
        ? 5.0
        : isFloor
        ? 4.5
        : isTrack
        ? 10.0
        : isPendant
        ? 12.0
        : isCeiling
        ? 9.0
        : 5.0;
    final range = isWall
        ? 3.8
        : isFloor
        ? 4.5
        : 6.0;"""
text = replace_once(text, old_light, new_light, "fixture light energy")
text = replace_once(text, "      ..emissiveStrength = isWall ? 2.8 : 4.8;", "      ..emissiveStrength = isWall ? 1.8 : 2.6;", "fixture emissive")
renderer_path.write_text(text)

screen_path = Path("lib/screens/floor_3d_screen.dart")
screen = screen_path.read_text()
screen = replace_once(
    screen,
    "  Future<void> _showRenderSheet() async {\n    if (_rendering) return;\n    await showModalBottomSheet<void>(",
    "  Future<void> _showRenderSheet() async {\n    if (_rendering) return;\n    final size = MediaQuery.sizeOf(context);\n    final portrait = size.height >= size.width;\n    final hdWidth = portrait ? 1080 : 1920;\n    final hdHeight = portrait ? 1920 : 1080;\n    final twoKWidth = portrait ? 1440 : 2560;\n    final twoKHeight = portrait ? 2560 : 1440;\n    final fourKWidth = portrait ? 2160 : 3840;\n    final fourKHeight = portrait ? 3840 : 2160;\n    await showModalBottomSheet<void>(",
    "render orientation sizing",
)
screen = replace_once(screen, "subtitle: '1920 × 1080 • быстро',", "subtitle: '${hdWidth} × ${hdHeight} • быстро',", "HD subtitle")
screen = replace_once(screen, "_exportRender(width: 1920, height: 1080, label: 'HD');", "_exportRender(width: hdWidth, height: hdHeight, label: 'HD');", "HD dimensions")
screen = replace_once(screen, "subtitle: '2560 × 1440 • презентация',", "subtitle: '${twoKWidth} × ${twoKHeight} • презентация',", "2K subtitle")
screen = replace_once(screen, "_exportRender(width: 2560, height: 1440, label: '2K');", "_exportRender(width: twoKWidth, height: twoKHeight, label: '2K');", "2K dimensions")
screen = replace_once(screen, "subtitle: '3840 × 2160 • максимальное качество',", "subtitle: '${fourKWidth} × ${fourKHeight} • максимальное качество',", "4K subtitle")
screen = replace_once(screen, "_exportRender(width: 3840, height: 2160, label: '4K');", "_exportRender(width: fourKWidth, height: fourKHeight, label: '4K');", "4K dimensions")
screen_path.write_text(screen)

pubspec.write_text(pub.replace("version: 1.5.6+47", "version: 1.5.6+48", 1))
changelog = Path("CHANGELOG.md")
changelog.write_text(
    """## 1.5.6+48

- Исправлена ориентация направленной мебели в GPU 3D: кровати, диваны и кресла учитывают корректирующий yaw GLB без изменения угла объекта на плане.
- Напольные PBR-текстуры сильнее сохраняют цвет выбранного декора; кэш материалов учитывает схему раскладки и больше не смешивает разные варианты покрытия между помещениями.
- Снижены общий пересвет и локальные световые пятна от люстр/бра при сохранении AO, SSR и теней финального кадра.
- HD/2K/4K экспорт учитывает ориентацию экрана; в портретном режиме 4K создаётся как 2160×3840 вместо широкого кадра с огромными полями.

"""
    + changelog.read_text()
)
print("Applied guarded 1.5.6+48 visual patch")
