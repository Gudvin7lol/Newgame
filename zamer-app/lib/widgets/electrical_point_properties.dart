import 'package:flutter/material.dart';
import '../models/models.dart';

/// Edits a detached point. The caller owns persistence and undo.
class ElectricalPointProperties extends StatefulWidget {
  const ElectricalPointProperties({
    super.key,
    required this.point,
    required this.circuits,
  });
  final ElectricalPoint point;
  final List<String> circuits;
  @override
  State<ElectricalPointProperties> createState() =>
      _ElectricalPointPropertiesState();
}

class _ElectricalPointPropertiesState extends State<ElectricalPointProperties> {
  late final ElectricalPoint draft;
  late final TextEditingController label, circuit, power, height;
  String? error;
  bool get canMount =>
      draft.isWallDevice || draft.type == ElectricalPointType.junctionBox;
  bool get canFrame => const {
    ElectricalPointType.socket,
    ElectricalPointType.switchPoint,
    ElectricalPointType.tvSocket,
    ElectricalPointType.dataSocket,
    ElectricalPointType.frame,
  }.contains(widget.point.type);

  @override
  void initState() {
    super.initState();
    draft = ElectricalPoint.fromJson(widget.point.toJson());
    label = TextEditingController(text: draft.label);
    circuit = TextEditingController(text: draft.circuit);
    power = TextEditingController(text: draft.powerW.toString());
    height = TextEditingController(text: draft.heightMm.toString());
    if (canFrame && draft.modules.isEmpty) {
      draft.modules.add(switch (draft.type) {
        ElectricalPointType.switchPoint => ElectricalModuleType.switch1,
        ElectricalPointType.tvSocket => ElectricalModuleType.tv,
        ElectricalPointType.dataSocket => ElectricalModuleType.data,
        _ => ElectricalModuleType.socket220,
      });
    }
  }

  @override
  void dispose() {
    for (final c in [label, circuit, power, height]) {
      c.dispose();
    }
    super.dispose();
  }

  void save() {
    final watts = double.tryParse(power.text.replaceAll(',', '.'));
    final h = double.tryParse(height.text.replaceAll(',', '.'));
    if (watts == null ||
        !watts.isFinite ||
        watts < 0 ||
        h == null ||
        !h.isFinite ||
        h < 0) {
      setState(
        () => error = 'Высота и мощность должны быть неотрицательными числами.',
      );
      return;
    }
    draft.label = label.text.trim();
    draft.circuit = circuit.text
        .trim(); // Blank is unassigned, never an implicit group.
    draft.powerW = watts;
    if (!canMount) draft.heightMm = h;
    if (canFrame) {
      draft.type = draft.modules.length > 1
          ? ElectricalPointType.frame
          : switch (draft.modules.single) {
              ElectricalModuleType.switch1 ||
              ElectricalModuleType.switch2 => ElectricalPointType.switchPoint,
              ElectricalModuleType.tv => ElectricalPointType.tvSocket,
              ElectricalModuleType.data => ElectricalPointType.dataSocket,
              _ => ElectricalPointType.socket,
            };
    }
    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    final groups =
        widget.circuits
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                title: const Text('Свойства точки'),
                subtitle: Text(widget.point.type.label),
                trailing: IconButton(
                  tooltip: 'Закрыть без сохранения',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    TextField(
                      key: const ValueKey('point-label'),
                      controller: label,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Подпись',
                        hintText: 'Например: у рабочего стола',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('point-circuit'),
                      controller: circuit,
                      decoration: InputDecoration(
                        labelText: 'Группа / линия',
                        hintText: 'Без группы',
                        helperText: 'Выберите существующую или введите новую',
                        suffixIcon: groups.isEmpty
                            ? null
                            : PopupMenuButton<String>(
                                tooltip: 'Выбрать существующую группу',
                                icon: const Icon(Icons.expand_more),
                                onSelected: (value) =>
                                    setState(() => circuit.text = value),
                                itemBuilder: (_) => [
                                  for (final group in groups)
                                    PopupMenuItem(
                                      value: group,
                                      child: Text(group),
                                    ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!canMount)
                      TextField(
                        key: const ValueKey('point-height'),
                        controller: height,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Центр над чистым полом',
                          suffixText: 'мм',
                        ),
                      ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Нагрузка'),
                      subtitle: Text('${power.text} Вт'),
                      children: [
                        TextField(
                          key: const ValueKey('point-power'),
                          controller: power,
                          onChanged: (_) => setState(() => error = null),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Мощность подключённого прибора',
                            suffixText: 'Вт',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                    if (canFrame)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Состав рамки'),
                        subtitle: Text('${draft.modules.length} мест'),
                        children: [
                          DropdownButtonFormField<int>(
                            key: const ValueKey('point-module-count'),
                            initialValue: draft.modules.length
                                .clamp(1, 5)
                                .toInt(),
                            decoration: const InputDecoration(
                              labelText: 'Количество мест',
                            ),
                            items: [
                              for (var i = 1; i <= 5; i++)
                                DropdownMenuItem(value: i, child: Text('$i')),
                            ],
                            onChanged: (n) {
                              if (n == null) return;
                              setState(() {
                                while (draft.modules.length < n) {
                                  draft.modules.add(
                                    ElectricalModuleType.socket220,
                                  );
                                }
                                while (draft.modules.length > n) {
                                  draft.modules.removeLast();
                                }
                              });
                            },
                          ),
                          for (var i = 0; i < draft.modules.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child:
                                  DropdownButtonFormField<ElectricalModuleType>(
                                    key: ValueKey('point-module-$i'),
                                    initialValue: draft.modules[i],
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: 'Место ${i + 1}',
                                    ),
                                    items: [
                                      for (final type
                                          in ElectricalModuleType.values)
                                        DropdownMenuItem(
                                          value: type,
                                          child: Text(type.label),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null)
                                        setState(() => draft.modules[i] = v);
                                    },
                                  ),
                            ),
                          if (draft.modules.length > 1)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: draft.frameVertical,
                              title: const Text('Вертикальная рамка'),
                              onChanged: (v) =>
                                  setState(() => draft.frameVertical = v),
                            ),
                          const SizedBox(height: 12),
                        ],
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    FilledButton(
                      key: const ValueKey('point-save'),
                      onPressed: save,
                      child: const Text('Сохранить точку'),
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
}
