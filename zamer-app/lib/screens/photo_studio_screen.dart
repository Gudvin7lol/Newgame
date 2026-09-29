import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../renderer3d/zamer_gpu_viewport.dart';

class PhotoStudioScreen extends StatefulWidget {
  const PhotoStudioScreen({
    super.key,
    required this.floor,
    required this.rotation,
    required this.tilt,
    required this.zoom,
    required this.pan,
  });

  final FloorPlan floor;
  final double rotation;
  final double tilt;
  final double zoom;
  final Offset pan;

  @override
  State<PhotoStudioScreen> createState() => _PhotoStudioScreenState();
}

class _PhotoStudioScreenState extends State<PhotoStudioScreen> {
  final GlobalKey<ZamerGpuViewportState> _gpuKey =
      GlobalKey<ZamerGpuViewportState>();

  late double _rotation;
  late double _tilt;
  late double _zoom;
  late Offset _pan;
  double _gestureZoom = 1;
  Offset _gesturePan = Offset.zero;
  Offset _gestureFocal = Offset.zero;
  int _gesturePointers = 0;

  String _mode = 'Фото';
  String _quality = 'Высокий';
  String _time = 'День';
  double _lens = 1;
  bool _grid = true;
  bool _hdr = true;
  bool _stabilization = true;
  bool _horizon = true;
  bool _rendering = false;

  static const _sand = Color(0xFFF1C79E);
  static const _surface = Color(0xFF10181D);
  static const _border = Color(0xFF26343B);

  @override
  void initState() {
    super.initState();
    _rotation = widget.rotation;
    _tilt = widget.tilt;
    _zoom = widget.zoom;
    _pan = widget.pan;
  }

