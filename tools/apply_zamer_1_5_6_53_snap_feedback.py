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
if 'version: 1.5.6+53' in pubspec:
    print('1.5.6+53 snap feedback patch already applied')
    raise SystemExit(0)
if 'version: 1.5.6+52' not in pubspec:
    raise SystemExit('unexpected app version; refusing automatic +53 patch')

service_path = APP / 'lib/services/angle_snap_service.dart'
service = service_path.read_text()
service = replace_once(
    service,
    """class AngleSnapService {
  const AngleSnapService._();

  /// Magnetically snaps a free rotation to the nearest quarter turn when the
  /// gesture is close enough. Values outside the threshold remain untouched,
  /// so two-finger rotation still feels continuous instead of jumping between
  /// 90-degree sectors.
  static double snapQuarterTurn(
    double angleDeg, {
    double thresholdDeg = 8,
  }) {
    if (!angleDeg.isFinite || !thresholdDeg.isFinite || thresholdDeg < 0) {
      return angleDeg;
    }
    final nearest = (angleDeg / 90).round() * 90.0;
    return (angleDeg - nearest).abs() <= thresholdDeg ? nearest : angleDeg;
  }

  static bool isQuarterTurnSnapped(
    double angleDeg, {
    double epsilonDeg = 0.001,
  }) {
    if (!angleDeg.isFinite) return false;
    final nearest = (angleDeg / 90).round() * 90.0;
    return (angleDeg - nearest).abs() <= epsilonDeg;
  }
}
""",
    """class AngleSnapService {
  const AngleSnapService._();

  static double _angularDistance(double a, double b) {
    final wrapped = ((a - b + 180) % 360 + 360) % 360 - 180;
    return wrapped.abs();
  }

  /// Magnetically snaps a free rotation to the nearest quarter turn when the
  /// gesture is close enough. Values outside the threshold remain untouched,
  /// so two-finger rotation still feels continuous instead of jumping between
  /// 90-degree sectors.
  static double snapQuarterTurn(
    double angleDeg, {
    double thresholdDeg = 8,
  }) {
    return snapQuarterTurnWithLock(
      angleDeg,
      engageThresholdDeg: thresholdDeg,
      releaseThresholdDeg: thresholdDeg,
    ).angleDeg;
  }

  /// Stateful-friendly quarter-turn snapping with hysteresis.
  ///
  /// Once a gesture has locked to 0/90/180/270 it stays locked until the raw
  /// angle moves beyond [releaseThresholdDeg]. This avoids the visible jitter
  /// caused by repeatedly entering and leaving one threshold at the edge.
  static ({double angleDeg, double? lockedAngleDeg}) snapQuarterTurnWithLock(
    double angleDeg, {
    double? lockedAngleDeg,
    double engageThresholdDeg = 7,
    double releaseThresholdDeg = 12,
  }) {
    if (!angleDeg.isFinite ||
        !engageThresholdDeg.isFinite ||
        !releaseThresholdDeg.isFinite ||
        engageThresholdDeg < 0 ||
        releaseThresholdDeg < 0) {
      return (angleDeg: angleDeg, lockedAngleDeg: null);
    }
    final release = releaseThresholdDeg < engageThresholdDeg
        ? engageThresholdDeg
        : releaseThresholdDeg;
    if (lockedAngleDeg != null &&
        lockedAngleDeg.isFinite &&
        _angularDistance(angleDeg, lockedAngleDeg) <= release) {
      return (angleDeg: lockedAngleDeg, lockedAngleDeg: lockedAngleDeg);
    }

    final nearest = (angleDeg / 90).round() * 90.0;
    if (_angularDistance(angleDeg, nearest) <= engageThresholdDeg) {
      return (angleDeg: nearest, lockedAngleDeg: nearest);
    }
    return (angleDeg: angleDeg, lockedAngleDeg: null);
  }

  static bool isQuarterTurnSnapped(
    double angleDeg, {
    double epsilonDeg = 0.001,
  }) {
    if (!angleDeg.isFinite) return false;
    final nearest = (angleDeg / 90).round() * 90.0;
    return _angularDistance(angleDeg, nearest) <= epsilonDeg;
  }
}
""",
    'angle snap service hysteresis',
)
service_path.write_text(service)

