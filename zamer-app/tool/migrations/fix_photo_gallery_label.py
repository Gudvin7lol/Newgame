#!/usr/bin/env python3
"""Repair persisted Photo labels and gesture-stabilization transition state."""

from pathlib import Path

APP = Path(__file__).resolve().parents[2]
PHOTO = APP / 'lib' / 'screens' / 'photo_studio_screen.dart'


def main() -> None:
    text = PHOTO.read_text(encoding='utf-8')

    old_label = """    if (parts.length >= 4) {
      return '${parts[2]}×${parts[3]}';
    }
"""
    new_label = """    if (parts.length >= 6) {
      return '${parts[3]}×${parts[4]}';
    }
"""
    if old_label in text:
        text = text.replace(old_label, new_label, 1)
    elif new_label not in text:
        raise RuntimeError('render gallery filename parser anchor not found')

    old_pointer = """    if (d.pointerCount != _gesturePointers) {
      _gesturePointers = d.pointerCount;
      _gestureZoom = _zoom / math.max(.001, d.scale);
      _gesturePan = _pan;
      _gestureFocal = d.focalPoint;
      return;
    }
"""
    new_pointer = """    if (d.pointerCount != _gesturePointers) {
      _gesturePointers = d.pointerCount;
      _gestureZoom = _zoom / math.max(.001, d.scale);
      _gesturePan = _pan;
      _gestureFocal = d.focalPoint;
      _stabilizedLookDelta = Offset.zero;
      return;
    }
"""
    if old_pointer in text:
        text = text.replace(old_pointer, new_pointer, 1)
    elif '_stabilizedLookDelta' in text and new_pointer not in text:
        raise RuntimeError('gesture stabilization transition anchor not found')

    PHOTO.write_text(text, encoding='utf-8')
    print('Photo render labels and stabilization transitions are current')


if __name__ == '__main__':
    main()
