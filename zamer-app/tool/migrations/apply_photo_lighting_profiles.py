#!/usr/bin/env python3
"""Wire Photo Studio time-of-day and HDR controls into the live GPU renderer."""

from pathlib import Path

APP = Path(__file__).resolve().parents[2]
GPU = APP / 'lib' / 'renderer3d' / 'zamer_gpu_viewport.dart'
PHOTO = APP / 'lib' / 'screens' / 'photo_studio_screen.dart'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        if new in text:
            return text
        raise RuntimeError(f'could not locate {label}')
    if text.count(old) != 1:
        raise RuntimeError(f'expected one {label}, found {text.count(old)}')
    return text.replace(old, new, 1)


def patch_gpu() -> None:
    text = GPU.read_text(encoding='utf-8')

    enum_anchor = """/// GPU-backed 3D viewport for Zamер.\n"""
    enum_block = """enum ZamerPhotoTime { day, sunset, evening, night }\n\nclass ZamerPhotoLightingProfile {\n  const ZamerPhotoLightingProfile({\n    required this.environmentIntensity,\n    required this.exposure,\n    required this.temperature,\n    required this.saturation,\n    required this.lightDirection,\n    required this.lightColor,\n    required this.lightIntensity,\n    required this.backgroundTop,\n    required this.backgroundBottom,\n  });\n\n  final double environmentIntensity;\n  final double exposure;\n  final double temperature;\n  final double saturation;\n  final vm.Vector3 lightDirection;\n  final vm.Vector3 lightColor;\n  final double lightIntensity;\n  final Color backgroundTop;\n  final Color backgroundBottom;\n}\n\nZamerPhotoLightingProfile zamerPhotoLightingProfile(ZamerPhotoTime time) {\n  return switch (time) {\n    ZamerPhotoTime.day => ZamerPhotoLightingProfile(\n        environmentIntensity: 0.92,\n        exposure: 0.94,\n        temperature: 0.025,\n        saturation: 1.025,\n        lightDirection: vm.Vector3(-0.38, -1.0, -0.28),\n        lightColor: vm.Vector3(1.0, 0.965, 0.90),\n        lightIntensity: 2.15,\n        backgroundTop: const Color(0xFFEAF1F5),\n        backgroundBottom: const Color(0xFFF7F4EE),\n      ),\n    ZamerPhotoTime.sunset => ZamerPhotoLightingProfile(\n        environmentIntensity: 0.66,\n        exposure: 0.90,\n        temperature: 0.18,\n        saturation: 1.08,\n        lightDirection: vm.Vector3(-0.82, -0.46, -0.18),\n        lightColor: vm.Vector3(1.0, 0.66, 0.40),\n        lightIntensity: 1.72,\n        backgroundTop: const Color(0xFF8FA6C3),\n        backgroundBottom: const Color(0xFFF1B27E),\n      ),\n    ZamerPhotoTime.evening => ZamerPhotoLightingProfile(\n        environmentIntensity: 0.38,\n        exposure: 0.84,\n        temperature: -0.07,\n        saturation: 1.04,\n        lightDirection: vm.Vector3(-0.34, -0.82, -0.46),\n        lightColor: vm.Vector3(0.72, 0.82, 1.0),\n        lightIntensity: 0.82,\n        backgroundTop: const Color(0xFF52627A),\n        backgroundBottom: const Color(0xFF9A887D),\n      ),\n    ZamerPhotoTime.night => ZamerPhotoLightingProfile(\n        environmentIntensity: 0.16,\n        exposure: 0.76,\n        temperature: -0.16,\n        saturation: 0.96,\n        lightDirection: vm.Vector3(-0.22, -0.74, -0.58),\n        lightColor: vm.Vector3(0.46, 0.60, 1.0),\n        lightIntensity: 0.34,\n        backgroundTop: const Color(0xFF111827),\n        backgroundBottom: const Color(0xFF26354D),\n      ),\n  };\n}\n\n/// GPU-backed 3D viewport for Zamер.\n"""
    text = replace_once(text, enum_anchor, enum_block, 'photo lighting enum')

    text = replace_once(
        text,
        """    required this.walkY,\n    this.performanceMode = false,\n  });\n""",
        """    required this.walkY,\n    this.performanceMode = false,\n    this.photoPreview = false,\n    this.photoTime = ZamerPhotoTime.day,\n    this.photoHdr = true,\n  });\n""",
        'photo viewport constructor',
    )
    text = replace_once(
        text,
        """  final double walkY;\n  final bool performanceMode;\n\n  @override\n""",
        """  final double walkY;\n  final bool performanceMode;\n  final bool photoPreview;\n  final ZamerPhotoTime photoTime;\n  final bool photoHdr;\n\n  @override\n""",
        'photo viewport fields',
    )

    text = replace_once(
        text,
        """    final performanceChanged =\n        oldWidget.performanceMode != widget.performanceMode;\n    if (performanceChanged) _configureScene();\n    if (!identical(oldWidget.floor, widget.floor) ||\n        fingerprint != _lastFloorFingerprint ||\n        performanceChanged) {\n""",
        """    final performanceChanged =\n        oldWidget.performanceMode != widget.performanceMode;\n    final photoLightingChanged =\n        oldWidget.photoPreview != widget.photoPreview ||\n        oldWidget.photoTime != widget.photoTime ||\n        oldWidget.photoHdr != widget.photoHdr;\n    if (performanceChanged || photoLightingChanged) _configureScene();\n    if (!identical(oldWidget.floor, widget.floor) ||\n        fingerprint != _lastFloorFingerprint ||\n        performanceChanged) {\n""",
        'photo lighting update trigger',
    )

    text = replace_once(
        text,
        """  void _configureScene() {\n    final scene = _scene;\n    if (scene == null) return;\n    final performance = widget.performanceMode;\n""",
        """  void _configureScene() {\n    final scene = _scene;\n    if (scene == null) return;\n    if (widget.photoPreview) {\n      _configurePhotoLighting(exportQuality: false);\n      return;\n    }\n    final performance = widget.performanceMode;\n""",
        'photo preview scene switch',
    )

    start = text.index('  void _configurePhotoLighting() {')
    end = text.index('  Future<void> _loadFinishTextures()', start)
    old_photo = text[start:end]
    new_photo = """  void _configurePhotoLighting({required bool exportQuality}) {\n    final scene = _scene;\n    if (scene == null) return;\n    final profile = zamerPhotoLightingProfile(widget.photoTime);\n    final hdr = widget.photoHdr;\n    final nightBoost = widget.photoTime == ZamerPhotoTime.night ? 0.16 : 0.0;\n    scene.environmentSettings = EnvironmentSettings(\n      toneMapping: ToneMappingMode.pbrNeutral,\n      environmentIntensity: profile.environmentIntensity,\n      exposure: profile.exposure,\n      colorGradingEnabled: true,\n      brightness: 1.0,\n      contrast: hdr ? 1.04 : 1.015,\n      saturation: profile.saturation,\n      temperature: profile.temperature,\n      ambientOcclusionEnabled: true,\n      ambientOcclusionRadius: exportQuality ? 0.28 : 0.22,\n      ambientOcclusionIntensity: exportQuality ? 0.72 : 0.56,\n      ambientOcclusionBias: 0.035,\n      ambientOcclusionSampleCount: exportQuality ? 12 : 4,\n      ambientOcclusionHalfResolution: !exportQuality,\n      screenSpaceReflectionsEnabled: exportQuality && hdr,\n      screenSpaceReflectionsIntensity: hdr ? 0.38 : 0.20,\n      screenSpaceReflectionsMaxDistance: 18,\n      screenSpaceReflectionsThickness: 0.42,\n      screenSpaceReflectionsStride: 3,\n      screenSpaceReflectionsMaxSteps: exportQuality ? 96 : 48,\n      screenSpaceReflectionsBlur: 0.18,\n      screenSpaceReflectionsResolutionScale: exportQuality ? 1.0 : 0.5,\n      bloomEnabled: hdr || widget.photoTime != ZamerPhotoTime.day,\n      bloomThreshold: widget.photoTime == ZamerPhotoTime.night ? 0.82 : 1.08,\n      bloomIntensity: widget.photoTime == ZamerPhotoTime.night ? 0.10 : 0.05,\n      bloomScatter: 0.62,\n      vignetteEnabled: true,\n      vignetteIntensity: widget.photoTime == ZamerPhotoTime.night ? 0.13 : 0.08,\n      vignetteRadius: 0.86,\n      vignetteSmoothness: 0.55,\n      autoExposureEnabled: hdr,\n      autoExposureStrength: hdr ? 0.30 : 0.0,\n      autoExposureCompensation: -0.20 + nightBoost,\n      autoExposureMinEv: widget.photoTime == ZamerPhotoTime.night ? -2.0 : -1.2,\n      autoExposureMaxEv: widget.photoTime == ZamerPhotoTime.night ? 2.2 : 1.2,\n    );\n    scene.antiAliasingMode = AntiAliasingMode.auto;\n    scene.environmentIntensity = profile.environmentIntensity;\n    final direction = profile.lightDirection.clone()..normalize();\n    scene.directionalLight = DirectionalLight(\n      direction: direction,\n      color: profile.lightColor,\n      intensity: profile.lightIntensity,\n      castsShadow: true,\n      cacheStaticShadows: false,\n      shadowMapResolution: exportQuality ? 2048 : 1024,\n      shadowMaxDistance: 45,\n      shadowSoftness: widget.photoTime == ZamerPhotoTime.sunset ? 0.42 : 0.30,\n    );\n    scene.ambientOcclusion\n      ..enabled = true\n      ..halfResolution = !exportQuality\n      ..sampleCount = exportQuality ? 8 : 4\n      ..radius = exportQuality ? 0.30 : 0.22\n      ..intensity = exportQuality ? 0.82 : 0.62\n      ..bias = 0.035;\n  }\n\n"""
    text = text[:start] + new_photo + text[end:]

    text = replace_once(
        text,
        """    if (photoQuality) _configurePhotoLighting();\n    try {\n      final recorder = ui.PictureRecorder();\n      final canvas = ui.Canvas(recorder);\n      final background = ui.Paint()\n        ..shader = ui.Gradient.linear(\n          ui.Offset(0, 0),\n          ui.Offset(0, height.toDouble()),\n          const <Color>[Color(0xFFEAF1F5), Color(0xFFF7F4EE)],\n        );\n""",
        """    if (photoQuality) _configurePhotoLighting(exportQuality: true);\n    try {\n      final recorder = ui.PictureRecorder();\n      final canvas = ui.Canvas(recorder);\n      final profile = zamerPhotoLightingProfile(widget.photoTime);\n      final background = ui.Paint()\n        ..shader = ui.Gradient.linear(\n          ui.Offset(0, 0),\n          ui.Offset(0, height.toDouble()),\n          <Color>[profile.backgroundTop, profile.backgroundBottom],\n        );\n""",
        'photo export lighting and background',
    )

    GPU.write_text(text, encoding='utf-8')