screen_path = APP / 'lib/screens/planning_objects_screen.dart'
screen = screen_path.read_text()
screen = replace_once(
    screen,
    """  double _gestureBaseRotation = 0;
  Offset _gestureGrabOffset = Offset.zero;
  bool _gestureDirty = false;
""",
    """  double _gestureBaseRotation = 0;
  double? _gestureSnapAngleDeg;
  Offset _gestureGrabOffset = Offset.zero;
  bool _gestureDirty = false;
""",
    'snap state field',
)
screen = replace_once(
    screen,
    """      _gestureBaseRotation = o?.rotationDeg ?? 0;
      _gestureGrabOffset = o == null
          ? Offset.zero
          : d.localFocalPoint - (tx.origin + Offset(o.xMm, o.yMm) * tx.scale);
      _gestureDirty = false;
""",
    """      _gestureBaseRotation = o?.rotationDeg ?? 0;
      _gestureSnapAngleDeg = null;
      _gestureGrabOffset = o == null
          ? Offset.zero
          : d.localFocalPoint - (tx.origin + Offset(o.xMm, o.yMm) * tx.scale);
      _gestureDirty = false;
""",
    'reset snap lock at gesture start',
)
screen = replace_once(
    screen,
    """    if (d.pointerCount >= 2) {
      final rawRotation = _gestureBaseRotation + d.rotation * 180 / math.pi;
      o.rotationDeg = AngleSnapService.snapQuarterTurn(rawRotation);
    } else {
      _snapObjectGuides(o);
      _snapRadiatorToWall(o);
      _snapCatalogMount(o);
    }
""",
    """    if (d.pointerCount >= 2) {
      final rawRotation = _gestureBaseRotation + d.rotation * 180 / math.pi;
      final snap = AngleSnapService.snapQuarterTurnWithLock(
        rawRotation,
        lockedAngleDeg: _gestureSnapAngleDeg,
      );
      o.rotationDeg = snap.angleDeg;
      _gestureSnapAngleDeg = snap.lockedAngleDeg;
    } else {
      _gestureSnapAngleDeg = null;
      _snapObjectGuides(o);
      _snapRadiatorToWall(o);
      _snapCatalogMount(o);
    }
""",
    'use snap hysteresis during rotation',
)
screen = replace_once(
    screen,
    """      setState(() {
        _gestureObjectId = null;
        _gestureDirty = false;
      });
""",
    """      setState(() {
        _gestureObjectId = null;
        _gestureSnapAngleDeg = null;
        _gestureDirty = false;
      });
""",
    'clear snap lock after gesture',
)
screen = replace_once(
    screen,
    """                  painter: _PlanningPainter(
                    floor: widget.floor,
                    scale: tx.scale,
                    origin: tx.origin,
                    selectedId: _selectedId,
                  ),
""",
    """                  painter: _PlanningPainter(
                    floor: widget.floor,
                    scale: tx.scale,
                    origin: tx.origin,
                    selectedId: _selectedId,
                    snapAngleDeg: _gestureSnapAngleDeg,
                  ),
""",
    'pass snap feedback to painter',
)
screen = replace_once(
    screen,
    """            'Нажми на свободное место для установки. Потяни объект одним пальцем; двумя — поверни. Касание объекта открывает размеры.',
""",
    """            'Нажми на свободное место для установки. Потяни объект одним пальцем; двумя — поверни. Возле 0/90/180/270° включается магнитная привязка.',
""",
    'object interaction hint',
)
screen = replace_once(
    screen,
    """    this.selectedId,
    this.darkPreview = false,
  });
  final FloorPlan floor;
  final double scale;
  final Offset origin;
  final String? selectedId;
  final bool darkPreview;
""",
    """    this.selectedId,
    this.snapAngleDeg,
    this.darkPreview = false,
  });
  final FloorPlan floor;
  final double scale;
  final Offset origin;
  final String? selectedId;
  final double? snapAngleDeg;
  final bool darkPreview;
""",
    'painter snap field',
)
screen = replace_once(
    screen,
    """    for (final o in floor.planObjects) _object(canvas, o, size);
  }
""",
    """    if (selectedId != null && snapAngleDeg != null) {
      PlanObject? active;
      for (final object in floor.planObjects) {
        if (object.id == selectedId) {
          active = object;
          break;
        }
      }
      if (active != null) {
        final c = p(active.xMm, active.yMm);
        final guide = Paint()
          ..color = const Color(0xFF18A979).withValues(alpha: .48)
          ..strokeWidth = 1.2;
        canvas.drawLine(Offset(0, c.dy), Offset(size.width, c.dy), guide);
        canvas.drawLine(Offset(c.dx, 0), Offset(c.dx, size.height), guide);
      }
    }
    for (final o in floor.planObjects) _object(canvas, o, size);
  }
""",
    'draw snap guides',
)
screen = replace_once(
    screen,
    """    final name = o.label.isEmpty ? o.type.label : o.label;
    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Color(0xFF30363D),
        ),
      ),
""",
    """    final name = o.label.isEmpty ? o.type.label : o.label;
    final snapped = snapAngleDeg != null;
    final label = snapped
        ? '$name • ${o.rotationDeg.round()}° • 90°'
        : '$name • ${o.rotationDeg.round()}°';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: snapped ? const Color(0xFF087A5B) : const Color(0xFF30363D),
        ),
      ),
""",
    'snap angle label',
)
screen = replace_once(
    screen,
    """      Paint()..color = const Color(0xFFF7F8FA),
""",
    """      Paint()
        ..color = snapAngleDeg != null
            ? const Color(0xFFE5F7F0)
            : const Color(0xFFF7F8FA),
""",
    'snap label background',
)
screen_path.write_text(screen)

