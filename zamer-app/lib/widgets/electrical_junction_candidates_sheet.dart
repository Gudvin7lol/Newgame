import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/electrical_junction_candidate_service.dart';

/// Read-only, ranked geometry suggestions, not an electrical design approval.
class ElectricalJunctionCandidatesSheet extends StatefulWidget {
  const ElectricalJunctionCandidatesSheet({
    super.key,
    required this.floor,
    required this.onPlace,
  });

  final FloorPlan floor;
  final Future<void> Function(ElectricalJunctionCandidate) onPlace;

  @override
  State<ElectricalJunctionCandidatesSheet> createState() =>
      _ElectricalJunctionCandidatesSheetState();
}

class _ElectricalJunctionCandidatesSheetState
    extends State<ElectricalJunctionCandidatesSheet> {
  String? error;

  Future<void> previewAndPlace(ElectricalJunctionCandidate candidate) async {
    final selected = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Кандидат распределительной коробки'),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Помещение: ${candidate.roomKey}'),
            Text('Предварительная группа: ${candidate.circuitLabel} '
                 '(${candidate.loadClass})'),
            Text('Стена: ${candidate.wallId}, сторона '
                '${candidate.wallSide > 0 ? '+' : '-'}'),
            Text('От начала стены: ${candidate.wallOffsetMm.round()} мм'),
            Text('От чистого пола: ${candidate.heightMm.round()} мм'),
            Text('Точек для проверки: ${candidate.consumerIds.length}'),
            const SizedBox(height: 12),
            for (final warning in candidate.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $warning',
                  style: Theme.of(dialog).textTheme.bodySmall),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Отмена')),
          FilledButton(
            key: const ValueKey('junction-candidate-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Добавить только точку РК'),
          ),
        ],
      ),
    );
    if (!mounted || selected != true) return;
    try {
      await widget.onPlace(candidate);
      if (mounted) setState(() => error = null);
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<ElectricalJunctionCandidate> candidates;
    try {
      candidates = ElectricalJunctionCandidateService.propose(widget.floor);
    } on FormatException catch (e) {
      candidates = const [];
      error = e.message;
    }
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .78,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('Кандидаты распределительных коробок',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Места рассчитаны по геометрии помещений и '
                'подписям групп, не по проверенной схеме сети. '
                'Автоматических кабелей и соединений не будет.'),
            const SizedBox(height: 10),
            if (error != null)
              Text(error!, style: TextStyle(
                  color: Theme.of(context).colorScheme.error)),
            if (candidates.isEmpty)
              const Text('Нет подходящих кандидатов. Для предложения '
                  'нужны как минимум две точки одного назначения '
                  'в одной предварительной группе и помещении.'),
            for (var i = 0; i < candidates.length; i++)
              Card(
                child: ListTile(
                  key: ValueKey('junction-candidate-$i'),
                  title: Text('РК · ${candidates[i].circuitLabel} '
                      '(${candidates[i].loadClass})'),
                  subtitle: Text(
                    'Стена ${candidates[i].wallId}, '
                    '${candidates[i].wallOffsetMm.round()} мм · '
                    'H ${candidates[i].heightMm.round()} мм\n'
                    '${candidates[i].consumerIds.length} точек · '
                    'сравнительный показатель '
                    '${(candidates[i].nominalDistanceMm / 1000).toStringAsFixed(1)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => previewAndPlace(candidates[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
