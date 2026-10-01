#!/usr/bin/env python3
"""Correct width/height parsing in persisted Photo Render filenames."""

from pathlib import Path

APP = Path(__file__).resolve().parents[2]
PHOTO = APP / 'lib' / 'screens' / 'photo_studio_screen.dart'


def main() -> None:
    text = PHOTO.read_text(encoding='utf-8')
    old = """    if (parts.length >= 4) {
      return '${parts[2]}×${parts[3]}';
    }
"""
    new = """    if (parts.length >= 6) {
      return '${parts[3]}×${parts[4]}';
    }
"""
    if old in text:
        text = text.replace(old, new, 1)
    elif new not in text:
        raise RuntimeError('render gallery filename parser anchor not found')
    PHOTO.write_text(text, encoding='utf-8')
    print('Photo Render gallery labels now use width × height')


if __name__ == '__main__':
    main()
