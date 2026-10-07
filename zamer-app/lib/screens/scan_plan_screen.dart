import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../services/geometry_service.dart';

enum _ScanMode { calibrate, trace }

class ScanPlanScreen extends StatefulWidget {
  const ScanPlanScreen({
    super.key,
    required this.floor,
    required this.onChanged,
  });

  final FloorPlan floor;
  final Future<void> Function() onChanged;

  @override
  State<ScanPlanScreen> createState() => _ScanPlanScreenState();
}

class _ScanPlanScreenState extends State<ScanPlanScreen> {
  final _picker = ImagePicker();
  XFile? _file;
  ui.Image? _image;
  _ScanMode _mode = _ScanMode.calibrate;
  math.Point<double>? _calA;
  math.Point<double>? _calB;
  double? _mmPerPx;
  final _trace = <math.Point<double>>[];
  bool _closed = false;
  bool _busy = false;
  bool _angleSnap = true;

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 95);
    if (file == null) return;
    final bytes = await File(file.path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() {
      _file = file;
      _image = frame.image;
      _mode = _ScanMode.calibrate;
      _calA = null;
      _calB = null;
      _mmPerPx = null;
      _trace.clear();
      _closed = false;
    });
  }

  Rect _imageRect(Size box) {
    final image = _image;
    if (image == null) return Rect.zero;
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    final scale = math.min(box.width / iw, box.height / ih);
    final w = iw * scale;
    final h = ih * scale;
    return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
  }

  math.Point<double>? _toImage(Offset local, Size box) {
    final image = _image;
    if (image == null) return null;
    final rect = _imageRect(box);
    if (!rect.contains(local)) return null;
    return math.Point(
      (local.dx - rect.left) / rect.width * image.width,
      (local.dy - rect.top) / rect.height * image.height,
    );
  }

  math.Point<double> _snapTracePoint(math.Point<double> raw) {
    if (!_angleSnap || _trace.isEmpty) return raw;
    final prev = _trace.last;
    final dx = raw.x - prev.x;
    final dy = raw.y - prev.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 2) return raw;
    final a = math.atan2(dy, dx);
    const step = math.pi / 4;
    final snappedA = (a / step).round() * step;
    var diff = (a - snappedA).abs();
    if (diff > math.pi) diff = 2 * math.pi - diff;
    if (diff > 10 * math.pi / 180) return raw;
    return math.Point<double>(
      prev.x + math.cos(snappedA) * len,
      prev.y + math.sin(snappedA) * len,
    );
  }

  Future<void> _tap(TapUpDetails d, Size box) async {
    final p = _toImage(d.localPosition, box);
    if (p == null) return;
    if (_mode == _ScanMode.calibrate) {
      if (_calA == null) {
        setState(() => _calA = p);
        return;
      }
      setState(() => _calB = p);
      final px = math.sqrt(
        math.pow(p.x - _calA!.x, 2) + math.pow(p.y - _calA!.y, 2),
      );
      final c = TextEditingController(text: '1000');
      final mm = await showDialog<double>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Известный размер'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Введи реальное расстояние между двумя отмеченными точками.',
              ),
              const SizedBox(height: ZamerSpace.md),
              TextField(
                controller: c,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Расстояние',
                  suffixText: 'мм',
                  prefixIcon: Icon(Icons.straighten_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                double.tryParse(c.text.replaceAll(',', '.')),
              ),
              child: const Text('Калибровать'),
            ),
          ],
        ),
      );
      if (mm == null || mm <= 0 || px <= 0) {
        setState(() => _calB = null);
        return;
      }
      setState(() {
        _mmPerPx = mm / px;
        _mode = _ScanMode.trace;
      });
      return;
    }

    if (_closed) return;
    setState(() => _trace.add(_snapTracePoint(p)));
  }

  Future<void> _importWalls() async {
    final scale = _mmPerPx;
    if (scale == null || _trace.length < 2) return;
    setState(() => _busy = true);
    try {
      final base = _trace.first;
      math.Point<double> mm(math.Point<double> p) => math.Point(
        (p.x - base.x) * scale,
        (p.y - base.y) * scale,
      );
      final first = GeometryService.ensureAnchor(
        widget.floor,
        mm(_trace.first),
      );
      var current = first;
      for (var i = 1; i < _trace.length; i++) {
        current = GeometryService.addWallFromNode(
          widget.floor,
          startNodeId: current.id,
          endPoint: mm(_trace[i]),
          type: WallType.exterior,
          thicknessMm: 300,
          material: WallMaterial.gasBlock,
        );
      }
      if (_closed && _trace.length > 2 && current.id != first.id) {
        GeometryService.addWallFromNode(
          widget.floor,
          startNodeId: current.id,
          endPoint: math.Point(first.xMm, first.yMm),
          type: WallType.exterior,
          thicknessMm: 300,
          material: WallMaterial.gasBlock,
        );
      }
      await widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Контур перенесён на план. Проверь контрольный размер и точки.',
          ),
        ),
      );
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int get _step => _file == null ? 0 : (_mmPerPx == null ? 1 : 2);

  String get _instruction => switch (_step) {
    0 => 'Добавь фото плана или БТИ',
    1 => _calA == null
        ? 'Отметь первую точку известного размера'
        : 'Отметь вторую точку известного размера',
    _ => _closed
        ? 'Контур замкнут. Проверь точки и создай план.'
        : 'Нажимай последовательно по углам стен',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Скан / импорт плана'),
            Text(widget.floor.name, style: ZamerTypography.caption),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              ZamerSpace.md,
              ZamerSpace.md,
              ZamerSpace.md,
              ZamerSpace.sm,
            ),
            decoration: const BoxDecoration(
              color: ZamerColors.surfaceLow,
              border: Border(
                bottom: BorderSide(color: ZamerColors.outlineSoft),
              ),
            ),
            child: Column(
              children: [
                _StepProgress(current: _step),
                const SizedBox(height: ZamerSpace.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ZamerColors.accent.withValues(alpha: .11),
                        borderRadius: BorderRadius.circular(ZamerRadius.sm),
                      ),
                      child: Icon(
                        _step == 0
                            ? Icons.add_photo_alternate_outlined
                            : _step == 1
                            ? Icons.straighten_rounded
                            : Icons.polyline_outlined,
                        size: 19,
                        color: ZamerColors.accent,
                      ),
                    ),
                    const SizedBox(width: ZamerSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _instruction,
                            style: const TextStyle(
                              color: ZamerColors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _mmPerPx == null
                                ? 'Точность импорта зависит от правильной калибровки масштаба.'
                                : '1 пиксель ≈ ${_mmPerPx!.toStringAsFixed(2)} мм • ${_trace.length} точек',
                            style: ZamerTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZamerSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Галерея'),
                      ),
                    ),
                    const SizedBox(width: ZamerSpace.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Камера'),
                      ),
                    ),
                  ],
                ),
                if (_mmPerPx != null) ...[
                  const SizedBox(height: ZamerSpace.sm),
                  ZPanel(
                    padding: EdgeInsets.zero,
                    child: ZLayerToggle(
                      label: 'Привязка линий 90° / 45°',
                      icon: Icons.architecture_outlined,
                      value: _angleSnap,
                      onChanged: (v) => setState(() => _angleSnap = v),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _image == null
                ? const ZEmptyState(
                    icon: Icons.add_photo_alternate_outlined,
                    title: 'Добавь исходный план',
                    subtitle:
                        'Подойдёт фото БТИ, чертёж или снимок бумажного плана. Затем укажи один известный размер для масштаба.',
                  )
                : Padding(
                    padding: const EdgeInsets.all(ZamerSpace.sm),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: ZamerColors.surfaceLow,
                        borderRadius: BorderRadius.circular(ZamerRadius.lg),
                        border: Border.all(color: ZamerColors.outline),
                      ),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final size = Size(c.maxWidth, c.maxHeight);
                          final rect = _imageRect(size);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (d) => _tap(d, size),
                            child: Stack(
                              children: [
                                Positioned.fromRect(
                                  rect: rect,
                                  child: Image.file(
                                    File(_file!.path),
                                    fit: BoxFit.fill,
                                  ),
                                ),
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _ScanOverlayPainter(
                                      imageSize: Size(
                                        _image!.width.toDouble(),
                                        _image!.height.toDouble(),
                                      ),
                                      imageRect: rect,
                                      calA: _calA,
                                      calB: _calB,
                                      trace: _trace,
                                      closed: _closed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
          if (_file != null)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  ZamerSpace.md,
                  ZamerSpace.sm,
                  ZamerSpace.md,
                  ZamerSpace.md,
                ),
                decoration: const BoxDecoration(
                  color: ZamerColors.surfaceLow,
                  border: Border(
                    top: BorderSide(color: ZamerColors.outlineSoft),
                  ),
                ),
                child: _mode == _ScanMode.trace
                    ? Row(
                        children: [
                          IconButton(
                            onPressed: _trace.isEmpty
                                ? null
                                : () => setState(() {
                                    _trace.removeLast();
                                    _closed = false;
                                  }),
                            tooltip: 'Назад на точку',
                            icon: const Icon(Icons.undo_rounded),
                          ),
                          IconButton(
                            onPressed: _trace.length < 3
                                ? null
                                : () => setState(() => _closed = !_closed),
                            tooltip: _closed
                                ? 'Разомкнуть контур'
                                : 'Замкнуть контур',
                            icon: Icon(
                              _closed ? Icons.link_rounded : Icons.link_off,
                              color: _closed ? ZamerColors.success : null,
                            ),
                          ),
                          const SizedBox(width: ZamerSpace.xs),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _busy || _trace.length < 2
                                  ? null
                                  : _importWalls,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.architecture_outlined),
                              label: Text(
                                _closed
                                    ? 'Создать замкнутый план'
                                    : 'Создать стены',
                              ),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _calA = null;
                            _calB = null;
                          }),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Выбрать точки масштаба заново'),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.photo_outlined, 'Фото'),
      (Icons.straighten_rounded, 'Масштаб'),
      (Icons.polyline_outlined, 'Контур'),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: _StepItem(
              icon: items[i].$1,
              label: items[i].$2,
              active: i == current,
              complete: i < current,
            ),
          ),
          if (i < items.length - 1)
            Container(
              width: 20,
              height: 1,
              color: i < current
                  ? ZamerColors.success
                  : ZamerColors.outline,
            ),
        ],
      ],
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.complete,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color = complete
        ? ZamerColors.success
        : active
        ? ZamerColors.accent
        : ZamerColors.textFaint;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          complete ? Icons.check_circle_rounded : icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: active || complete ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter({
    required this.imageSize,
    required this.imageRect,
    this.calA,
    this.calB,
    required this.trace,
    required this.closed,
  });

  final Size imageSize;
  final Rect imageRect;
  final math.Point<double>? calA;
  final math.Point<double>? calB;
  final List<math.Point<double>> trace;
  final bool closed;

  Offset q(math.Point<double> p) => Offset(
    imageRect.left + p.x / imageSize.width * imageRect.width,
    imageRect.top + p.y / imageSize.height * imageRect.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final cal = Paint()
      ..color = ZamerColors.warning
      ..strokeWidth = 2.5;
    if (calA != null) canvas.drawCircle(q(calA!), 6, cal);
    if (calB != null) {
      canvas.drawCircle(q(calB!), 6, cal);
      canvas.drawLine(q(calA!), q(calB!), cal);
    }
    if (trace.isNotEmpty) {
      final path = Path()..moveTo(q(trace.first).dx, q(trace.first).dy);
      for (final p in trace.skip(1)) {
        final o = q(p);
        path.lineTo(o.dx, o.dy);
      }
      if (closed && trace.length > 2) path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = closed ? ZamerColors.success : ZamerColors.info
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      for (final p in trace) {
        canvas.drawCircle(q(p), 6, Paint()..color = ZamerColors.textPrimary);
        canvas.drawCircle(
          q(p),
          6,
          Paint()
            ..color = closed ? ZamerColors.success : ZamerColors.info
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) => true;
}
