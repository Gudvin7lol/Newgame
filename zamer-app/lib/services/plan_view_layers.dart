import '../models/models.dart';

/// Visible drawing contents, separate from the construction phase.
enum PlanContentLayer {
  walls,
  finishes,
  furniture,
  sanitary,
  electrical,
  engineering,
  otherObjects,
  dimensions,
  roomLabels,
}

extension PlanContentLayerLabel on PlanContentLayer {
  String get label => switch (this) {
    PlanContentLayer.walls => 'Стены и проёмы',
    PlanContentLayer.finishes => 'Покрытия пола',
    PlanContentLayer.furniture => 'Мебель',
    PlanContentLayer.sanitary => 'Сантехника',
    PlanContentLayer.electrical => 'Электрика и освещение',
    PlanContentLayer.engineering => 'Инженерные трассы',
    PlanContentLayer.otherObjects => 'Прочие объекты',
    PlanContentLayer.dimensions => 'Размеры',
    PlanContentLayer.roomLabels => 'Названия помещений',
  };
}

enum PlanClashCategory {
  wallIntersection,
  objectWall,
  objectObject,
  doorPassage,
}

extension PlanClashCategoryLabel on PlanClashCategory {
  String get label => switch (this) {
    PlanClashCategory.wallIntersection => 'Пересечения стен',
    PlanClashCategory.objectWall => 'Мебель / объект со стеной',
    PlanClashCategory.objectObject => 'Пересечение объектов',
    PlanClashCategory.doorPassage => 'Загромождение дверных проходов',
  };
}

/// Pure view preferences: never deletes or edits construction objects.
/// Defaults intentionally reproduce the existing full-drawing appearance;
/// clash markers are opt-in to avoid obscuring the plan on opening a project.
class PlanViewLayers {
  PlanViewLayers({
    Set<ProjectLayer>? stages,
    Set<PlanContentLayer>? content,
    Set<PlanClashCategory>? clashTypes,
    this.showClashes = false,
  }) : stages = stages ?? ProjectLayer.values.toSet(),
       content = content ?? PlanContentLayer.values.toSet(),
       clashTypes = clashTypes ?? PlanClashCategory.values.toSet();

  final Set<ProjectLayer> stages;
  final Set<PlanContentLayer> content;
  final Set<PlanClashCategory> clashTypes;
  bool showClashes;

  factory PlanViewLayers.fromMap(Map<String, bool> values) {
    Set<T> selected<T>(List<T> options, String prefix, String Function(T) name) =>
        options.where((v) => values['$prefix.${name(v)}'] ?? true).toSet();
    return PlanViewLayers(
      stages: selected(ProjectLayer.values, 'stage', (v) => v.name),
      content: selected(PlanContentLayer.values, 'content', (v) => v.name),
      clashTypes: selected(PlanClashCategory.values, 'clash', (v) => v.name),
      showClashes: values['showClashes'] ?? false,
    );
  }

  PlanViewLayers copy() => PlanViewLayers(
    stages: {...stages},
    content: {...content},
    clashTypes: {...clashTypes},
    showClashes: showClashes,
  );

  Map<String, bool> toMap() => {
    for (final value in ProjectLayer.values)
      'stage.${value.name}': stages.contains(value),
    for (final value in PlanContentLayer.values)
      'content.${value.name}': content.contains(value),
    for (final value in PlanClashCategory.values)
      'clash.${value.name}': clashTypes.contains(value),
    'showClashes': showClashes,
  };

  bool visibleObject(PlanObject object) {
    if (!stages.contains(object.layer)) return false;
    return content.contains(categoryOfObject(object.type));
  }

  static PlanContentLayer categoryOfObject(PlanObjectType type) =>
      switch (type) {
        PlanObjectType.furniture => PlanContentLayer.furniture,
        PlanObjectType.sanitary ||
        PlanObjectType.waterPoint ||
        PlanObjectType.drainPoint ||
        PlanObjectType.radiator => PlanContentLayer.sanitary,
        PlanObjectType.lighting => PlanContentLayer.electrical,
        _ => PlanContentLayer.otherObjects,
      };
}
