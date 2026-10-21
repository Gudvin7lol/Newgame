import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Native translation of ZAMER UI Kit 1.2: contextual radial dial v2.
/// The CAD model and all editing operations remain in the production screens.
/// This widget is presentation plus a typed command dispatcher, not a fake
/// second drawing surface.
abstract final class ZamerKitColors {
  static const canvas = Color(0xFF171C20);
  static const bg = Color(0xFF101519);
  static const panel = Color(0xFF20252A);
  static const raised = Color(0xFF2B3238);
  static const line = Color(0xFF414B53);
  static const text = Color(0xFFF2F0EB);
  static const muted = Color(0xFFACB4BB);
  static const peach = Color(0xFFFFCEA0);
  static const peachDim = Color(0xFFC4956A);
  static const ink = Color(0xFF261D15);
}

class ZamerKitCommand {
  const ZamerKitCommand(this.id, this.label, this.icon, {this.enabled = true});
  final String id;
  final String label;
  final IconData icon;
  final bool enabled;
}

/// Controls only the real four domains. Object navigation has ONE category:
/// "Мебель". Kitchen, decor and sanitary models are catalog entries, not
/// separate pages/categories within the furniture window.
abstract final class ZamerKitNavigation {
  static const domains = <String>['План', 'Пол', 'Объекты', 'Электрика'];

  static List<String> categories(int domain) => switch (domain) {
    0 => const ['Стены', 'Перегородки', 'Проёмы', 'Демонтаж', 'Размеры'],
    1 => const ['Покрытия', 'Подложка', 'Плинтус'],
    2 => const ['Мебель'],
    _ => const ['Розетки', 'Выключатели', 'Свет', 'Линии', 'Щит', 'Группы'],
  };
}

/// Fixed primary slot placement is part of the accepted interaction contract.
class ZamerKitFan extends StatefulWidget {
  const ZamerKitFan({
    super.key,
    required this.contextId,
    required this.first,
    required this.second,
    required this.outer,
    required this.onCommand,
    this.selectedCommand = 'select',
  });

  final String contextId;
  final ZamerKitCommand first, second;
  final List<ZamerKitCommand> outer;
  final String selectedCommand;
  final ValueChanged<String> onCommand;

  @override
  State<ZamerKitFan> createState() => _ZamerKitFanState();
}

class _ZamerKitFanState extends State<ZamerKitFan> {
  // Keep construction canvas accessible until the dial is explicitly opened.
  bool _expanded = false;
  bool _leftHanded = false;
  int _ringOffset = 0;
  double _dragAmount = 0;
  bool _ringWasDragged = false;
  bool _draggingOuter = false;
  double? _lastOuterAngle;

  static const _select = ZamerKitCommand(
    'select', 'Выбрать', Icons.near_me_outlined);
  static const _size = 208.0;
  static const _center = Offset(158, 158);

