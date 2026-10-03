import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import '../renderer3d/zamer_gpu_viewport.dart';
import '../services/camera_gesture_policy.dart';
import '../services/walk_navigation_service.dart';
import '../widgets/master_walk_joystick.dart';
import 'photo_studio_screen.dart';

class Master3DScreen extends StatefulWidget {
  const Master3DScreen({
    super.key,
    required this.floor,
    required this.projectTitle,
    required this.onOpen2D,
    this.onOpenAr,
    this.onBack,
  });

  final FloorPlan floor;
  final String projectTitle;
  final VoidCallback onOpen2D;
  final VoidCallback? onOpenAr;
  final VoidCallback? onBack;

  @override
  State<Master3DScreen> createState() => _Master3DScreenState();
}

class _Master3DScreenState extends State<Master3DScreen> {
  double _rotation = -.65;
  double _tilt = .82;
  double _zoom = .92;
  Offset _pan = Offset.zero;
  double _gestureZoom = .92;
  Offset _gesturePan = Offset.zero;
  Offset _gestureFocal = Offset.zero;
  int _gesturePointers = 0;

  bool _walk = false;
  bool _noclip = false;
  bool _cutaway = true;
  bool _hideWalls = false;
  bool _perspective = true;
  int _lightMode = 0;
  int _qualityMode = 1;

  double _walkX = 0;
  double _walkY = 0;
  double _walkSpeedMmPerSecond = 2500;
  double _overviewRotation = -.65;
  double _overviewTilt = .82;
  double _overviewZoom = .92;
  Offset _overviewPan = Offset.zero;

  void _resetOverview() => setState(() {
        _walk = false;
        _rotation = -.65;
        _tilt = .82;
        _zoom = .92;
        _pan = Offset.zero;
      });

  void _centerWalk() {
    final start = WalkNavigationService.startingPoint(widget.floor);
    _walkX = start.x;
    _walkY = start.y;
  }

  void _toggleWalk() {
    setState(() {
      if (!_walk) {
        _overviewRotation = _rotation;
        _overviewTilt = _tilt;
        _overviewZoom = _zoom;
        _overviewPan = _pan;
        _centerWalk();
        _rotation = WalkNavigationService.startingRotation(
          widget.floor,
          math.Point(_walkX, _walkY),
        );
        _tilt = 0;
        _zoom = 1;
        _pan = Offset.zero;
        _walk = true;
      } else {
        _rotation = _overviewRotation;
        _tilt = _overviewTilt;
        _zoom = _overviewZoom;
        _pan = _overviewPan;
        _walk = false;
      }
    });
  }

