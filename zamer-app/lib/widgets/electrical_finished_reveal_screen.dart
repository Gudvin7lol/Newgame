import 'package:flutter/material.dart';

import '../models/electrical_finished_reveal.dart';
import '../models/models.dart';
import '../services/electrical_opening_reveal_service.dart';

/// Editing explicit wall-face reveal stations. The caller owns the undo and
/// persistence boundary, and the editor never moves existing electric points.
class ElectricalFinishedRevealScreen extends StatefulWidget {
  const ElectricalFinishedRevealScreen({
    super.key,
    required this.floor,
    required this.wallId,
    required this.wallSide,
    required this.onSave,
  });

  final FloorPlan floor;
  final String wallId;
  final int wallSide;
  final Future<void> Function(String wallId, String openingId, int side,
      ElectricalFinishedReveal? reveal) onSave;

  @override
  State<ElectricalFinishedRevealScreen> createState() =>
      _ElectricalFinishedRevealScreenState();
}

class _ElectricalFinishedRevealScreenState
    extends State<ElectricalFinishedRevealScreen> {
  String mm(double x) => x.toStringAsFixed(1) + ' мм';

  Future<void> _edit(WallOpening opening) async {
    final previous = ElectricalOpeningRevealService.saved(
        opening, widget.wallSide);
    var startText = previous?.startUMm.toStringAsFixed(1) ??
        opening.offsetFromStartMm.toStringAsFixed(1);
    var endText = previous?.endUMm.toStringAsFixed(1) ??
        (opening.offsetFromStartMm + opening.widthMm).toStringAsFixed(1);
    var uncertaintyText = previous?.uncertaintyMm?.toStringAsFixed(1) ?? '';
    var note = previous?.note ?? '';
    var source = previous?.source ?? OpeningRevealSource.unspecified;
    final decision = await showDialog<_RevealDecision>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => AlertDialog(
          title: Text('Чистовые грани · ' + opening.id),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Введите две фактические или проектные координаты '
                  'граней от НАЧАЛА стены. Предзаполнены черновые размеры '
                  'как подсказка, они не становятся обмером автоматически.'),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('reveal-start-input'),
                initialValue: startText,
                onChanged: (value) => startText = value,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Первая грань от начала, мм',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('reveal-end-input'),
                initialValue: endText,
                onChanged: (value) => endText = value,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Вторая грань от начала, мм',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<OpeningRevealSource>(
                initialValue: source,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Источник размеров'),
                items: const [
                  DropdownMenuItem(
                    value: OpeningRevealSource.unspecified,
                    child: Text('Не подтверждено'),
                  ),
                  DropdownMenuItem(
                    value: OpeningRevealSource.designed,
                    child: Text('Проект'),
                  ),
                  DropdownMenuItem(
                    value: OpeningRevealSource.document,
                    child: Text('Документ'),
                  ),
                  DropdownMenuItem(
                    value: OpeningRevealSource.measured,
                    child: Text('Введённый обмер'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) refresh(() => source = value);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('reveal-uncertainty-input'),
                initialValue: uncertaintyText,
                onChanged: (value) => uncertaintyText = value,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Погрешность, мм',
                  helperText: 'Пусто = неизвестна',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('reveal-note-input'),
                initialValue: note,
                onChanged: (value) => note = value,
                decoration: const InputDecoration(
                  labelText: 'Примечание к обмеру',
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Отмена'),
            ),
            TextButton(
              key: const ValueKey('reveal-clear'),
              onPressed: () => Navigator.pop(
                  dialog, const _RevealDecision(null)),
              child: const Text('Сбросить'),
            ),
            FilledButton(
              key: const ValueKey('reveal-save'),
              onPressed: () {
                double? parse(String text) => double.tryParse(
                    text.trim().replaceAll(',', '.'));
                final from = parse(startText);
                final to = parse(endText);
                final unc = uncertaintyText.trim().isEmpty
                    ? null : parse(uncertaintyText);
                if (from == null || to == null ||
                    !from.isFinite || !to.isFinite ||
                    from < 0 || to <= from ||
                    (uncertaintyText.trim().isNotEmpty && unc == null) ||
                    (unc != null && (!unc.isFinite || unc < 0 || unc > 500))) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(
                      'Введите две возрастающие координаты и '
                      'допустимую погрешность.',
                    )),
                  );
                  return;
                }
                Navigator.pop(dialog, _RevealDecision(
                  ElectricalFinishedReveal(
                    startUMm: from, endUMm: to,
                    geometrySnapshot: '',
                    source: source, uncertaintyMm: unc, note: note.trim(),
                  ),
                ));
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (decision == null || !mounted) return;
    try {
      await widget.onSave(widget.wallId, opening.id,
          widget.wallSide, decision.reveal);
      if (mounted) setState(() {});
    } on FormatException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wall = widget.floor.wallById(widget.wallId);
    final openings = wall?.openings ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Чистовые грани проёмов')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('finished-reveals-screen'),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Стена ' + widget.wallId +
                ' · ' + (widget.wallSide == 1
                    ? 'левая сторона' : 'правая сторона'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Грани задаются отдельно для каждой стороны стены. '
                'Это координаты вдоль оси, а не ширина наличника. '
                'Обмер отделки и проёма необходимо проверить на объекте.'),
            const SizedBox(height: 12),
            if (openings.isEmpty)
              const Text('На выбранной стене нет проёмов.'),
            for (final o in openings)
              _card(o),
            const SizedBox(height: 14),
            Text('Важно: даже размер с источником «Введённый обмер» '
                'не подтверждает уровень чистого пола, точность '
                'оси стены или реальную геометрию коробки.',
              style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _card(WallOpening opening) {
    final entry = ElectricalOpeningRevealService.saved(
        opening, widget.wallSide);
    final problem = ElectricalOpeningRevealService.problem(
        widget.floor, widget.wallId, opening.id, widget.wallSide);
    final hasCurrent = entry != null && problem == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Проём ' + opening.id,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Черновые грани: ' +
              mm(opening.offsetFromStartMm) + ' / ' +
              mm(opening.offsetFromStartMm + opening.widthMm)),
          const SizedBox(height: 6),
          Text(entry == null
              ? 'Чистовые грани: не заданы'
              : 'Чистовые грани: ' + mm(entry.startUMm) +
                ' / ' + mm(entry.endUMm),
              key: ValueKey('reveal-status-' + opening.id)),
          if (entry != null) ...[
            Text('Источник: ' + switch (entry.source) {
              OpeningRevealSource.unspecified => 'не подтверждён',
              OpeningRevealSource.designed => 'проект',
              OpeningRevealSource.document => 'документ',
              OpeningRevealSource.measured => 'введённый обмер',
            }),
            Text('Погрешность: ' +
                (entry.uncertaintyMm == null
                    ? 'неизвестна' : mm(entry.uncertaintyMm!))),
          ],
          if (problem != null && entry != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(problem, style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              )),
            ),
          if (hasCurrent)
            const Text('Размер согласован с текущей проектной '
                'геометрией, не является актом обмера.'),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: ValueKey('reveal-edit-' + opening.id),
              onPressed: () => _edit(opening),
              icon: const Icon(Icons.straighten),
              label: Text(entry == null ? 'Ввести грани' : 'Уточнить'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RevealDecision {
  const _RevealDecision(this.reveal);
  final ElectricalFinishedReveal? reveal;
}
