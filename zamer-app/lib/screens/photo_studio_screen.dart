import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../design_system/zamer_components.dart';
import '../design_system/zamer_tokens.dart';
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
  ZamerPhotoTime _time = ZamerPhotoTime.day;
  double _lens = 1;
  bool _grid = true;
  bool _hdr = true;
  bool _stabilization = true;
  bool _horizon = true;
  bool _rendering = false;

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

  String get _resolutionLabel {
    final size = _renderSize();
    return '${size.$1}×${size.$2}';
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
          backgroundColor: ZamerColors.background,
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZamerSpace.sm,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: ZamerColors.outlineSoft),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Готовый кадр',
                              style: TextStyle(
                                color: ZamerColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${size.$1}×${size.$2} PNG',
                              style: ZamerTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 44),
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
                Container(
                  padding: const EdgeInsets.all(ZamerSpace.md),
                  decoration: const BoxDecoration(
                    color: ZamerColors.surfaceLow,
                    border: Border(
                      top: BorderSide(color: ZamerColors.outlineSoft),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Назад'),
                        ),
                      ),
                      const SizedBox(width: ZamerSpace.sm),
                      Expanded(
                        flex: 2,
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

  String _timeLabel(ZamerPhotoTime value) => switch (value) {
    ZamerPhotoTime.day => 'День',
    ZamerPhotoTime.sunset => 'Закат',
    ZamerPhotoTime.evening => 'Вечер',
    ZamerPhotoTime.night => 'Ночь',
  };

  IconData _timeIcon(ZamerPhotoTime value) => switch (value) {
    ZamerPhotoTime.day => Icons.wb_sunny_outlined,
    ZamerPhotoTime.sunset => Icons.wb_twilight_outlined,
    ZamerPhotoTime.evening => Icons.brightness_4_outlined,
    ZamerPhotoTime.night => Icons.nightlight_outlined,
  };

  Future<void> _showTimeSheet() async {
    final value = await showModalBottomSheet<ZamerPhotoTime>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ZSheetFrame(
        title: 'Время суток',
        description: 'Меняет окружение, направление и цвет основного света в превью и финальном рендере.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in ZamerPhotoTime.values)
              _SelectionTile(
                icon: _timeIcon(item),
                title: _timeLabel(item),
                selected: item == _time,
                onTap: () => Navigator.pop(sheetContext, item),
              ),
          ],
        ),
      ),
    );
    if (value != null) setState(() => _time = value);
  }

  Future<void> _showQualitySheet() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ZSheetFrame(
        title: 'Качество рендера',
        description: 'Финальные режимы создают настоящий PNG нужного размера.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in const [
              'Черновой',
              'Стандарт',
              'Высокий',
              'Ультра',
            ])
              _SelectionTile(
                icon: item == 'Черновой'
                    ? Icons.speed_rounded
                    : item == 'Стандарт'
                    ? Icons.balance_rounded
                    : item == 'Высокий'
                    ? Icons.auto_awesome_outlined
                    : Icons.high_quality_outlined,
                title: item,
                subtitle: item == 'Черновой'
                    ? '1080p • быстро'
                    : item == 'Стандарт'
                    ? '1440p • баланс'
                    : item == 'Высокий'
                    ? '4K • финальный кадр'
                    : '4K • максимальные настройки',
                selected: item == _quality,
                onTap: () => Navigator.pop(sheetContext, item),
              ),
          ],
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
        builder: (context, setSheet) => ZSheetFrame(
          title: 'Параметры камеры',
          description: 'Настройки кадрирования и вспомогательных элементов.',
          child: ZPanel(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ZLayerToggle(
                  label: 'HDR',
                  icon: Icons.hdr_on_outlined,
                  value: _hdr,
                  onChanged: (v) {
                    setState(() => _hdr = v);
                    setSheet(() {});
                  },
                ),
                ZLayerToggle(
                  label: 'Стабилизация',
                  icon: Icons.motion_photos_auto_outlined,
                  value: _stabilization,
                  onChanged: (v) {
                    setState(() => _stabilization = v);
                    setSheet(() {});
                  },
                ),
                ZLayerToggle(
                  label: 'Сетка третей',
                  icon: Icons.grid_3x3,
                  value: _grid,
                  onChanged: (v) {
                    setState(() => _grid = v);
                    setSheet(() {});
                  },
                ),
                ZLayerToggle(
                  label: 'Уровень горизонта',
                  icon: Icons.horizontal_rule_rounded,
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
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: ZamerSpace.sm),
              decoration: const BoxDecoration(
                color: ZamerColors.background,
                border: Border(
                  bottom: BorderSide(color: ZamerColors.outlineSoft),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Photo Render',
                          style: TextStyle(
                            color: ZamerColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(_resolutionLabel, style: ZamerTypography.caption),
                      ],
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZamerSpace.md,
                ZamerSpace.sm,
                ZamerSpace.md,
                0,
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: ZamerColors.surfaceLow,
                  borderRadius: BorderRadius.circular(ZamerRadius.md),
                  border: Border.all(color: ZamerColors.outlineSoft),
                ),
                child: Row(
                  children: [
                    for (final item in const ['Фото', '4K', 'Панорама', 'AR'])
                      Expanded(
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: ZamerSpace.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: ZamerSpace.sm),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: ZamerColors.surfaceLow,
                    borderRadius: BorderRadius.circular(ZamerRadius.lg),
                    border: Border.all(color: ZamerColors.outline),
                  ),
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
                          photoPreview: true,
                          photoTime: _time,
                          photoHdr: _hdr,
                        ),
                      ),
                      if (_grid)
                        const IgnorePointer(
                          child: CustomPaint(painter: _PhotoGridPainter()),
                        ),
                      if (_horizon)
                        IgnorePointer(
                          child: Center(
                            child: SizedBox(
                              width: 76,
                              child: Divider(
                                color: ZamerColors.accent.withValues(alpha: .7),
                                thickness: 1,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: ZamerSpace.sm,
                        top: ZamerSpace.md,
                        bottom: ZamerSpace.md,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _FloatingPanel(
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
                        right: ZamerSpace.sm,
                        top: ZamerSpace.md,
                        child: _FloatingPanel(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _OverlayAction(
                                tooltip: 'Сетка',
                                icon: Icons.grid_3x3,
                                selected: _grid,
                                onTap: () => setState(() => _grid = !_grid),
                              ),
                              _OverlayAction(
                                tooltip: 'HDR',
                                icon: Icons.hdr_on_outlined,
                                selected: _hdr,
                                onTap: () => setState(() => _hdr = !_hdr),
                              ),
                              _OverlayAction(
                                tooltip: 'Параметры',
                                icon: Icons.tune_rounded,
                                onTap: _showParametersSheet,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: ZamerSpace.md,
                        bottom: ZamerSpace.md,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ZamerSpace.sm,
                            vertical: ZamerSpace.xs,
                          ),
                          decoration: BoxDecoration(
                            color: ZamerColors.surfaceLow.withValues(
                              alpha: .92,
                            ),
                            borderRadius: BorderRadius.circular(ZamerRadius.sm),
                            border: Border.all(color: ZamerColors.outlineSoft),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wb_sunny_outlined,
                                size: 14,
                                color: ZamerColors.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${_timeLabel(_time)} • ${_mode == '4K' ? '4K' : _quality}',
                                style: const TextStyle(
                                  color: ZamerColors.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZamerSpace.md,
                ZamerSpace.sm,
                ZamerSpace.md,
                ZamerSpace.sm,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Center(
                      child: _CaptureButton(
                        rendering: _rendering,
                        onTap: _capture,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
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
              margin: const EdgeInsets.fromLTRB(
                ZamerSpace.sm,
                0,
                ZamerSpace.sm,
                ZamerSpace.sm,
              ),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: ZamerColors.surfaceLow,
                borderRadius: BorderRadius.circular(ZamerRadius.lg),
                border: Border.all(color: ZamerColors.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _BottomAction(
                      icon: Icons.wb_sunny_outlined,
                      label: 'Время',
                      value: _timeLabel(_time),
                      onTap: _showTimeSheet,
                    ),
                  ),
                  Expanded(
                    child: _BottomAction(
                      icon: Icons.camera_outlined,
                      label: 'Объектив',
                      value: _lens == 1 ? '1×' : '${_lens}×',
                      onTap: _showParametersSheet,
                    ),
                  ),
                  Expanded(
                    child: _BottomAction(
                      icon: Icons.auto_awesome_outlined,
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

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ZamerSpace.xs),
    child: Material(
      color: selected
          ? ZamerColors.accent.withValues(alpha: .10)
          : ZamerColors.surface,
      borderRadius: BorderRadius.circular(ZamerRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZamerRadius.md),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZamerRadius.md),
            border: Border.all(
              color: selected ? ZamerColors.accent : ZamerColors.outlineSoft,
            ),
          ),
          child: ListTile(
            leading: Icon(
              icon,
              color: selected ? ZamerColors.accent : ZamerColors.textSecondary,
            ),
            title: Text(title),
            subtitle: subtitle == null ? null : Text(subtitle!),
            trailing: selected
                ? const Icon(Icons.check_rounded, color: ZamerColors.accent)
                : null,
          ),
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) {
    final foreground = selected
        ? ZamerColors.accentInk
        : ZamerColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? ZamerColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(ZamerRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ZamerRadius.sm),
          child: Opacity(
            opacity: available ? 1 : .42,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    borderRadius: BorderRadius.circular(ZamerRadius.sm),
    child: Container(
      width: 42,
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.symmetric(vertical: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? ZamerColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(ZamerRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: selected ? ZamerColors.accentInk : ZamerColors.textPrimary,
        ),
      ),
    ),
  );
}

class _FloatingPanel extends StatelessWidget {
  const _FloatingPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 3),
    decoration: BoxDecoration(
      color: ZamerColors.surfaceLow.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(ZamerRadius.md),
      border: Border.all(color: ZamerColors.outline),
    ),
    child: child,
  );
}

class _OverlayAction extends StatelessWidget {
  const _OverlayAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(
      icon,
      color: selected ? ZamerColors.accent : ZamerColors.textSecondary,
    ),
  );
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.rendering, required this.onTap});

  final bool rendering;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: rendering ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 70,
      height: 70,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: rendering ? ZamerColors.textFaint : ZamerColors.accent,
          width: 3,
        ),
        boxShadow: rendering
            ? null
            : [
                BoxShadow(
                  color: ZamerColors.accent.withValues(alpha: .16),
                  blurRadius: 18,
                ),
              ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: rendering ? ZamerColors.surfaceHighest : ZamerColors.accent,
        ),
        child: rendering
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.photo_camera_rounded,
                color: ZamerColors.accentInk,
                size: 24,
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
    borderRadius: BorderRadius.circular(ZamerRadius.md),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 2,
        vertical: ZamerSpace.xs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: ZamerColors.textSecondary),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ZamerColors.textPrimary,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ZamerColors.textMuted,
              fontSize: 8,
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
      ..color = ZamerColors.textPrimary.withValues(alpha: .24)
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