  @override
  void didUpdateWidget(covariant ZamerKitFan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contextId != widget.contextId) _ringOffset = 0;
  }

  Offset _point(double radius, double angle) {
    final rad = angle * math.pi / 180;
    final x = _center.dx + radius * math.cos(rad);
    return Offset(_leftHanded ? _size - x : x,
        _center.dy + radius * math.sin(rad));
  }

  Widget _label(ZamerKitCommand command, Offset pos, {
    required bool outer,
  }) {
    final active = command.id == widget.selectedCommand;
    final foreground = !command.enabled
        ? ZamerKitColors.muted.withValues(alpha: .48)
        : active ? ZamerKitColors.peach : ZamerKitColors.text;
    final w = outer ? 68.0 : 74.0;
    return Positioned(
      left: pos.dx - w / 2,
      top: pos.dy - (outer ? 24 : 23),
      child: IgnorePointer(
        child: SizedBox(
          width: w,
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(command.icon, size: outer ? 16 : 20, color: foreground),
              const SizedBox(height: 2),
              Text(command.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: outer ? 9.5 : 10.5,
                  height: 1.08,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _angleFor(Offset local) {
    final p = _leftHanded
        ? Offset(_size - local.dx, local.dy) : local;
    final v = p - _center;
    return math.atan2(v.dy, v.dx) * 180 / math.pi;
  }

  int get _lastRingStart => math.max(0, widget.outer.length - 3);

  void _stepRing(int direction) {
    if (widget.outer.length <= 3) return;
    setState(() {
      _ringOffset = (_ringOffset + direction).clamp(0, _lastRingStart);
    });
  }

  void _tap(TapUpDetails e) {
    final raw = e.localPosition;
    final p = _leftHanded ? Offset(_size - raw.dx, raw.dy) : raw;
    final v = p - _center;
    final r = v.distance;
    final angle = (math.atan2(v.dy, v.dx) * 180 / math.pi + 360) % 360;

    if (r <= 28) {
      setState(() => _expanded = !_expanded);
      return;
    }
    if (_ringWasDragged) {
      _ringWasDragged = false;
      return;
    }
    if (!_expanded) {
      if (r >= 30 && r <= 105 && (angle - 180).abs() <= 24) {
        widget.onCommand(_select.id);
      }
      return;
    }
    if (r >= 31 && r <= 85) {
      final candidates = <(double, ZamerKitCommand)>[
        (180, _select), (225, widget.first), (270, widget.second),
      ];
      for (final entry in candidates) {
        if ((angle - entry.$1).abs() <= 22 && entry.$2.enabled) {
          widget.onCommand(entry.$2.id);
          return;
        }
      }
    }
    if (r >= 92 && r <= 145) {
      const angles = [155.0, 205.0, 255.0];
      for (var i = 0; i < 3; i++) {
        if ((angle - angles[i]).abs() <= 18 &&
            _ringOffset + i < widget.outer.length) {
          final cmd = widget.outer[_ringOffset + i];
          if (cmd.enabled) widget.onCommand(cmd.id);
          return;
        }
      }
    }
  }

  void _showAll() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZamerKitColors.panel,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .72),
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Команды веера',
                  style: TextStyle(color: ZamerKitColors.text,
                    fontWeight: FontWeight.w700)),
                subtitle: Text('Недоступные действия пока не подключены',
                  style: TextStyle(color: ZamerKitColors.muted)),
              ),
              for (final cmd in [_select, widget.first, widget.second,
                ...widget.outer])
                ListTile(
                  key: ValueKey('fan-command-${cmd.id}'),
                  enabled: cmd.enabled,
                  leading: Icon(cmd.icon,
                    color: cmd.enabled
                      ? ZamerKitColors.peach : ZamerKitColors.muted),
                  title: Text(cmd.label),
                  trailing: !cmd.enabled
                    ? const Icon(Icons.lock_outline_rounded, size: 18)
                    : null,
                  onTap: !cmd.enabled ? null : () {
                    Navigator.pop(ctx);
                    widget.onCommand(cmd.id);
                  },
                ),
              SwitchListTile.adaptive(
                title: const Text('Для левой руки'),
                value: _leftHanded,
                onChanged: (value) {
                  setState(() => _leftHanded = value);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <ZamerKitCommand>[];
    for (var i = _ringOffset;
        i < math.min(_ringOffset + 3, widget.outer.length); i++) {
      items.add(widget.outer[i]);
    }
    if (!_expanded) {
      return SizedBox(
        width: 145, height: 54,
        child: Row(children: [
          Material(
            color: ZamerKitColors.panel,
            elevation: 4,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: const ValueKey('fan-quick-select'),
              onTap: () => widget.onCommand('select'),
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.near_me_outlined, size: 17,
                    color: ZamerKitColors.peach),
                  SizedBox(width: 5),
                  Text('Выбрать', style: TextStyle(
                    color: ZamerKitColors.text, fontSize: 11,
                    fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            key: const ValueKey('fan-expand'),
            onTap: () => setState(() => _expanded = true),
            onLongPress: _showAll,
            customBorder: const CircleBorder(),
            child: Container(
              width: 49, height: 49,
              decoration: BoxDecoration(
                color: ZamerKitColors.peach, shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: ZamerKitColors.peach.withValues(alpha: .22),
                  blurRadius: 18)]),
              child: const Icon(Icons.tune_rounded,
                color: ZamerKitColors.ink, size: 24),
            ),
          ),
        ]),
      );
    }
    return SizedBox(
      width: _size, height: _size,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild;
        onTapUp: _tap,
        onLongPress: _showAll,
        onPanStart: (details) {
          final local = details.localPosition;
          final p = _leftHanded
              ? Offset(_size - local.dx, local.dy) : local;
          final distance = (p - const Offset(188, 188)).distance;
          _draggingOuter = _expanded &&
              distance >= 92 && distance <= 145;
          _lastOuterAngle = _draggingOuter
              ? _angleFor(local) : null;
          _dragAmount = 0;
          _ringWasDragged = false;
        },
        onPanUpdate: (d) {
          if (!_draggingOuter || _lastOuterAngle == null) return;
          final angle = _angleFor(d.localPosition);
          var delta = angle - _lastOuterAngle!;
          if (delta > 180) delta -= 360;
          if (delta < -180) delta += 360;
          _dragAmount += delta;
          _lastOuterAngle = angle;
          if (_dragAmount.abs() >= 18) {
            _ringWasDragged = true;
            _stepRing(_dragAmount < 0 ? 1 : -1);
            _dragAmount = 0;
          }
        },
        onPanEnd: (_) {
          // Flutter's pan recognizer has already defeated the tap recognizer.
          // Clear the gesture guard so the *next* genuine tap still works.
          _draggingOuter = false;
          _lastOuterAngle = null;
          _ringWasDragged = false;
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedSwitcher(
              duration: Duration(milliseconds: _expanded ? 380 : 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: CustomPaint(
                key: ValueKey(_expanded),
                size: const Size(_size, _size),
                painter: _FanShellPainter(
                  leftHanded: _leftHanded,
                  showMain: _expanded,
                  showOuter: _expanded ? items.length : 0,
                  selected: widget.selectedCommand,
                  firstId: widget.first.id,
                  secondId: widget.second.id,
                ),
              ),
            ),
            if (_expanded) ...[
              _label(_select, _point(65, 180), outer: false),
              _label(widget.first, _point(65, 225), outer: false),
              _label(widget.second, _point(65, 270), outer: false),
              for (var i = 0; i < items.length; i++)
                _label(items[i],
                  _point(118, [155.0, 205.0, 255.0][i]), outer: true),
            ] else
              _label(_select, _point(65, 180), outer: false),
            Positioned(
              left: _point(0, 0).dx - 26,
              top: 132,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFFFFE4BB), Color(0xFFFFD0A1),
                      Color(0xFFF4B784)],
                  ),
                  border: Border.all(color: const Color(0xFFFFE8C4)),
                  boxShadow: [
                    BoxShadow(color: ZamerKitColors.peach.withValues(alpha:.36),
                      blurRadius: 24, spreadRadius: 1),
                    const BoxShadow(color: Colors.black45,
                      blurRadius: 14, offset: Offset(0, 6)),
                  ],
                ),
                child: Icon(_expanded ? Icons.close_rounded
                    : Icons.tune_rounded,
                  color: ZamerKitColors.ink, size: 27),
              ),
            ),
            Positioned(
              top: 1,
              left: _leftHanded ? 145 : 8,
              child: _expanded && widget.outer.length > 3
                ? GestureDetector(
                  onTap: _showAll,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ZamerKitColors.panel,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ZamerKitColors.line)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                      child: Text(
                        '${_ringOffset + 1}–${math.min(_ringOffset + 3,
                          widget.outer.length)}/${widget.outer.length}',
                        style: const TextStyle(color: ZamerKitColors.muted,
                          fontSize: 10),
                      ),
                    ),
                  ),
                ) : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FanShellPainter extends CustomPainter {
  const _FanShellPainter({
    required this.leftHanded,
    required this.showMain,
    required this.showOuter,
    required this.selected,
    required this.firstId,
    required this.secondId,
  });
  final bool leftHanded, showMain;
  final int showOuter;
  final String selected, firstId, secondId;

  Offset _polar(double radius, double degrees) {
    final a = degrees * math.pi / 180;
    final x = 158 + radius * math.cos(a);
    return Offset(leftHanded ? 208 - x : x,
      158 + radius * math.sin(a));
  }

  Path _slice(double inner, double outer, double first, double last) {
    final p = Path();
    for (var a = first; a <= last; a += 2) {
      final at = _polar(outer, a);
      if (a == first) { p.moveTo(at.dx, at.dy); }
      else { p.lineTo(at.dx, at.dy); }
    }
    final tip = _polar(outer, last);
    p.lineTo(tip.dx, tip.dy);
    for (var a = last; a >= first; a -= 2) {
      final at = _polar(inner, a);
      p.lineTo(at.dx, at.dy);
    }
    p.close();
    return p;
  }

  void _sector(Canvas canvas, double inner, double outer,
      double a, double b, bool hot) {
    final path = _slice(inner, outer, a, b);
    canvas.drawShadow(path, Colors.black.withValues(alpha: .65), 4, false);
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: hot
          ? const [Color(0xFFAD805C), Color(0xFF594838),
              Color(0xFF303133), Color(0xFFD39B6B)]
          : const [Color(0xFF69696D), Color(0xFF353B42),
              Color(0xFF20272D), Color(0xFF1D2429)],
        stops: const [0, .18, .70, 1],
      ).createShader(path.getBounds()));
    canvas.drawPath(path, Paint()
      ..color = hot ? ZamerKitColors.peach : ZamerKitColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = hot ? 1.3 : .85);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // The SELECT sector has one permanent hit area whether open or closed.
    _sector(canvas, 28, 86, 155, 202, selected == 'select');
    if (showMain) {
      _sector(canvas, 28, 86, 204, 247, selected == firstId);
      _sector(canvas, 28, 86, 249, 293, selected == secondId);
    }
    final angles = <(double, double)>[
      (137, 174), (187, 224), (237, 274),
    ];
    for (var i = 0; i < showOuter; i++) {
      _sector(canvas, 96, 140, angles[i].$1, angles[i].$2, false);
    }
  }

  @override
  bool? hitTest(Offset position) {
    // A transparent section of the dial must never block a CAD wall tap.
    final p = leftHanded
        ? Offset(208 - position.dx, position.dy) : position;
    final d = p - const Offset(158, 158);
    final r = d.distance;
    final a = (math.atan2(d.dy, d.dx) * 180 / math.pi + 360) % 360;
    if (r < 28) return true;
    if (r <= 86) return a >= 155 && a <= (showMain ? 293 : 202);
    if (!showMain || r < 96 || r > 140) return false;
    const wedges = <(double, double)>[
      (137, 174), (187, 224), (237, 274)
    ];
    return wedges.take(showOuter).any(
      (w) => a >= w.$1 && a <= w.$2);
  }

  @override
  bool shouldRepaint(covariant _FanShellPainter old) =>
    leftHanded != old.leftHanded ||
    showMain != old.showMain ||
    showOuter != old.showOuter ||
    selected != old.selected ||
    firstId != old.firstId ||
    secondId != old.secondId;
}

