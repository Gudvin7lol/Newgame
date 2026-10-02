from pathlib import Path

path = Path('zamer-app/lib/renderer3d/zamer_gpu_viewport.dart')
text = path.read_text(encoding='utf-8')


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'Missing expected source for {label}')
    text = text.replace(old, new, 1)


replace_once(
    "import 'model_lod_policy.dart';\n",
    "import 'model_lod_policy.dart';\nimport 'photo_render_quality_policy.dart';\n",
    'photo quality policy import',
)

replace_once(
    """    if (object.type == PlanObjectType.lighting) {
      _attachLightEmitter(root, object, importedModel: importedModel);
    }
""",
    """    if (object.type == PlanObjectType.lighting) {
      _attachLightEmitter(
        root,
        object,
        importedModel: importedModel,
        photoQuality: photoQuality,
      );
    }
""",
    'photo quality argument',
)

replace_once(
    """  void _attachLightEmitter(
    Node objectNode,
    ZamerObjectPlacement object, {
    required bool importedModel,
  }) {
""",
    """  void _attachLightEmitter(
    Node objectNode,
    ZamerObjectPlacement object, {
    required bool importedModel,
    required bool photoQuality,
  }) {
""",
    'light emitter signature',
)

replace_once(
    """    if (!widget.performanceMode) {
      lightNode.addComponent(
""",
    """    if (ZamerPhotoRenderQualityPolicy.useLocalLights(
      photoQuality: photoQuality,
      performanceMode: widget.performanceMode,
    )) {
      lightNode.addComponent(
""",
    'local light quality gate',
)

replace_once(
    """          segments: widget.performanceMode ? 10 : 16,
          rings: widget.performanceMode ? 6 : 10,
""",
    """          segments: ZamerPhotoRenderQualityPolicy.glowSegments(
            photoQuality: photoQuality,
            performanceMode: widget.performanceMode,
          ),
          rings: ZamerPhotoRenderQualityPolicy.glowRings(
            photoQuality: photoQuality,
            performanceMode: widget.performanceMode,
          ),
""",
    'fixture glow tessellation',
)

path.write_text(text, encoding='utf-8')
