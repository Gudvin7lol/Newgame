#!/usr/bin/env python3
"""Reset Photo Studio look smoothing whenever pointer count changes."""

from pathlib import Path

APP = Path(__file__).resolve().parents[2]
PHOTO = APP / 'lib' / 'screens' / 'photo_studio_screen.dart'


def main() -> None:
    text = PHOTO.read_text(encoding='utf-8')
    old = """    if (d.pointerCount != _gesturePointers) {
      _gesturePointers = d.pointerCount;
      _gestureZoom = _zoom / math.max(.001, d.scale);
      _gesturePan = _pan;
      _gestureFocal = d.focalPoint;
      return;
    }
"""
    new = """    if (d.pointerCount != _gesturePointers) {
      _gesturePointers = d.pointerCount;
      _gestureZoom = _zoom / math.max(.001, d.scale);
      _gesturePan = _pan;
      _gestureFocal = d.focalPoint;
      _stabilizedLookDelta = Offset.zero;
      return;
    }
"""
    if old in text:
        text = text.replace(old, new, 1)
    elif new not in text:
        raise RuntimeError('gesture pointer transition anchor not found')

    if text.count('_stabilizedLookDelta = Offset.zero;') < 2:
        raise RuntimeError('stabilization reset is incomplete')

    PHOTO.write_text(text, encoding='utf-8')
    print('Photo stabilization now resets when pointer count changes')


if __name__ == '__main__':
    main()
