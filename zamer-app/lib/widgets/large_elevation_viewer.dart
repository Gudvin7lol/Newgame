import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/zamer_tokens.dart';
import '../models/models.dart';
import 'elevation_painter.dart';

/// Full-screen elevation workspace with explicit navigation and tile-edit modes.
///
/// Keeping those gestures separate prevents the old ambiguity where one drag
/// could both pan the InteractiveViewer and shift the wall-tile origin.
class LargeElevationViewer extends StatefulWidget {
  const LargeElevationViewer({
    super.key,
    required this.floor,
    required this.face,
    required this.run,
    required this.heightMm,
    required this.settings,
    required this.onChanged,
  });

  final FloorPlan floor;
  final RoomFace face;
  final ElevationRun run;
  final double heightMm;
  final RoomMaterialSettings settings;
  final Future<void> Function() onChanged;

  @override
  State<LargeElevationViewer> createState() => _LargeElevationViewerState();
}

class _LargeElevationViewerState extends State<LargeElevationViewer> {
  final TransformationController _transform = TransformationController();
  bool _editTile = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  double _positiveModulo(double value, double module) {
    if (module <= 0) return value;
    return ((value % module) + module) % module;
  }

  void _panTile(Size drawing, Offset delta) {
    final horizontalMargin = math.min(38.0, drawing.width * .09);
    final verticalMargin = math.min(34.0, drawing.height * .12);
    final scale = math.min(
      (drawing.width - horizontalMargin * 2) /
          math.max(1, widget.run.lengthMm),
      (drawing.height - verticalMargin * 2) /
          math.max(1, widget.heightMm),
    );
    if (scale <= 0 || !scale.isFinite) return;

    final tileW = math.max(
      1.0,
      widget.settings.wallTileWidthFor(widget.run.id),
    ).toDouble();
    final tileH = math.max(
      1.0,
      widget.settings.wallTileHeightFor(widget.run.id),
    ).toDouble();
    widget.settings.wallTileRunOffsetX[widget.run.id] = _positiveModulo(
      widget.settings.wallTileXFor(widget.run.id) + delta.dx / scale,
      tileW,
    );
    widget.settings.wallTileRunOffsetY[widget.run.id] = _positiveModulo(
      widget.settings.wallTileYFor(widget.run.id) - delta.dy / scale,
      tileH,
    );
    setState(() {});
  }

  void _zoom(double factor) {
    final current = _transform.value.clone();
    current.scale(factor, factor, 1.0);
    _transform.value = current;
  }

  void _resetView() => _transform.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    final tileEnabled = widget.settings.wallTileEnabledFor(widget.run.id);
    if (!tileEnabled && _editTile) _editTile = false;

    return Scaffold(
      appBar: AppBar(
        title: Text('Развёртка • ${widget.run.lengthMm.round()} мм'),
        actions: [
          IconButton(
            key: const ValueKey('large-elevation-edit-mode'),
            tooltip: _editTile ? 'Навигация по чертежу' : 'Сдвиг плитки',
            onPressed: tileEnabled
                ? () => setState(() => _editTile = !_editTile)
                : null,
            icon: Icon(
              _editTile ? Icons.pan_tool_alt : Icons.grid_on_outlined,
              color: _editTile ? ZamerColors.accent : null,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final drawing = Size(
            math.max(constraints.maxWidth - 24, widget.run.lengthMm * .25),
            math.max(constraints.maxHeight * .80, widget.heightMm * .25),
          );
          return Stack(
            children: [
              InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                minScale: .35,
                maxScale: 6,
                boundaryMargin: const EdgeInsets.all(240),
                panEnabled: !_editTile,
                scaleEnabled: !_editTile,
                child: GestureDetector(
                  key: ValueKey('large-elevation-canvas-${widget.run.id}'),
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: _editTile
                      ? (details) => _panTile(drawing, details.delta)
                      : null,
                  onPanEnd: _editTile ? (_) => widget.onChanged() : null,
                  child: SizedBox.fromSize(
                    size: drawing,
                    child: CustomPaint(
                      painter: ElevationPainter(
                        floor: widget.floor,
                        face: widget.face,
                        run: widget.run,
                        heightMm: widget.heightMm,
                        settings: widget.settings,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ZamerColors.surfaceLow.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ZamerColors.outline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Text(
                        _editTile
                            ? 'Плитка: веди пальцем для сдвига раскладки'
                            : 'Навигация: двигай и масштабируй чертёж',
                        style: const TextStyle(
                          color: ZamerColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ZamerColors.surfaceLow.withValues(alpha: .96),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZamerColors.outline),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Приблизить',
                        onPressed: () => _zoom(1.25),
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        tooltip: 'Отдалить',
                        onPressed: () => _zoom(.8),
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        key: const ValueKey('large-elevation-reset-view'),
                        tooltip: 'Вписать в экран',
                        onPressed: _resetView,
                        icon: const Icon(Icons.fit_screen_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
