#!/usr/bin/env python3
"""Make Walk Mode movement frame-rate aware and smooth first-person look."""

from pathlib import Path

APP = Path(__file__).resolve().parents[2]
SCREEN = APP / 'lib' / 'screens' / 'floor_3d_screen.dart'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        if new in text:
            return text
        raise RuntimeError(f'could not locate {label}')
    if text.count(old) != 1:
        raise RuntimeError(f'expected one {label}, found {text.count(old)}')
    return text.replace(old, new, 1)


def main() -> None:
    text = SCREEN.read_text(encoding='utf-8')

    text = replace_once(
        text,
        """  double _walkStepMm = 120;\n  double _lookSensitivity = 0.010;\n""",
        """  double _walkSpeedMmPerSecond = 2500;\n  double _lookSensitivity = 0.010;\n  Offset _walkLookDelta = Offset.zero;\n""",
        'walk speed state',
    )

    text = replace_once(
        text,
        """    _gestureFocal = d.focalPoint;\n    _gesturePointers = d.pointerCount;\n  }\n""",
        """    _gestureFocal = d.focalPoint;\n    _gesturePointers = d.pointerCount;\n    _walkLookDelta = Offset.zero;\n  }\n""",
        'gesture start smoothing reset',
    )

    text = replace_once(
        text,
        """      _gesturePan = _pan;\n      _gestureFocal = d.focalPoint;\n      return;\n""",
        """      _gesturePan = _pan;\n      _gestureFocal = d.focalPoint;\n      _walkLookDelta = Offset.zero;\n      return;\n""",
        'pointer transition smoothing reset',
    )

    text = replace_once(
        text,
        """        final lookSensitivity = _walkMode ? _lookSensitivity : 0.010;\n        final angle = _rotation + d.focalPointDelta.dx * lookSensitivity;\n        _rotation = math.atan2(math.sin(angle), math.cos(angle));\n        _tilt = (_tilt - d.focalPointDelta.dy * lookSensitivity * 0.6)\n            .clamp(_walkMode ? -0.7 : 0.22, _walkMode ? 0.7 : 1.48)\n            .toDouble();\n""",
        """        final rawLook = d.focalPointDelta;\n        final lookDelta = _walkMode\n            ? (_walkLookDelta = Offset(\n                _walkLookDelta.dx * .55 + rawLook.dx * .45,\n                _walkLookDelta.dy * .55 + rawLook.dy * .45,\n              ))\n            : rawLook;\n        if (!_walkMode) _walkLookDelta = Offset.zero;\n        final lookSensitivity = _walkMode ? _lookSensitivity : 0.010;\n        final angle = _rotation + lookDelta.dx * lookSensitivity;\n        _rotation = math.atan2(math.sin(angle), math.cos(angle));\n        _tilt = (_tilt - lookDelta.dy * lookSensitivity * 0.6)\n            .clamp(_walkMode ? -0.7 : 0.22, _walkMode ? 0.7 : 1.48)\n            .toDouble();\n""",
        'walk look smoothing',
    )

    text = replace_once(
        text,
        """                      value: _walkStepMm,\n                      min: 55,\n                      max: 220,\n                      divisions: 11,\n                      label: '${_walkStepMm.round()} мм',\n                      onChanged: (value) {\n                        setState(() => _walkStepMm = value);\n""",
        """                      value: _walkSpeedMmPerSecond,\n                      min: 800,\n                      max: 4500,\n                      divisions: 37,\n                      label: '${(_walkSpeedMmPerSecond / 1000).toStringAsFixed(1)} м/с',\n                      onChanged: (value) {\n                        setState(() => _walkSpeedMmPerSecond = value);\n""",
        'physical walk speed slider',
    )

    text = replace_once(
        text,
        """              child: _WalkJoystick(\n                onStep: (forward, sideways) =>\n                    _walk(forward * _walkStepMm, sideways * _walkStepMm),\n              ),\n""",
        """              child: _WalkJoystick(\n                onStep: (forward, sideways, deltaSeconds) => _walk(\n                  forward * _walkSpeedMmPerSecond * deltaSeconds,\n                  sideways * _walkSpeedMmPerSecond * deltaSeconds,\n                ),\n              ),\n""",
        'frame-rate aware walk callback',
    )

    text = replace_once(
        text,
        """  final void Function(double forward, double sideways) onStep;\n""",
        """  final void Function(\n    double forward,\n    double sideways,\n    double deltaSeconds,\n  ) onStep;\n""",
        'joystick callback signature',
    )

    text = replace_once(
        text,
        """  Timer? _timer;\n  Offset _vector = Offset.zero;\n  static const double _radius = 58;\n""",
        """  Timer? _timer;\n  Offset _vector = Offset.zero;\n  static const double _radius = 58;\n  static const Duration _frameInterval = Duration(milliseconds: 16);\n  static const double _frameSeconds = 0.016;\n""",
        '60Hz joystick timing',
    )

    text = replace_once(
        text,
        """    widget.onStep(input.forward, input.sideways);\n""",
        """    widget.onStep(input.forward, input.sideways, _frameSeconds);\n""",
        'joystick delta time pass-through',
    )

    text = replace_once(
        text,
        """    _timer = Timer.periodic(\n      const Duration(milliseconds: 48),\n      (_) => _emitStep(),\n    );\n""",
        """    _timer = Timer.periodic(_frameInterval, (_) => _emitStep());\n""",
        '60Hz joystick timer',
    )

    SCREEN.write_text(text, encoding='utf-8')
    print('Walk Mode now uses 60Hz movement, physical speed and smoothed look')


if __name__ == '__main__':
    main()
