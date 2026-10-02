#!/usr/bin/env python3
"""Make the Photo Studio stabilization toggle smooth single-finger camera look."""

from pathlib import Path

APP = Path(__file__).resolve().parents[2]
PHOTO = APP / 'lib' / 'screens' / 'photo_studio_screen.dart'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        if new in text:
            return text
        raise RuntimeError(f'could not locate {label}')
    if text.count(old) != 1:
        raise RuntimeError(f'expected one {label}, found {text.count(old)}')
    return text.replace(old, new, 1)


def main() -> None:
    text = PHOTO.read_text(encoding='utf-8')

    text = replace_once(
        text,
        """  int _gesturePointers = 0;

  String _mode = 'Фото';
""",
        """  int _gesturePointers = 0;
  Offset _stabilizedLookDelta = Offset.zero;

  String _mode = 'Фото';
""",
        'stabilized delta state',
    )

    text = replace_once(
        text,
        """    _gestureFocal = d.focalPoint;
    _gesturePointers = d.pointerCount;
  }
""",
        """    _gestureFocal = d.focalPoint;
    _gesturePointers = d.pointerCount;
    _stabilizedLookDelta = Offset.zero;
  }
""",
        'stabilization reset',
    )

    old_single = """      } else {
        final angle = _rotation + d.focalPointDelta.dx * .008;
        _rotation = math.atan2(math.sin(angle), math.cos(angle));
        _tilt = (_tilt - d.focalPointDelta.dy * .005)
            .clamp(.15, 1.48)
            .toDouble();
      }
"""
    new_single = """      } else {
        final rawLook = d.focalPointDelta;
        final lookDelta = _stabilization
            ? (_stabilizedLookDelta = Offset(
                _stabilizedLookDelta.dx * .68 + rawLook.dx * .32,
                _stabilizedLookDelta.dy * .68 + rawLook.dy * .32,
              ))
            : rawLook;
        if (!_stabilization) _stabilizedLookDelta = rawLook;
        final angle = _rotation + lookDelta.dx * .008;
        _rotation = math.atan2(math.sin(angle), math.cos(angle));
        _tilt = (_tilt - lookDelta.dy * .005)
            .clamp(.15, 1.48)
            .toDouble();
      }
"""
    text = replace_once(text, old_single, new_single, 'single-finger stabilization')

    text = text.replace(
        "label: 'Стабилизация',",
        "label: 'Стабилизация движения',",
        1,
    )

    PHOTO.write_text(text, encoding='utf-8')
    print('Photo Studio stabilization now smooths camera look input')


if __name__ == '__main__':
    main()
