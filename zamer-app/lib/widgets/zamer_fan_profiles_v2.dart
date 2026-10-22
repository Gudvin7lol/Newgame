import 'package:flutter/material.dart';

import 'zamer_ui_kit_v2.dart';

/// Literal migration of the 43 contexts from ZAMER_fan_architecture_v2.md.
/// Profiles are presentation data. Only commands with an existing CAD handler
/// in the production workspace are marked enabled; unsupported operations
/// must not pretend to edit a user's project.
class ZamerFanProfileV2 {
  const ZamerFanProfileV2(this.id, this.first, this.second, this.outer);
  final String id;
  final ZamerKitCommand first, second;
  final List<ZamerKitCommand> outer;
}

abstract final class ZamerFanProfilesV2 {
  static const _profiles = <String, List<String>>{
    // Context dial = fast modes; structural creation lives in top strip.
    'plan.idle': ['nodes', 'arc', 'measure', 'frame'],
    'plan.wall.create': ['straight', 'arc', 'ortho', 'parallel', 'closeContour', 'measure'],
    'plan.wall.selected': ['move', 'nodes', 'split', 'extend', 'join', 'duplicate', 'measure', 'delete'],
    'plan.arc.selected': ['move', 'nodes', 'split', 'extend', 'duplicate', 'measure', 'delete'],
    'plan.nodes.edit': ['moveNode', 'addNode', 'align', 'mergeNodes', 'deleteNode', 'measure'],
    'plan.room.selected': ['contour', 'dimensions', 'measure', 'name', 'areaLabel'],
    'plan.opening.create': ['door', 'window', 'arch', 'emptyOpening', 'measure'],
    'plan.door.selected': ['move', 'doorSwing', 'center', 'align', 'duplicate', 'replace', 'measure', 'delete'],
    'plan.window.selected': ['move', 'replace', 'center', 'align', 'side', 'duplicate', 'measure', 'delete'],
    'plan.opening.selected': ['move', 'replace', 'center', 'align', 'duplicate', 'measure', 'delete'],
    'plan.demolition.create': ['segment', 'whole', 'split', 'measure'],
    'plan.demolition.selected': ['boundaries', 'clearMark', 'measure'],
    'plan.dimension.create': ['linearDimension', 'chainDimension', 'angularDimension', 'radialDimension', 'diameterDimension'],
    'plan.dimension.selected': ['move', 'points', 'flip', 'measure', 'delete'],
    'floor.idle': ['roomFill', 'contour', 'rooms', 'measure'],
    'floor.room.uncovered': ['lay', 'contour', 'rooms', 'measure'],
    'floor.pattern.selected': ['direction', 'patternShift', 'start', 'contour', 'link', 'align', 'measure', 'deleteCover'],
    'floor.contour.edit': ['nodes', 'cutout', 'addNode', 'deleteNode', 'measure'],
    'floor.cutout.selected': ['move', 'nodes', 'duplicate', 'measure', 'deleteCutout'],
    'floor.patterns.multi': ['link', 'direction', 'patternShift', 'unlink', 'measure'],
    'floor.underlay.create': ['followCover', 'contour', 'measure'],
    'floor.underlay.selected': ['contour', 'cutout', 'measure', 'deleteLayer'],
    'floor.plinth.create': ['byRoom', 'byWall', 'excludeSegment', 'measure'],
    'floor.plinth.selected': ['ends', 'break', 'extend', 'join', 'measure', 'deleteSegment'],
    'objects.idle': ['add', 'frame', 'measure'],
    'objects.placing': ['move', 'rotate', 'toWall', 'align', 'mirror'],
    'objects.object.selected': ['move', 'rotate', 'duplicate', 'align', 'toWall', 'mirror', 'measure', 'delete'],
    'objects.builtin.selected': ['move', 'replace', 'duplicate', 'align', 'mirror', 'measure', 'delete'],
    'objects.kitchen.row': ['move', 'addModule', 'lineUp', 'separate', 'measure', 'delete'],
    'objects.multi': ['move', 'rotate', 'align', 'spacing', 'group', 'duplicate', 'delete'],
    'objects.group.selected': ['move', 'rotate', 'ungroup', 'duplicate', 'align', 'measure', 'delete'],
    'electrical.idle': ['point', 'line', 'frame', 'measure'],
    'electrical.point.create': ['singlePoint', 'block', 'line', 'measure'],
    'electrical.light.create': ['light', 'row', 'line', 'measure'],
    'electrical.point.selected': ['move', 'side', 'duplicate', 'toBlock', 'group', 'line', 'measure', 'delete'],
    'electrical.block.selected': ['move', 'composition', 'duplicate', 'orientation', 'group', 'measure', 'delete'],
    'electrical.light.selected': ['move', 'rotate', 'duplicate', 'row', 'group', 'line', 'measure', 'delete'],
    'electrical.lights.row': ['move', 'direction', 'spacing', 'group', 'ungroup', 'measure', 'delete'],
    'electrical.line.create': ['straight', 'route', 'ortho', 'byWall', 'measure'],
    'electrical.line.selected': ['nodes', 'connect', 'split', 'reassignGroup', 'measure', 'delete'],
    'electrical.panel.selected': ['move', 'connections', 'groups', 'measure', 'delete'],
    'electrical.group.create': ['createGroup', 'selectPoints', 'measure'],
    'electrical.group.selected': ['addPoints', 'removePoints', 'showLines', 'rename', 'deleteGroup'],
  };