def patch_photo() -> None:
    text = PHOTO.read_text(encoding='utf-8')

    text = replace_once(
        text,
        """  String _time = 'День';\n""",
        """  ZamerPhotoTime _time = ZamerPhotoTime.day;\n""",
        'photo time state',
    )

    text = replace_once(
        text,
        """  Future<void> _showTimeSheet() async {\n    final value = await showModalBottomSheet<String>(\n""",
        """  String _timeLabel(ZamerPhotoTime value) => switch (value) {\n    ZamerPhotoTime.day => 'День',\n    ZamerPhotoTime.sunset => 'Закат',\n    ZamerPhotoTime.evening => 'Вечер',\n    ZamerPhotoTime.night => 'Ночь',\n  };\n\n  IconData _timeIcon(ZamerPhotoTime value) => switch (value) {\n    ZamerPhotoTime.day => Icons.wb_sunny_outlined,\n    ZamerPhotoTime.sunset => Icons.wb_twilight_outlined,\n    ZamerPhotoTime.evening => Icons.brightness_4_outlined,\n    ZamerPhotoTime.night => Icons.nightlight_outlined,\n  };\n\n  Future<void> _showTimeSheet() async {\n    final value = await showModalBottomSheet<ZamerPhotoTime>(\n""",
        'photo time helpers',
    )

    old_time_body = """      builder: (sheetContext) => ZSheetFrame(\n        title: 'Время суток',\n        description:\n            'Пока это пресет интерфейса. Управление освещением сцены подключается отдельным проходом рендера.',\n        child: Column(\n          mainAxisSize: MainAxisSize.min,\n          children: [\n            for (final item in const ['День', 'Закат', 'Вечер', 'Ночь'])\n              _SelectionTile(\n                icon: item == 'День'\n                    ? Icons.wb_sunny_outlined\n                    : item == 'Ночь'\n                    ? Icons.nightlight_outlined\n                    : Icons.wb_twilight_outlined,\n                title: item,\n                selected: item == _time,\n                onTap: () => Navigator.pop(sheetContext, item),\n              ),\n          ],\n        ),\n      ),\n    );\n    if (value != null) setState(() => _time = value);\n  }\n"""
    new_time_body = """      builder: (sheetContext) => ZSheetFrame(\n        title: 'Время суток',\n        description:\n            'Меняет окружение, направление и цвет основного света в превью и финальном рендере.',\n        child: Column(\n          mainAxisSize: MainAxisSize.min,\n          children: [\n            for (final item in ZamerPhotoTime.values)\n              _SelectionTile(\n                icon: _timeIcon(item),\n                title: _timeLabel(item),\n                selected: item == _time,\n                onTap: () => Navigator.pop(sheetContext, item),\n              ),\n          ],\n        ),\n      ),\n    );\n    if (value != null) setState(() => _time = value);\n  }\n"""
    text = replace_once(text, old_time_body, new_time_body, 'photo time sheet')

    text = replace_once(
        text,
        """                          walkX: 0,\n                          walkY: 0,\n                        ),\n""",
        """                          walkX: 0,\n                          walkY: 0,\n                          photoPreview: true,\n                          photoTime: _time,\n                          photoHdr: _hdr,\n                        ),\n""",
        'photo preview renderer props',
    )

    text = text.replace("'$_time • ${_mode == '4K' ? '4K' : _quality}'", "'${_timeLabel(_time)} • ${_mode == '4K' ? '4K' : _quality}'")
    text = text.replace("value: _time,\n                      onTap: _showTimeSheet,", "value: _timeLabel(_time),\n                      onTap: _showTimeSheet,")

    PHOTO.write_text(text, encoding='utf-8')


def main() -> None:
    patch_gpu()
    patch_photo()
    print('Photo Studio time-of-day and HDR now drive GPU lighting')


if __name__ == '__main__':
    main()