  void _walkStep(double forward, double sideways, double deltaSeconds) {
    final next = WalkNavigationService.advance(
      widget.floor,
      math.Point(_walkX, _walkY),
      _rotation,
      forward * _walkSpeedMmPerSecond * deltaSeconds,
      sideways * _walkSpeedMmPerSecond * deltaSeconds,
      ignoreCollisions: _noclip,
    );
    if (next.x == _walkX && next.y == _walkY) return;
    setState(() {
      _walkX = next.x;
      _walkY = next.y;
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureZoom = _zoom;
    _gesturePan = _pan;
    _gestureFocal = details.focalPoint;
    _gesturePointers = details.pointerCount;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount != _gesturePointers) {
      _gesturePointers = details.pointerCount;
      _gestureZoom = _zoom / math.max(.001, details.scale);
      _gesturePan = _pan;
      _gestureFocal = details.focalPoint;
      return;
    }
    setState(() {
      if (details.pointerCount >= 2 && !_walk) {
        _zoom = (_gestureZoom * details.scale).clamp(.2, 8).toDouble();
        _pan = _gesturePan + (details.focalPoint - _gestureFocal);
      } else {
        _rotation = CameraGesturePolicy.applyHorizontalSwipe(
          yaw: _rotation,
          deltaX: details.focalPointDelta.dx,
          sensitivity: .010,
        );
        final minTilt = _walk ? -.7 : .22;
        final maxTilt = _walk ? .7 : 1.48;
        _tilt = (_tilt - details.focalPointDelta.dy * .006)
            .clamp(minTilt, maxTilt)
            .toDouble();
      }
    });
  }

  Future<void> _openRender() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoStudioScreen(
          floor: widget.floor,
          rotation: _rotation,
          tilt: _tilt,
          zoom: _zoom,
          pan: _pan,
          cameraOriginXMm: _walk ? _walkX : null,
          cameraOriginYMm: _walk ? _walkY : null,
        ),
      ),
    );
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.background,
      barrierColor: Colors.black.withValues(alpha: .72),
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ZMasterSectionTitle('Настройки просмотра'),
                const SizedBox(height: 12),
                ZMasterPanel(
                  child: Column(
                    children: [
                      _SettingsRow(
                        label: 'Тип камеры',
                        child: ZMasterSegmentedControl(
                          labels: const ['Перспектива', 'Ортогональная'],
                          selectedIndex: _perspective ? 0 : 1,
                          onSelected: (index) {
                            setState(() => _perspective = index == 0);
                            setSheetState(() {});
                          },
                          height: 38,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SettingsRow(
                        label: 'Скрывать стены',
                        child: Switch.adaptive(
                          value: _hideWalls,
                          onChanged: (value) {
                            setState(() => _hideWalls = value);
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SettingsRow(
                        label: 'Время суток',
                        child: ZMasterSegmentedControl(
                          labels: const ['День', 'Вечер', 'Ночь'],
                          selectedIndex: _lightMode,
                          onSelected: (index) {
                            setState(() => _lightMode = index);
                            setSheetState(() {});
                          },
                          height: 38,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SettingsRow(
                        label: 'Качество рендера',
                        child: ZMasterSegmentedControl(
                          labels: const ['Быстро', 'Стандартно', 'Высоко'],
                          selectedIndex: _qualityMode,
                          onSelected: (index) {
                            setState(() => _qualityMode = index);
                            setSheetState(() {});
                          },
                          height: 38,
                        ),
                      ),
                      if (_walk) ...[
                        const SizedBox(height: 12),
                        _SettingsRow(
                          label: 'Скорость',
                          child: Slider(
                            value: _walkSpeedMmPerSecond,
                            min: 800,
                            max: 4500,
                            divisions: 37,
                            label:
                                '${(_walkSpeedMmPerSecond / 1000).toStringAsFixed(1)} м/с',
                            onChanged: (value) {
                              setState(() => _walkSpeedMmPerSecond = value);
                              setSheetState(() {});
                            },
                          ),
                        ),
                        _SettingsRow(
                          label: 'Сквозь объекты',
                          child: Switch.adaptive(
                            value: _noclip,
                            onChanged: (value) {
                              setState(() => _noclip = value);
                              setSheetState(() {});
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openRender();
                  },
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Открыть рендер'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLayers() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.background,
      barrierColor: Colors.black.withValues(alpha: .72),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ZMasterSectionTitle('Слои'),
              const SizedBox(height: 12),
              ZMasterPanel(
                child: Column(
                  children: [
                    _ToggleRow(
                      icon: Icons.visibility_off_outlined,
                      label: 'Скрывать стены',
                      value: _hideWalls,
                      onChanged: (value) => setState(() => _hideWalls = value),
                    ),
                    const Divider(),
                    _ToggleRow(
                      icon: Icons.content_cut_rounded,
                      label: 'Разрез помещения',
                      value: _cutaway,
                      onChanged: (value) => setState(() => _cutaway = value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLightMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.background,
      barrierColor: Colors.black.withValues(alpha: .72),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ZMasterSectionTitle('Режим освещения'),
              const SizedBox(height: 12),
              ZMasterSegmentedControl(
                labels: const ['День', 'Вечер', 'Ночь'],
                selectedIndex: _lightMode,
                onSelected: (index) {
                  setState(() => _lightMode = index);
                  Navigator.pop(sheetContext);
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
    if (widget.floor.walls.isEmpty) {
      return const ColoredBox(
        color: ZamerColors.background,
        child: Center(child: Text('3D пока пуст')),
      );
    }

    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ZMasterTopBar(
              title: widget.projectTitle,
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
              onSettings: _showSettings,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ZMasterSegmentedControl(
                labels: const ['2D', '3D', 'AR'],
                selectedIndex: 1,
                onSelected: (index) {
                  if (index == 0) widget.onOpen2D();
                  if (index == 2) widget.onOpenAr?.call();
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        child: ZamerGpuViewport(
                          floor: widget.floor,
                          rotation: _rotation,
                          tilt: _tilt,
                          zoom: _zoom,
                          cutaway: !_walk && (_hideWalls || _cutaway),
                          pan: _pan,
                          walkMode: _walk,
                          walkX: _walkX,
                          walkY: _walkY,
                          performanceMode: _qualityMode == 0,
                        ),
                      ),
                      if (_walk)
                        const IgnorePointer(
                          child: Center(
                            child: Icon(
                              Icons.add_rounded,
                              size: 20,
                              color: ZamerColors.accent,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 14,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: ZamerColors.surface.withValues(alpha: .94),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ZamerColors.outline),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ZMasterVerticalToolButton(
                                icon: Icons.light_mode_outlined,
                                tooltip: 'Свет',
                                onTap: _showLightMenu,
                              ),
                              ZMasterVerticalToolButton(
                                icon: Icons.view_in_ar_outlined,
                                tooltip: 'Перспектива',
                                selected: _perspective,
                                onTap: () => setState(
                                  () => _perspective = !_perspective,
                                ),
                              ),
                              ZMasterVerticalToolButton(
                                icon: Icons.layers_outlined,
                                tooltip: 'Слои',
                                onTap: _showLayers,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_walk)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: MasterWalkJoystick(onStep: _walkStep),
                        )
                      else
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: IconButton.filledTonal(
                            tooltip: 'Сбросить обзор',
                            onPressed: _resetOverview,
                            icon: const Icon(Icons.open_with_rounded),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ZMasterPanel(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Expanded(
                      child: ZMasterToolButton(
                        icon: Icons.open_with_rounded,
                        label: 'Обзор',
                        selected: !_walk,
                        onTap: _walk ? _toggleWalk : _resetOverview,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: ZMasterToolButton(
                        icon: Icons.directions_walk_rounded,
                        label: 'Прогулка',
                        selected: _walk,
                        onTap: _toggleWalk,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: ZMasterToolButton(
                        icon: _walk ? Icons.blur_on : Icons.view_in_ar_outlined,
                        label: _walk ? 'Сквозь' : 'Разрез',
                        selected: _walk ? _noclip : _cutaway,
                        onTap: () => setState(() {
                          if (_walk) {
                            _noclip = !_noclip;
                          } else {
                            _cutaway = !_cutaway;
                          }
                        }),
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: ZMasterToolButton(
                        icon: Icons.visibility_off_outlined,
                        label: 'Скрыть',
                        selected: _hideWalls,
                        onTap: () => setState(() => _hideWalls = !_hideWalls),
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: ZMasterToolButton(
                        icon: Icons.settings_outlined,
                        label: 'Настройки',
                        onTap: _showSettings,
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 116,
            child: Text(label, style: ZamerTypography.bodySmall),
          ),
          Expanded(child: child),
        ],
      );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: ZamerTypography.bodySmall)),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      );
}
