import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/electrical_network.dart';
import '../services/electrical_network_service.dart';

/// An inspection sheet for an existing junction box. It never guesses or
/// creates conductor connections by observing crossed lines on the plan.
class ElectricalJunctionConnectionsSheet extends StatelessWidget {
  const ElectricalJunctionConnectionsSheet({
    super.key,
    required this.floor,
    required this.junctionPointId,
  });

  final FloorPlan floor;
  final String junctionPointId;

  String _pointName(String id) {
    for (final p in floor.electricalPoints) {
      if (p.id == id) return p.label.isEmpty ? p.type.label : p.label;
    }
    return 'Точка удалена';
  }

  Widget _cableItem(BuildContext context, ElectricalCableRecord cable) {
    final network = floor.electricalNetwork;
    final circuit = network?.circuits
        .where((c) => c.id == cable.circuitId)
        .firstOrNull;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(_pointName(cable.fromPointId) +
          ' → ' + _pointName(cable.toPointId)),
      subtitle: Text((circuit?.name ?? 'Цепь не найдена') +
          ' · ' + cable.cores.length.toString() + ' жил' +
          (cable.routeRunId == null
              ? ' · без линии на плане' : ' · линия привязана')),
      trailing: Text(cable.id, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ElectricalNetworkService.junction(floor, junctionPointId);
    final terminalIds = s.terminals.map((t) => t.id).toSet();
    final relevant = ElectricalNetworkService.inspect(floor).where(
      (e) => e.referenceId == junctionPointId ||
          terminalIds.contains(e.referenceId) ||
          [...s.incoming, ...s.outgoing].any((c) => c.id == e.referenceId),
    ).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: FractionallySizedBox(
          heightFactor: .76,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: const Text('Соединения коробки'),
                subtitle: const Text('Кабели, жилы и клеммы · черновая схема'),
                trailing: IconButton(
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                  children: [
                    if (!s.isMapped)
                      const Text('Связи для этой коробки ещё не заданы. '
                          'Нарисованные линии и совпадающие названия групп '
                          'не считаются подключениями.'),
                    if (s.isMapped) ...[
                      Text('Кабели: входящих ' + s.incoming.length.toString() +
                          ', исходящих ' + s.outgoing.length.toString()),
                      const SizedBox(height: 4),
                      Text('Клемм: ' + s.terminals.length.toString() +
                          ' · жил без клеммы в коробке: ' +
                          s.unterminatedCoreEnds.toString()),
                      const SizedBox(height: 10),
                      const Text('Направление кабеля взято из введённой '
                          'схемы и не подтверждает фактический монтаж.'),
                    ],
                    if (relevant.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Требует проверки',
                          style: Theme.of(context).textTheme.titleSmall),
                      for (final issue in relevant)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            issue.severity == ElectricalNetworkSeverity.error
                                ? Icons.error_outline
                                : Icons.info_outline,
                          ),
                          title: Text(issue.message),
                        ),
                    ],
                    if (s.incoming.isNotEmpty)
                      ExpansionTile(
                        initiallyExpanded: true,
                        title: const Text('Входящие кабели'),
                        children: [
                          for (final cable in s.incoming)
                            _cableItem(context, cable),
                        ],
                      ),
                    if (s.outgoing.isNotEmpty)
                      ExpansionTile(
                        title: const Text('Исходящие кабели'),
                        children: [
                          for (final cable in s.outgoing)
                            _cableItem(context, cable),
                        ],
                      ),
                    if (s.terminals.isNotEmpty)
                      ExpansionTile(
                        title: const Text('Клеммы и назначенные жилы'),
                        children: [
                          for (final terminal in s.terminals)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(terminal.mark.isEmpty
                                  ? terminal.id : terminal.mark),
                              subtitle: Text(terminal.members.map(
                                (ref) => ref.cableId + ':' + ref.coreId,
                              ).join(' · ')),
                            ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    Text('Этот экран показывает только введённые вручную '
                        'связи. Совместимость клемм, допустимые соединения, '
                        'защита и электробезопасность здесь не подтверждаются.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