  void _onScaleStart(ScaleStartDetails d) {
    _gestureZoom = _zoom;
    _gesturePan = _pan;
    _gestureFocal = d.focalPoint;
    _gesturePointers = d.pointerCount;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount != _gesturePointers) {
      _gesturePointers = d.pointerCount;
      _gestureZoom = _zoom / math.max(.001, d.scale);
      _gesturePan = _pan;
      _gestureFocal = d.focalPoint;
      return;
    }
    setState(() {
      if (d.pointerCount >= 2) {
        _zoom = (_gestureZoom * d.scale).clamp(.25, 5).toDouble();
        _pan = _gesturePan + (d.focalPoint - _gestureFocal);
      } else {
        final angle = _rotation + d.focalPointDelta.dx * .008;
        _rotation = math.atan2(math.sin(angle), math.cos(angle));
        _tilt = (_tilt - d.focalPointDelta.dy * .005)
            .clamp(.15, 1.48)
            .toDouble();
      }
    });
  }

  void _selectLens(double value) {
    setState(() {
      _lens = value;
      _zoom = (widget.zoom * value).clamp(.28, 4.5).toDouble();
    });
  }

  Future<void> _selectMode(String mode) async {
    if (mode == 'Панорама' || mode == 'AR') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$mode появится после подключения отдельного режима камеры.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _mode = mode;
      if (mode == '4K') _quality = 'Ультра';
    });
  }

  (int, int) _renderSize() {
    final portrait =
        MediaQuery.sizeOf(context).height >= MediaQuery.sizeOf(context).width;
    final size = switch (_mode == '4K' ? 'Ультра' : _quality) {
      'Черновой' => (1080, 1920),
      'Стандарт' => (1440, 2560),
      'Высокий' => (2160, 3840),
      _ => (2160, 3840),
    };
    return portrait ? size : (size.$2, size.$1);
  }

  Future<void> _capture() async {
    if (_rendering) return;
    final renderer = _gpuKey.currentState;
    if (renderer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('3D-сцена ещё загружается.')),
      );
      return;
    }
    final size = _renderSize();
    setState(() => _rendering = true);
    try {
      final png = await renderer.renderPng(
        width: size.$1,
        height: size.$2,
        photoQuality: true,
      );
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/zamer-photo-${DateTime.now().millisecondsSinceEpoch}-${size.$1}x${size.$2}.png',
      );
      await file.writeAsBytes(png, flush: true);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog.fullscreen(
          backgroundColor: const Color(0xFF090E11),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                      const Expanded(
                        child: Text(
                          'Готовый кадр',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: .5,
                    maxScale: 5,
                    child: Center(
                      child: Image.memory(png, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Назад'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Share.shareXFiles([
                            XFile(file.path),
                          ], text: 'Фото из проекта «Замер»'),
                          icon: const Icon(Icons.ios_share_outlined),
                          label: const Text('Сохранить / поделиться'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Не удалось создать кадр: $e')));
      }
    } finally {
      if (mounted) setState(() => _rendering = false);
    }
  }

  Future<void> _showTimeSheet() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Время суток',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              for (final item in const ['День', 'Закат', 'Вечер', 'Ночь'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item == 'День'
                        ? Icons.wb_sunny_outlined
                        : item == 'Ночь'
                        ? Icons.nightlight_outlined
                        : Icons.wb_twilight_outlined,
                  ),
                  title: Text(item),
                  trailing: item == _time
                      ? const Icon(Icons.check, color: _sand)
                      : null,
                  onTap: () => Navigator.pop(context, item),
                ),
              const Text(
                'Сейчас это состояние интерфейса. Управление светом сцены подключается отдельным проходом рендера.',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF7F8B91)),
              ),
            ],
          ),
        ),
      ),
    );
    if (value != null) setState(() => _time = value);
  }

  Future<void> _showQualitySheet() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Качество рендера',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              for (final item in const [
                'Черновой',
                'Стандарт',
                'Высокий',
                'Ультра',
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item),
                  subtitle: Text(
                    item == 'Черновой'
                        ? '1080p • быстро'
                        : item == 'Стандарт'
                        ? '1440p • баланс'
                        : item == 'Высокий'
                        ? '4K • финальный кадр'
                        : '4K • максимальные настройки',
                  ),
                  trailing: item == _quality
                      ? const Icon(Icons.check, color: _sand)
                      : null,
                  onTap: () => Navigator.pop(context, item),
                ),
            ],
          ),
        ),
      ),
    );
    if (value != null) setState(() => _quality = value);
  }

  Future<void> _showParametersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Параметры камеры',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('HDR'),
                  value: _hdr,
                  onChanged: (v) {
                    setState(() => _hdr = v);
                    setSheet(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Стабилизация'),
                  value: _stabilization,
                  onChanged: (v) {
                    setState(() => _stabilization = v);
                    setSheet(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Сетка'),
                  value: _grid,
                  onChanged: (v) {
                    setState(() => _grid = v);
                    setSheet(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Уровень горизонта'),
                  value: _horizon,
                  onChanged: (v) {
                    setState(() => _horizon = v);
                    setSheet(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D10),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  const Expanded(
                    child: Text(
                      'Фото',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Параметры',
                    onPressed: _showParametersSheet,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final item in const ['Фото', '4K', 'Панорама', 'AR'])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _ModeButton(
                          label: item,
                          icon: item == 'Фото'
                              ? Icons.photo_camera_outlined
                              : item == '4K'
                              ? Icons.high_quality_outlined
                              : item == 'Панорама'
                              ? Icons.panorama_horizontal_outlined
                              : Icons.view_in_ar_outlined,
                          selected: _mode == item,
                          available: item == 'Фото' || item == '4K',
                          onTap: () => _selectMode(item),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        child: ZamerGpuViewport(
                          key: _gpuKey,
                          floor: widget.floor,
                          rotation: _rotation,
                          tilt: _tilt,
                          zoom: _zoom,
                          cutaway: false,
                          pan: _pan,
                          walkMode: false,
                          walkX: 0,
                          walkY: 0,
                        ),
                      ),
                      if (_grid)
                        const IgnorePointer(
                          child: CustomPaint(painter: _PhotoGridPainter()),
                        ),
                      if (_horizon)
                        const IgnorePointer(
                          child: Center(
                            child: SizedBox(
                              width: 74,
                              child: Divider(
                                color: Color(0x99F1C79E),
                                thickness: 1,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 10,
                        top: 12,
                        bottom: 12,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xB90C1216),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _border),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final lens in const [.5, 1.0, 2.0, 3.0])
                                  _LensButton(
                                    label: lens == 1
                                        ? '1×'
                                        : '${lens.toStringAsFixed(lens < 1 ? 1 : 0)}×',
                                    selected: _lens == lens,
                                    onTap: () => _selectLens(lens),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 12,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xB90C1216),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Сетка',
                                onPressed: () => setState(() => _grid = !_grid),
                                icon: Icon(
                                  Icons.grid_3x3,
                                  color: _grid ? _sand : null,
                                ),
                              ),
                              IconButton(
                                tooltip: 'HDR',
                                onPressed: () => setState(() => _hdr = !_hdr),
                                icon: Icon(
                                  Icons.hdr_on_outlined,
                                  color: _hdr ? _sand : null,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Параметры',
                                onPressed: _showParametersSheet,
                                icon: const Icon(Icons.tune_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xC80C1216),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _border),
                          ),
                          child: Text(
                            '$_time • ${_mode == '4K' ? '4K' : _quality}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  const SizedBox(width: 54),
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: _rendering ? null : _capture,
                        child: Container(
                          width: 72,
                          height: 72,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _rendering
                                  ? const Color(0xFF5C6569)
                                  : Colors.white,
                            ),
                            child: _rendering
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 54,
                    child: IconButton(
                      tooltip: 'Повернуть камеру',
                      onPressed: () => setState(() => _rotation += math.pi),
                      icon: const Icon(Icons.cameraswitch_outlined),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _BottomAction(
                      icon: Icons.wb_sunny_outlined,
                      label: 'Время суток',
                      value: _time,
                      onTap: _showTimeSheet,
                    ),
                  ),
                  Expanded(
                    child: _BottomAction(
                      icon: Icons.tune_rounded,
                      label: 'Параметры',
                      value: _lens == 1 ? '1×' : '${_lens}×',
                      onTap: _showParametersSheet,
                    ),
                  ),
                  Expanded(
                    child: _BottomAction(
                      icon: Icons.view_in_ar_outlined,
                      label: 'Качество',
                      value: _mode == '4K' ? '4K' : _quality,
                      onTap: _showQualitySheet,
                    ),
                  ),
                  Expanded(
                    child: _BottomAction(
                      icon: Icons.photo_library_outlined,
                      label: 'Галерея',
                      value: 'Кадры',
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Галерея проекта будет подключена отдельным проходом.',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? _PhotoStudioScreenState._sand : const Color(0xFF121A1F),
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Opacity(
        opacity: available ? 1 : .5,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected
                    ? const Color(0xFF21170F)
                    : const Color(0xFFD4DBDE),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? const Color(0xFF21170F)
                      : const Color(0xFFD4DBDE),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LensButton extends StatelessWidget {
  const _LensButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: Container(
      width: 42,
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.symmetric(vertical: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _PhotoStudioScreenState._sand : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: selected ? const Color(0xFF21170F) : Colors.white,
        ),
      ),
    ),
  );
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8,
              color: Color(0xFF8F9A9F),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PhotoGridPainter extends CustomPainter {
  const _PhotoGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x44FFFFFF)
      ..strokeWidth = .7;
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
