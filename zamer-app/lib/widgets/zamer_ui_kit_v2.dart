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
  bool _expanded = true;
  bool _leftHanded = false;
  int _ringOffset = 0;
  double _dragAmount = 0;
  bool _ringWasDragged = false;

  static const _select = ZamerKitCommand(
    'select', 'Выбрать', Icons.near_me_outlined);
  static const _size = 244.0;

  @override
  void didUpdateWidget(covariant ZamerKitFan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contextId != widget.contextId) _ringOffset = 0;
  }

  Offset _point(double radius, double angle) {
    final rad = angle * math.pi / 180;
    final x = 188 + radius * math.cos(rad);
    return Offset(_leftHanded ? _size - x : x,
        188 + radius * math.sin(rad));
  }

  Widget _label(ZamerKitCommand command, Offset pos, {
    required bool outer,
  }) {
    final active = command.id == widget.selectedCommand;
    final foreground = !command.enabled
        ? ZamerKitColors.muted.withValues(alpha: .48)
        : active ? ZamerKitColors.peach : ZamerKitColors.text;
    final w = outer ? 96.0 : 86.0;
    return Positioned(
      left: pos.dx - w / 2,
      top: pos.dy - (outer ? 32 : 30),
      child: IgnorePointer(
        child: SizedBox(
          width: w,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(command.icon, size: outer ? 18 : 22, color: foreground),
              const SizedBox(height: 2),
              Text(command.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: outer ? 10.5 : 11.5,
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
    final v = p - const Offset(188, 188);
    final r = v.distance;
    final angle = (math.atan2(v.dy, v.dx) * 180 / math.pi + 360) % 360;

    if (r <= 31) {
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
    if (r >= 30 && r <= 103) {
      final candidates = <(double, ZamerKitCommand)>[
        (180, _select), (225, widget.first), (270, widget.second),
      ];
      for (final entry in candidates) {
        if ((angle - entry.$1).abs() <= 23 && entry.$2.enabled) {
          widget.onCommand(entry.$2.id);
          return;
        }
      }
    }
    if (r >= 108 && r <= 176) {
      const angles = [180.0, 220.0, 260.0];
      for (var i = 0; i < 3; i++) {
        if ((angle - angles[i]).abs() <= 19 &&
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
    return SizedBox(
      width: _size, height: _size,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: _tap,
        onLongPress: _showAll,
        onPanStart: (_) {
          _dragAmount = 0;
          _ringWasDragged = false;
        },
        onPanUpdate: (d) {
          _dragAmount += d.delta.dx + d.delta.dy;
          if (_dragAmount.abs() >= 24) {
            _ringWasDragged = true;
            _stepRing(_dragAmount > 0 ? 1 : -1);
            _dragAmount = 0;
          }
        },
        onPanEnd: (_) {
          // Release after scrolling must never fire the command under finger.
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedOpacity(
              opacity: _expanded ? 1 : 0,
              duration: const Duration(milliseconds: 240),
              child: IgnorePointer(
                ignoring: !_expanded,
                child: CustomPaint(
                  size: const Size(_size, _size),
                  painter: _FanShellPainter(
                    leftHanded: _leftHanded,
                    showMain: true,
                    showOuter: items.length,
                    selected: widget.selectedCommand,
                    firstId: widget.first.id,
                    secondId: widget.second.id,
                  ),
                ),
              ),
            ),
            if (_expanded) ...[
              _label(_select, _point(69, 180), outer: false),
              _label(widget.first, _point(69, 225), outer: false),
              _label(widget.second, _point(69, 270), outer: false),
              for (var i = 0; i < items.length; i++)
                _label(items[i],
                  _point(146, [180.0, 220.0, 260.0][i]), outer: true),
            ] else
              _label(_select, _point(69, 180), outer: false),
            Positioned(
              left: _point(0, 0).dx - 29,
              top: 159,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                width: 58, height: 58,
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
              left: _leftHanded ? 165 : 8,
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
    final x = 188 + radius * math.cos(a);
    return Offset(leftHanded ? 244 - x : x,
      188 + radius * math.sin(a));
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
    if (showMain) {
      _sector(canvas, 30, 103, 155, 202, selected == 'select');
      _sector(canvas, 30, 103, 204, 247, selected == firstId);
      _sector(canvas, 30, 103, 249, 293, selected == secondId);
    }
    final angles = <(double, double)>[
      (158, 199), (201, 240), (242, 282),
    ];
    for (var i = 0; i < showOuter; i++) {
      _sector(canvas, 113, 173, angles[i].$1, angles[i].$2, false);
    }
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
                  ? const [Color(0xFFFFE4BB), Color(0xFFFFD0A1),
                      Color(0xFFF4B784)]
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
