import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/geometry_service.dart';

enum _ScanMode { calibrate, trace }

class ScanPlanScreen extends StatefulWidget {
  const ScanPlanScreen({super.key, required this.floor, required this.onChanged});
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
    final iw = image.width.toDouble(), ih = image.height.toDouble();
    final scale = math.min(box.width / iw, box.height / ih);
    final w = iw * scale, h = ih * scale;
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
    return math.Point<double>(prev.x + math.cos(snappedA) * len, prev.y + math.sin(snappedA) * len);
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
      final px = math.sqrt(math.pow(p.x - _calA!.x, 2) + math.pow(p.y - _calA!.y, 2));
      final c = TextEditingController(text: '1000');
      final mm = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Известный размер'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Введи реальное расстояние между двумя отмеченными точками.'),
            const SizedBox(height: 10),
            TextField(controller: c, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Расстояние', suffixText: 'мм')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(c.text.replaceAll(',', '.'))), child: const Text('Калибровать')),
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
      math.Point<double> mm(math.Point<double> p) => math.Point((p.x - base.x) * scale, (p.y - base.y) * scale);
      final first = GeometryService.ensureAnchor(widget.floor, mm(_trace.first));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Контур перенесён на план. Проверь контрольный размер и поправь точки при необходимости.')));
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Скан / фото-план')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(_file == null ? '1. Добавь фото плана или БТИ' : _mmPerPx == null ? '2. Укажи масштаб двумя точками' : '3. Обведи стены по фото', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Из галереи'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Камера'))),
                ]),
                if (_mmPerPx != null) ...[
                  const SizedBox(height: 8),
                  Text('Масштаб: 1 пиксель ≈ ${_mmPerPx!.toStringAsFixed(2)} мм. Нажимай последовательно по углам стен.', style: Theme.of(context).textTheme.bodySmall),
                  SwitchListTile.adaptive(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Привязка линий 90° / 45°'),
                    subtitle: const Text('Убирает мелкий перекос при ручной обводке.'),
                    value: _angleSnap,
                    onChanged: (v) => setState(() => _angleSnap = v),
                  ),
                ],
              ]),
            ),
          ),
        ),
        Expanded(
          child: _image == null
              ? const Center(child: Text('Добавь фото плана. Затем отметь на нём один известный размер.'))
              : LayoutBuilder(builder: (context, c) {
                  final size = Size(c.maxWidth, c.maxHeight);
                  final rect = _imageRect(size);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _tap(d, size),
                    child: Stack(children: [
                      Positioned.fromRect(rect: rect, child: Image.file(File(_file!.path), fit: BoxFit.fill)),
                      Positioned.fill(child: CustomPaint(painter: _ScanOverlayPainter(imageSize: Size(_image!.width.toDouble(), _image!.height.toDouble()), imageRect: rect, calA: _calA, calB: _calB, trace: _trace, closed: _closed))),
                    ]),
                  );
                }),
        ),
        if (_file != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(children: [
                if (_mode == _ScanMode.trace) ...[
                  IconButton(onPressed: _trace.isEmpty ? null : () => setState(() { _trace.removeLast(); _closed = false; }), tooltip: 'Назад на точку', icon: const Icon(Icons.undo)),
                  IconButton(onPressed: _trace.length < 3 ? null : () => setState(() => _closed = !_closed), tooltip: 'Замкнуть контур', icon: Icon(_closed ? Icons.link : Icons.link_off)),
                  const SizedBox(width: 4),
                  Expanded(child: FilledButton.icon(onPressed: _busy || _trace.length < 2 ? null : _importWalls, icon: const Icon(Icons.architecture_outlined), label: Text(_closed ? 'Создать замкнутый план' : 'Создать стены'))),
                ] else
                  Expanded(child: TextButton.icon(onPressed: () => setState(() { _calA = null; _calB = null; }), icon: const Icon(Icons.refresh), label: const Text('Выбрать точки масштаба заново'))),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter({required this.imageSize, required this.imageRect, this.calA, this.calB, required this.trace, required this.closed});
  final Size imageSize;
  final Rect imageRect;
  final math.Point<double>? calA;
  final math.Point<double>? calB;
  final List<math.Point<double>> trace;
  final bool closed;

  Offset q(math.Point<double> p) => Offset(imageRect.left + p.x / imageSize.width * imageRect.width, imageRect.top + p.y / imageSize.height * imageRect.height);

  @override
  void paint(Canvas canvas, Size size) {
    final cal = Paint()..color = const Color(0xFFFF8A34)..strokeWidth = 2.5;
    if (calA != null) canvas.drawCircle(q(calA!), 6, cal);
    if (calB != null) {
      canvas.drawCircle(q(calB!), 6, cal);
      canvas.drawLine(q(calA!), q(calB!), cal);
    }
    if (trace.isNotEmpty) {
      final path = Path()..moveTo(q(trace.first).dx, q(trace.first).dy);
      for (final p in trace.skip(1)) { final o = q(p); path.lineTo(o.dx, o.dy); }
      if (closed && trace.length > 2) path.close();
      canvas.drawPath(path, Paint()..color = const Color(0xFF1769E8)..style = PaintingStyle.stroke..strokeWidth = 3);
      for (final p in trace) {
        canvas.drawCircle(q(p), 6, Paint()..color = Colors.white);
        canvas.drawCircle(q(p), 6, Paint()..color = const Color(0xFF1769E8)..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) => true;
}