/// The graphite and warm-peach surface system from UI Kit 1.2. Native
/// gradients, not raster screenshots, so taps remain accessible.
class ZamerKitSegment extends StatelessWidget {
  const ZamerKitSegment({
    super.key, required this.label, required this.icon,
    required this.selected, required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limits) {
      final compact = limits.maxWidth < 108;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 12, vertical: 9),
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: selected
                  ? const [Color(0xFFFFE4BB), Color(0xFFFFD7AB),
                      Color(0xFFFFD0A1), Color(0xFFF4B784)]
                  : const [Color(0xFF69696D), Color(0xFF353B42),
                      Color(0xFF20272D), Color(0xFF5C4A3B)],
                stops: const [0, .18, .75, 1],
              ),
              border: Border.all(color: selected
                  ? ZamerKitColors.peach : ZamerKitColors.line),
              boxShadow: selected ? [BoxShadow(
                color: ZamerKitColors.peach.withValues(alpha:.18),
                blurRadius: 18)] : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 16 : 19, color: selected
                    ? ZamerKitColors.ink : ZamerKitColors.peach),
                SizedBox(width: compact ? 3 : 7),
                Flexible(
                  child: Text(label, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: selected
                      ? ZamerKitColors.ink : ZamerKitColors.text,
                      fontSize: compact ? 10 : 12, fontWeight: selected
                        ? FontWeight.w700 : FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
