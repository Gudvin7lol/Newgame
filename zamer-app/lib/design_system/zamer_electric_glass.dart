import 'package:flutter/material.dart';

/// Presentation component. Command ownership stays with the application.
class ZamerGlassSurface extends StatelessWidget {
  const ZamerGlassSurface({
    super.key,
    required this.child,
    this.selected = false,
    this.primary = false,
    this.pressed = false,
    this.radius = 16,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final bool selected;
  final bool primary;
  final bool pressed;
  final double radius;
  final EdgeInsetsGeometry padding;

  static const peach = Color(0xFFFFC28C);
  static const surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF555558), Color(0xFF383A3E), Color(0xFF27292D), Color(0xFF222428), Color(0xFF373536)],
    stops: [0, .09, .48, .9, 1],
  );
  static const accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD6A9), Color(0xFFFFC18A), Color(0xFFECA776)],
    stops: [0, .46, 1],
  );
  static const inset = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF191B20), Color(0xFF292C31)],
  );
  static const edge = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xA6FFCA9B), Color(0x40B9BDC4), Color(0x33848B96), Color(0x99FFBA80)],
    stops: [0, .27, .7, 1],
  );

  @override
  Widget build(BuildContext context) {
    final borderWidth = selected ? 1.5 : 1.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? peach : null,
        gradient: selected ? null : edge,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: pressed ? const [] : const [
          BoxShadow(color: Color(0x50000000), blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(borderWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: pressed ? inset : (primary ? accent : surface),
            borderRadius: BorderRadius.circular(radius - borderWidth),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

enum ZamerElectricKind { socket, switchPoint, light, tv, internet, board, box, cableOutlet }
enum ZamerElectricIconState { plan, fan, selected, disabled }

/// Raster fallback with no external SVG rendering dependency.
/// Wrap interactive instances in a control with a minimum 48 dp hit target.
class ZamerElectricIcon extends StatelessWidget {
  const ZamerElectricIcon({
    super.key,
    required this.kind,
    this.state = ZamerElectricIconState.plan,
    this.size = 28,
    this.assetRoot = 'assets/electric/icons',
  });
  final ZamerElectricKind kind;
  final ZamerElectricIconState state;
  final double size;
  final String assetRoot;

  static const names = {
    ZamerElectricKind.socket: ('socket', 'Розетка'),
    ZamerElectricKind.switchPoint: ('switch', 'Выключатель'),
    ZamerElectricKind.light: ('light', 'Светильник'),
    ZamerElectricKind.tv: ('tv', 'ТВ'),
    ZamerElectricKind.internet: ('net', 'Интернет'),
    ZamerElectricKind.board: ('board', 'Щит'),
    ZamerElectricKind.box: ('box', 'Распределительная коробка'),
    ZamerElectricKind.cableOutlet: ('outlet', 'Вывод кабеля'),
  };

  @override
  Widget build(BuildContext context) {
    final entry = names[kind]!;
    return Semantics(
      label: entry.$2,
      selected: state == ZamerElectricIconState.selected,
      child: ExcludeSemantics(child: Image.asset(
        '$assetRoot/${entry.$1}_${state.name}.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
      )),
    );
  }
}
