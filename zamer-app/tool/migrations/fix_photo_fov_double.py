#!/usr/bin/env python3
"""Keep camera FOV as a double after Dart num.clamp()."""

from pathlib import Path

APP = Path(__file__).resolve().parents[2]
GPU = APP / 'lib' / 'renderer3d' / 'zamer_gpu_viewport.dart'


def main() -> None:
    text = GPU.read_text(encoding='utf-8')
    old = "final fovDegrees = widget.cameraFovDegrees.clamp(18.0, 90.0);"
    new = "final fovDegrees = widget.cameraFovDegrees.clamp(18.0, 90.0).toDouble();"
    if old in text:
        text = text.replace(old, new, 1)
    elif new not in text:
        raise RuntimeError('camera FOV clamp anchor not found')
    GPU.write_text(text, encoding='utf-8')
    print('Photo Studio camera FOV is strongly typed as double')


if __name__ == '__main__':
    main()
