#!/usr/bin/env python3
"""Return from Photo Studio to the realtime profile the user actually chose."""

from pathlib import Path

APP = Path(__file__).resolve().parents[2]
SCREEN = APP / 'lib' / 'screens' / 'floor_3d_screen.dart'


def main() -> None:
    text = SCREEN.read_text(encoding='utf-8')
    old = """  Future<void> _selectGraphicsMode(ZGraphicsMode value) async {
    setState(() => _graphicsMode = value);
    if (value == ZGraphicsMode.photo) {
      await _showRenderSheet();
      if (mounted) setState(() => _graphicsMode = ZGraphicsMode.quality);
    }
  }
"""
    new = """  Future<void> _selectGraphicsMode(ZGraphicsMode value) async {
    final previousRealtimeMode = _graphicsMode == ZGraphicsMode.photo
        ? ZGraphicsMode.quality
        : _graphicsMode;
    setState(() => _graphicsMode = value);
    if (value == ZGraphicsMode.photo) {
      await _showRenderSheet();
      if (mounted) setState(() => _graphicsMode = previousRealtimeMode);
    }
  }
"""

    if old in text:
        text = text.replace(old, new, 1)
    elif new not in text:
        raise RuntimeError('graphics mode selection anchor not found')

    SCREEN.write_text(text, encoding='utf-8')
    print('Photo Studio now restores the previous realtime graphics mode')


if __name__ == '__main__':
    main()
