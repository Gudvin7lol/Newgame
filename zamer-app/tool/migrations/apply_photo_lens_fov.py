#!/usr/bin/env python3
"""Make Photo Studio lens presets change perspective instead of dolly zoom."""

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
    text = replace_once(
        text,
        """    this.photoHdr = true,\n  });\n""",
        """    this.photoHdr = true,\n    this.cameraFovDegrees = 46,\n  });\n""",
        'camera FOV constructor',
    )
    text = replace_once(
        text,
        """  final bool photoHdr;\n\n  @override\n""",
        """  final bool photoHdr;\n  final double cameraFovDegrees;\n\n  @override\n""",
        'camera FOV field',
    )
    text = replace_once(
        text,
        """    return PerspectiveCamera(\n      fovRadiansY: 46 * math.pi / 180,\n""",
        """    final fovDegrees = widget.cameraFovDegrees.clamp(18.0, 90.0);\n    return PerspectiveCamera(\n      fovRadiansY: fovDegrees * math.pi / 180,\n""",
        'perspective FOV',
    )
    GPU.write_text(text, encoding='utf-8')


def patch_photo() -> None:
    text = PHOTO.read_text(encoding='utf-8')
    text = replace_once(
        text,
        """  void _selectLens(double value) {\n    setState(() {\n      _lens = value;\n      _zoom = (widget.zoom * value).clamp(.28, 4.5).toDouble();\n    });\n  }\n""",
        """  double _lensFov(double lens) => switch (lens) {\n    <= 0.5 => 78,\n    <= 1.0 => 46,\n    <= 2.0 => 28,\n    _ => 20,\n  };\n\n  void _selectLens(double value) {\n    setState(() => _lens = value);\n  }\n""",
        'photo lens selector',
    )
    text = replace_once(
        text,
        """                          photoHdr: _hdr,\n                        ),\n""",
        """                          photoHdr: _hdr,\n                          cameraFovDegrees: _lensFov(_lens),\n                        ),\n""",
        'photo lens FOV wiring',
    )
    PHOTO.write_text(text, encoding='utf-8')


def main() -> None:
    patch_gpu()
    patch_photo()
    print('Photo Studio lens presets now drive perspective FOV')


if __name__ == '__main__':
    main()
