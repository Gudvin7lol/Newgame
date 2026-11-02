import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/electrical_issue_register_service.dart';
import '../services/electrical_issue_locator_service.dart';

/// Read-only diagnostics. The only action is locating a known point on plan.
class ElectricalIssueRegisterSheet extends StatefulWidget {
  const ElectricalIssueRegisterSheet({
    super.key,
    required this.floor,
    required this.onLocate,
    this.onOpenCable,
  });
  final FloorPlan floor;
  final ValueChanged<ElectricalIssueEntry> onLocate;
  final ValueChanged<String>? onOpenCable;

  @override
  State<ElectricalIssueRegisterSheet> createState() =>
      _ElectricalIssueRegisterSheetState();
}

class _ElectricalIssueRegisterSheetState
    extends State<ElectricalIssueRegisterSheet> {
  ElectricalIssueSeverity? filter;

  String? linkedCableId(ElectricalIssueEntry issue) {
    final network = widget.floor.electricalNetwork;
    if (network == null) return null;
    if (issue.object == ElectricalIssueObject.cable &&
        network.cables.any((c) => c.id == issue.objectId)) {
      return issue.objectId;
    }
    if (issue.object == ElectricalIssueObject.route) {
      // One physical route may belong to several distinct cables.
      // Do not jump to an arbitrary first cable when the link is ambiguous.
      final matchingCables = network.cables.where((c) =>
          c.route3dId == issue.objectId).toList();
      return matchingCables.length == 1 ? matchingCables.single.id : null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final register = ElectricalIssueRegisterService.inspect(widget.floor);
    final items = register.entries.where(
        (e) => filter == null || e.severity == filter).toList();
    final theme = Theme.of(context);
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .86,
        child: ListView(
          key: const ValueKey('electrical-issue-list'),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 26),
          children: [
            Text('Проверка электрики',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${register.errors} ошибок · '
                '${register.toReview} требуют проверки',
                key: const ValueKey('electrical-issue-counts')),
            const SizedBox(height: 5),
            Text('Проверяются данные проекта. '
                'Монтажная и нормативная пригодность '
                'не подтверждается автоматически.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Wrap(spacing: 7, runSpacing: 4, children: [
              ChoiceChip(
                key: const ValueKey('electrical-issue-all'),
                label: const Text('Все'),
                selected: filter == null,
                onSelected: (_) => setState(() => filter = null),
              ),
              ChoiceChip(
                key: const ValueKey('electrical-issue-errors'),
                label: Text('Ошибки ${register.errors}'),
                selected: filter == ElectricalIssueSeverity.error,
                onSelected: (_) => setState(
                    () => filter = ElectricalIssueSeverity.error),
              ),
              ChoiceChip(
                key: const ValueKey('electrical-issue-review'),
                label: Text('Проверить ${register.toReview}'),
                selected: filter == ElectricalIssueSeverity.review,
                onSelected: (_) => setState(
                    () => filter = ElectricalIssueSeverity.review),
              ),
            ]),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('В этом фильтре замечаний нет. '
                    'Это не означает подтверждение безопасности монтажа.'),
              ),
            for (var i = 0; i < items.length; i++)
              Card(
                key: ValueKey('electrical-issue-row-$i'),
                margin: const EdgeInsets.only(bottom: 6),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 9, 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        items[i].severity == ElectricalIssueSeverity.error
                            ? Icons.error_outline
                            : Icons.info_outline,
                        size: 19,
                        color: items[i].severity == ElectricalIssueSeverity.error
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(items[i].source +
                                (items[i].objectId == null ? '' :
                                ' · ${items[i].objectId}'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium),
                            const SizedBox(height: 3),
                            Text(items[i].description,
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      if (widget.onOpenCable != null &&
                          linkedCableId(items[i]) != null)
                        IconButton(
                          key: ValueKey('electrical-issue-cable-$i'),
                          tooltip: 'Открыть этот кабель в журнале',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.inventory_2_outlined),
                          onPressed: () {
                            final id = linkedCableId(items[i]);
                            if (id != null) widget.onOpenCable?.call(id);
                          },
                        ),
                      if (ElectricalIssueLocatorService.locate(
                          widget.floor, items[i]) != null)
                        IconButton(
                          key: ValueKey('electrical-issue-locate-$i'),
                          tooltip: 'Показать на плане',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.my_location_outlined),
                          onPressed: () => widget.onLocate(items[i]),
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
