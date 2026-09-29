from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'zamer-app'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    return text.replace(old, new, 1)


pubspec_path = APP / 'pubspec.yaml'
pubspec = pubspec_path.read_text()
if 'version: 1.5.6+52' in pubspec:
    print('1.5.6+52 walk input patch already applied')
    raise SystemExit(0)
if 'version: 1.5.6+51' not in pubspec:
    raise SystemExit('unexpected app version; refusing automatic +52 patch')

service_path = APP / 'lib/services/walk_input_service.dart'
service_path.write_text("""import 'dart:math' as math;

/// Converts the normalized virtual-stick displacement into camera-relative
/// movement input. The stick already carries its own magnitude, so applying the
/// magnitude twice makes low-speed movement feel artificially sluggish.
class WalkInputService {
  const WalkInputService._();

  static const double deadZone = 0.08;

  static ({double forward, double sideways}) fromStick(
    double x,
    double y, {
    double deadZoneRadius = deadZone,
  }) {
    if (!x.isFinite || !y.isFinite) {
      return (forward: 0.0, sideways: 0.0);
    }
    final magnitude = math.sqrt(x * x + y * y).clamp(0.0, 1.0).toDouble();
    final zone = deadZoneRadius.clamp(0.0, 0.95).toDouble();
    if (magnitude <= zone || magnitude <= 0.000001) {
      return (forward: 0.0, sideways: 0.0);
    }

    // Remove the dead zone, then keep a linear response up to full travel.
    final strength = ((magnitude - zone) / (1.0 - zone)).clamp(0.0, 1.0).toDouble();
    final nx = x / magnitude;
    final ny = y / magnitude;
    return (forward: -ny * strength, sideways: nx * strength);
  }
}
""")

test_path = APP / 'test/walk_input_service_test.dart'
test_path.write_text("""import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/services/walk_input_service.dart';

void main() {
  test('stick dead zone suppresses accidental drift', () {
    final input = WalkInputService.fromStick(0.03, -0.04);
    expect(input.forward, 0);
    expect(input.sideways, 0);
  });

  test('stick maps screen directions to walk axes', () {
    final forward = WalkInputService.fromStick(0, -1);
    expect(forward.forward, closeTo(1, 0.0001));
    expect(forward.sideways, closeTo(0, 0.0001));

    final right = WalkInputService.fromStick(1, 0);
    expect(right.forward, closeTo(0, 0.0001));
    expect(right.sideways, closeTo(1, 0.0001));
  });

  test('stick response stays linear instead of squaring its magnitude', () {
    final input = WalkInputService.fromStick(0, -0.54);
    final expected = (0.54 - WalkInputService.deadZone) /
        (1 - WalkInputService.deadZone);
    expect(input.forward, closeTo(expected, 0.0001));
    expect(input.forward, greaterThan(0.45));
  });
}
""")

screen_path = APP / 'lib/screens/floor_3d_screen.dart'
screen = screen_path.read_text()
screen = replace_once(
    screen,
    "import '../services/walk_navigation_service.dart';",
    "import '../services/walk_input_service.dart';\nimport '../services/walk_navigation_service.dart';",
    'walk input import',
)
screen = replace_once(
    screen,
    """  void _start(Offset local) {
    _update(local);
    _timer?.cancel();
    widget.onStep(-_vector.dy, _vector.dx);
    _timer = Timer.periodic(const Duration(milliseconds: 48), (_) {
      if (_vector.distance < 0.08) return;
      final strength = _vector.distance.clamp(0.0, 1.0).toDouble();
      widget.onStep(-_vector.dy * strength, _vector.dx * strength);
    });
  }
""",
    """  void _emitStep() {
    final input = WalkInputService.fromStick(_vector.dx, _vector.dy);
    if (input.forward == 0 && input.sideways == 0) return;
    widget.onStep(input.forward, input.sideways);
  }

  void _start(Offset local) {
    _update(local);
    _timer?.cancel();
    _emitStep();
    _timer = Timer.periodic(const Duration(milliseconds: 48), (_) => _emitStep());
  }
""",
    'linear joystick response',
)
screen = replace_once(
    screen,
    """    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final knob = center + vector * baseRadius;
""",
    """    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      center,
      baseRadius * 0.18,
      Paint()
        ..color = ringColor.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final knob = center + vector * baseRadius;
""",
    'joystick dead-zone guide',
)
screen = replace_once(
    screen,
    """      oldDelegate.vector != vector ||
      oldDelegate.baseColor != baseColor ||
      oldDelegate.knobColor != knobColor;
""",
    """      oldDelegate.vector != vector ||
      oldDelegate.baseColor != baseColor ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.knobColor != knobColor ||
      oldDelegate.iconColor != iconColor;
""",
    'joystick repaint colors',
)
screen_path.write_text(screen)

pubspec_path.write_text(pubspec.replace('version: 1.5.6+51', 'version: 1.5.6+52', 1))

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = """## 1.5.6+52

- Аналоговый стик Walk Mode получил линейную характеристику после небольшой мёртвой зоны. Раньше величина отклонения умножалась сама на себя, поэтому медленное движение ощущалось ватным и непредсказуемым.
- Направления стика вынесены в отдельный тестируемый `WalkInputService`: вверх = вперёд по камере, вправо = шаг вправо; случайный дрейф внутри мёртвой зоны игнорируется.
- На стике добавлена визуальная внутренняя зона и исправлено обновление цветов painter, чтобы управление читалось стабильнее при смене темы.
- Добавлены регрессионные тесты dead-zone, направлений и линейной чувствительности.

"""
if not changelog.startswith('## 1.5.6+52'):
    changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+52 walk input patch')
