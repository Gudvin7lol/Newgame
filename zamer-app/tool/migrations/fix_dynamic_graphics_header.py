#!/usr/bin/env python3
"""Keep the live graphics-mode header non-const after profile migration."""

from pathlib import Path

APP = Path(__file__).resolve().parents[2]
SCREEN = APP / 'lib' / 'screens' / 'floor_3d_screen.dart'


def main() -> None:
    text = SCREEN.read_text(encoding='utf-8')
    old = """        if (!_walkMode)
          const Positioned(
            left: ZamerSpace.md,
            right: ZamerSpace.md,
            top: ZamerSpace.sm,
            child: SafeArea(
              bottom: false,
              child: _ThreeDMasterHeader(graphicsMode: _graphicsMode),
            ),
          ),
"""
    new = """        if (!_walkMode)
          Positioned(
            left: ZamerSpace.md,
            right: ZamerSpace.md,
            top: ZamerSpace.sm,
            child: SafeArea(
              bottom: false,
              child: _ThreeDMasterHeader(graphicsMode: _graphicsMode),
            ),
          ),
"""

    if old in text:
        text = text.replace(old, new, 1)
    elif new not in text:
        raise RuntimeError('dynamic 3D graphics header anchor not found')

    SCREEN.write_text(text, encoding='utf-8')
    print('Dynamic 3D graphics header is non-const')


if __name__ == '__main__':
    main()