test_path = APP / 'test/angle_snap_service_test.dart'
test = test_path.read_text()
insert = """

  test('hysteresis keeps a quarter-turn lock until the release threshold', () {
    final engaged = AngleSnapService.snapQuarterTurnWithLock(84);
    expect(engaged.angleDeg, 90);
    expect(engaged.lockedAngleDeg, 90);

    final held = AngleSnapService.snapQuarterTurnWithLock(
      78,
      lockedAngleDeg: engaged.lockedAngleDeg,
    );
    expect(held.angleDeg, 90);
    expect(held.lockedAngleDeg, 90);

    final released = AngleSnapService.snapQuarterTurnWithLock(
      77,
      lockedAngleDeg: held.lockedAngleDeg,
    );
    expect(released.angleDeg, 77);
    expect(released.lockedAngleDeg, isNull);
  });

  test('snap lock handles equivalent angles across the 0/360 boundary', () {
    final held = AngleSnapService.snapQuarterTurnWithLock(
      -2,
      lockedAngleDeg: 360,
    );
    expect(held.angleDeg, 360);
    expect(held.lockedAngleDeg, 360);
  });
"""
test = replace_once(test, '\n}\n', insert + '\n}\n', 'append hysteresis tests')
test_path.write_text(test)

pubspec_path.write_text(pubspec.replace('version: 1.5.6+52', 'version: 1.5.6+53', 1))

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = """## 1.5.6+53

- Магнитная привязка вращения к 0/90/180/270° получила гистерезис: объект захватывается рядом с четвертью оборота и не дрожит на границе порога, пока пользователь явно не отведёт угол дальше.
- Во время активной 90°-привязки на плане показываются зелёные горизонтальная/вертикальная направляющие и текущий угол выбранного объекта.
- Подпись выбранного объекта теперь показывает угол; при захвате отдельно отмечается `90°`, поэтому действие привязки видно, а не приходится угадывать по поведению жеста.
- Добавлены тесты удержания/отпускания магнитного угла и корректной работы через границу 0/360°.

"""
if not changelog.startswith('## 1.5.6+53'):
    changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+53 snap feedback patch')
