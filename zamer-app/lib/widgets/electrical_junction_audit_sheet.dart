import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/electrical_junction_audit_service.dart';

/// Non-certifying summary for every junction box on this floor.
class ElectricalJunctionAuditSheet extends StatelessWidget {
  const ElectricalJunctionAuditSheet({
    super.key,
    required this.floor,
    this.onSelectJunction,
  });

  final FloorPlan floor;
  final ValueChanged<String>? onSelectJunction;

  @override
  Widget build(BuildContext context) {
    final audit = ElectricalJunctionAuditService.inspect(floor);
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor:.78,
        child: ListView(
          padding:const EdgeInsets.fromLTRB(16,12,16,26),
          children: [
            Text('Проверка распределительных коробок',
                style:Theme.of(context).textTheme.titleLarge),
            const SizedBox(height:6),
            Text('${audit.boxes} РК · ${audit.blocked} с ошибками · '
                '${audit.toReview} требуют проверки',
                key:const ValueKey('junction-audit-summary')),
            const SizedBox(height:8),
            const Text('Даже если все числовые ограничения соблюдены, '
                'монтажная пригодность и электробезопасность '
                'не подтверждаются автоматически.'),
            for (final problem in audit.globalErrors)
              Padding(
                padding:const EdgeInsets.only(top:8),
                child:Text(problem,style:TextStyle(
                    color:Theme.of(context).colorScheme.error)),
              ),
            if (audit.entries.isEmpty)
              const Padding(
                padding:EdgeInsets.only(top:14),
                child:Text('В этом этаже распределительные коробки не созданы.'),
              ),
            for (final item in audit.entries)
              Card(
                child:ExpansionTile(
                  key:ValueKey('junction-audit-${item.junctionId}'),
                  leading:Icon(item.blocked
                      ? Icons.error_outline
                      : Icons.fact_check_outlined,
                    color:item.blocked
                        ? Theme.of(context).colorScheme.error
                        : const Color(0xFFF1AF91)),
                  title:Text(item.label),
                  subtitle:Text(
                    '${item.capacity?.cableEntries ?? 0} вводов · '
                    '${item.capacity?.conductorEnds ?? 0} концов жил · '
                    '${item.capacity?.connectorCount ?? 0} соединений',
                  ),
                  childrenPadding:const EdgeInsets.fromLTRB(16,0,16,12),
                  children: [
                    if (item.errors.isNotEmpty)
                      for (final error in item.errors)
                        Padding(
                          padding:const EdgeInsets.only(bottom:5),
                          child:Align(alignment:Alignment.centerLeft,
                            child:Text('Ошибка: $error',
                              style:TextStyle(color:
                                Theme.of(context).colorScheme.error))),
                        ),
                    if (item.capacity != null)
                      Align(alignment:Alignment.centerLeft,
                        child:Text('Не назначено жил: '
                            '${item.capacity!.unassignedEnds}. '
                            'Наибольшее соединение: '
                            '${item.capacity!.maxObservedConnectorSize} концов.')),
                    if (item.unknown.isNotEmpty)
                      for (final warning in item.unknown)
                        Padding(
                          padding:const EdgeInsets.only(top:4),
                          child:Align(alignment:Alignment.centerLeft,
                            child:Text('Не проверено: $warning')),
                        ),
                    if (onSelectJunction != null)
                      Align(
                        alignment:Alignment.centerRight,
                        child:TextButton(
                          key:ValueKey('junction-audit-select-${item.junctionId}'),
                          onPressed:()=>onSelectJunction!(item.junctionId),
                          child:const Text('Показать на плане'),
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
