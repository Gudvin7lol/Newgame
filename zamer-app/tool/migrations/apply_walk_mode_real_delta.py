#!/usr/bin/env python3
"""Use measured elapsed time for Walk Mode movement instead of a fixed 16 ms delta."""

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
        """  Timer? _timer;\n  Offset _vector = Offset.zero;\n  static const double _radius = 58;\n  static const Duration _frameInterval = Duration(milliseconds: 16);\n  static const double _frameSeconds = 0.016;\n""",
        """  Timer? _timer;\n  Offset _vector = Offset.zero;\n  final Stopwatch _frameClock = Stopwatch();\n  int? _lastFrameMicros;\n  static const double _radius = 58;\n  static const Duration _frameInterval = Duration(milliseconds: 16);\n""",
        'walk frame timing state',
    )

    text = replace_once(
        text,
        """  void _emitStep() {\n    final input = WalkInputService.fromStick(_vector.dx, _vector.dy);\n    if (input.forward == 0 && input.sideways == 0) return;\n    widget.onStep(input.forward, input.sideways, _frameSeconds);\n  }\n""",
        """  void _emitStep() {\n    final nowMicros = _frameClock.elapsedMicroseconds;\n    final previousMicros = _lastFrameMicros;\n    _lastFrameMicros = nowMicros;\n    final elapsedMicros = previousMicros == null\n        ? _frameInterval.inMicroseconds\n        : nowMicros - previousMicros;\n    final deltaSeconds =\n        (elapsedMicros / Duration.microsecondsPerSecond)\n            .clamp(1 / 240, 0.05)\n            .toDouble();\n    final input = WalkInputService.fromStick(_vector.dx, _vector.dy);\n    if (input.forward == 0 && input.sideways == 0) return;\n    widget.onStep(input.forward, input.sideways, deltaSeconds);\n  }\n""",
        'measured walk delta',
    )

    text = replace_once(
        text,
        """  void _start(Offset local) {\n    _update(local);\n    _timer?.cancel();\n    _emitStep();\n    _timer = Timer.periodic(_frameInterval, (_) => _emitStep());\n  }\n""",
        """  void _start(Offset local) {\n    _update(local);\n    _timer?.cancel();\n    _frameClock\n      ..reset()\n      ..start();\n    _lastFrameMicros = null;\n    _emitStep();\n    _timer = Timer.periodic(_frameInterval, (_) => _emitStep());\n  }\n""",
        'walk clock start',
    )

    text = replace_once(
        text,
        """  void _stop() {\n    _timer?.cancel();\n    _timer = null;\n    if (mounted) setState(() => _vector = Offset.zero);\n  }\n""",
        """  void _stop() {\n    _timer?.cancel();\n    _timer = null;\n    _frameClock.stop();\n    _lastFrameMicros = null;\n    if (mounted) setState(() => _vector = Offset.zero);\n  }\n""",
        'walk clock stop',
    )

    SCREEN.write_text(text, encoding='utf-8')
    print('Walk Mode now uses measured elapsed time with a bounded delta')


if __name__ == '__main__':
    main()
