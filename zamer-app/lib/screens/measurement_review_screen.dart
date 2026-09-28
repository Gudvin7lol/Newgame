import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/measurement_review_service.dart';
import '../widgets/floor_plan_painter.dart';

class MeasurementReviewScreen extends StatefulWidget {
  const MeasurementReviewScreen({super.key, required this.floor});
  final FloorPlan floor;

  @override
  State<MeasurementReviewScreen> createState() =>
      _MeasurementReviewScreenState();
}

class _MeasurementReviewScreenState extends State<MeasurementReviewScreen> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final issues = MeasurementReviewService.review(widget.floor);
    return Scaffold(
      appBar: AppBar(title: const Text('Проверка обмера')),
      body: Column(
        children: [
          SizedBox(
            height: 290,
            child: LayoutBuilder(
              builder: (context, c) {
                final nodes = widget.floor.nodes;
                if (nodes.isEmpty)
                  return const Center(child: Text('План пуст'));
                final minX = nodes.map((e) => e.xMm).reduce(math.min);
                final minY = nodes.map((e) => e.yMm).reduce(math.min);
                final maxX = nodes.map((e) => e.xMm).reduce(math.max);
                final maxY = nodes.map((e) => e.yMm).reduce(math.max);
                final scale = math.min(
                  (c.maxWidth - 36) / math.max(1, maxX - minX),
                  (c.maxHeight - 36) / math.max(1, maxY - minY),
                );
                final origin = Offset(
                  (c.maxWidth - (maxX - minX) * scale) / 2 - minX * scale,
                  (c.maxHeight - (maxY - minY) * scale) / 2 - minY * scale,
                );
                return CustomPaint(
                  painter: _IssuePainter(
                    widget.floor,
                    issues,
                    _selected,
                    scale,
                    origin,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              issues.isEmpty
                  ? 'Замечаний по доступным данным нет'
                  : 'Замечаний: ${issues.length}. Размеры автоматически не меняются.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: issues.length,
              itemBuilder: (context, i) => ListTile(
                selected: _selected == i,
                leading: CircleAvatar(radius: 15, child: Text('${i + 1}')),
                title: Text(issues[i].description),
                subtitle: issues[i].deltaMm == null
                    ? null
                    : Text(
                        'Δ ${issues[i].deltaMm!.abs().round()} мм • точка отмечена на плане',
                      ),
                onTap: () => setState(() => _selected = i),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Сверь замечания на объекте. Контроль длины стены и его источник '
              'записываются в карточке стены; диагонали — инструментом «Размер».',
            ),
          ),
        ],
      ),
    );
  }
}

class _IssuePainter extends CustomPainter {
  const _IssuePainter(
    this.floor,
    this.issues,
    this.selected,
    this.scale,
    this.origin,
  );
  final FloorPlan floor;
  final List<MeasurementIssue> issues;
  final int? selected;
  final double scale;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    FloorPlanPainter(
      floor: floor,
      mmToPx: scale,
      origin: origin,
      showDimensions: false,
      showRoomLabels: false,
      showNodes: false,
    ).paint(canvas, size);
    for (var i = 0; i < issues.length; i++) {
      final p = issues[i].position;
      final q = origin + Offset(p.x * scale, p.y * scale);
      canvas.drawCircle(
        q,
        selected == i ? 15 : 11,
        Paint()
          ..color = selected == i
              ? const Color(0xFFE44739)
              : const Color(0xFFD66D27),
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, q - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _IssuePainter oldDelegate) => true;
}