  static List<String> get profileIds => _profiles.keys.toList(growable:false);

  static const _labels = <String,String>{
    'select':'Выбрать', 'wall':'Стена', 'opening':'Проём',
    'measure':'Измерить', 'frame':'Рамка',
    'straight':'Прямая', 'arc':'Дуга', 'ortho':'90°',
    'parallel':'Параллель', 'closeContour':'Замкнуть',
    'move':'Сдвинуть', 'nodes':'Узлы', 'split':'Разделить',
    'extend':'Продолжить', 'join':'Соединить', 'duplicate':'Копия',
    'delete':'Удалить', 'moveNode':'Сдвинуть узел',
    'addNode':'Добавить узел', 'align':'Выровнять',
    'mergeNodes':'Объединить узлы', 'deleteNode':'Удалить узел',
    'contour':'Контур', 'dimensions':'Размеры', 'name':'Название',
    'areaLabel':'Метка площади', 'door':'Дверь',
    'window':'Окно', 'arch':'Арка','emptyOpening':'Пустой проём',
    'doorSwing':'Открывание', 'center':'По центру',
    'replace':'Заменить', 'side':'Сторона',
    'segment':'Участок', 'whole':'Целиком',
    'boundaries':'Границы','clearMark':'Снять метку',
    'linearDimension':'Линейный', 'chainDimension':'Цепочка',
    'angularDimension':'Угловой', 'radialDimension':'Радиус',
    'diameterDimension':'Диаметр', 'points':'Точки',
    'flip':'Перевернуть', 'roomFill':'В комнате',
    'rooms':'Несколько комнат', 'lay':'Уложить',
    'direction':'Направление', 'patternShift':'Сдвиг',
    'start':'Старт', 'link':'Связать', 'deleteCover':'Удалить покрытие',
    'cutout':'Вырез', 'deleteCutout':'Удалить вырез',
    'unlink':'Развязать', 'followCover':'По покрытию',
    'deleteLayer':'Удалить слой', 'byRoom':'По комнате',
    'byWall':'По стене', 'excludeSegment':'Исключить участок',
    'ends':'Концы', 'break':'Разрыв', 'deleteSegment':'Удалить участок',
    'add':'Добавить', 'rotate':'Повернуть', 'toWall':'К стене',
    'mirror':'Отразить', 'addModule':'Добавить модуль',
    'lineUp':'Выстроить', 'separate':'Разъединить',
    'spacing':'Интервалы','group':'Группа',
    'ungroup':'Разгруппировать','point':'Точка', 'line':'Линия',
    'singlePoint':'Одна точка','block':'Блок',
    'light':'Светильник', 'row':'Ряд',
    'toBlock':'В блок', 'composition':'Состав',
    'orientation':'Ориентация', 'route':'Трасса',
    'connect':'Подключить',
    'reassignGroup':'Переназначить группу',
    'connections':'Подключения','groups':'Группы',
    'createGroup':'Создать группу','selectPoints':'Выбрать точки',
    'addPoints':'Добавить точки','removePoints':'Убрать точки',
    'showLines':'Показать линии','rename':'Переименовать',
    'deleteGroup':'Удалить группу',
  };

  static IconData _icon(String id) => switch(id) {
    'select' => Icons.near_me_outlined,
    'wall' || 'straight' => Icons.border_outer_rounded,
    'opening' || 'door' || 'arch' => Icons.door_front_door_outlined,
    'window' => Icons.window_outlined,
    'nodes' || 'addNode' || 'mergeNodes' || 'moveNode' =>
      Icons.account_tree_outlined,
    'arc' || 'radialDimension' => Icons.architecture_outlined,
    'measure' || 'dimensions' || 'linearDimension' ||
    'chainDimension' => Icons.straighten_outlined,
    'move' || 'patternShift' => Icons.open_with_rounded,
    'ortho' => Icons.turn_right_outlined,
    'closeContour' || 'contour' => Icons.crop_square_outlined,
    'duplicate' => Icons.copy_outlined,
    'delete' || 'deleteCover' || 'deleteLayer' || 'deleteGroup' ||
    'deleteCutout' || 'deleteSegment' || 'deleteNode' => Icons.delete_outline,
    'rotate' || 'doorSwing' => Icons.rotate_right_outlined,
    'center' || 'align' => Icons.align_horizontal_center_outlined,
    'point' || 'singlePoint' => Icons.radio_button_checked_outlined,
    'line' || 'route' => Icons.polyline_outlined,
    'frame' => Icons.crop_free_rounded,
    'add' || 'lay' => Icons.add_circle_outline_rounded,
    'light' => Icons.lightbulb_outline_rounded,
    'group' || 'groups' => Icons.hub_outlined,
    'roomFill' || 'followCover' => Icons.grid_on_outlined,
    _ => Icons.tune_outlined,
  };

  static ZamerFanProfileV2 of(
    String id, {required Set<String> enabledActions}) {
    final spec = _profiles[id] ?? _profiles['plan.idle']!;
    ZamerKitCommand action(String id) => ZamerKitCommand(
      id, _labels[id] ?? id, _icon(id), enabled:
        enabledActions.contains(id));
    return ZamerFanProfileV2(
      id, action(spec[0]), action(spec[1]),
      spec.skip(2).map(action).toList(growable:false));
  }
}
