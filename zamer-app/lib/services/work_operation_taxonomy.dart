import 'work_generation_service.dart';

/// User-facing work library hierarchy. This is a presentation layer: the
/// stable operation codes and their original phases are never rewritten.
class WorkOperationTaxonomy {
  static const groups = <String>[
    'Подготовка',
    'Демонтаж',
    'Конструктив',
    'Стены',
    'Пол',
    'Потолок',
    'Электрика',
    'Инженерия',
    'Двери и окна',
    'Оборудование и финиш',
    'Контроль и сдача',
  ];

  static String groupOf(WorkOperation op) {
    switch (op.phase) {
      case 'Подготовка':
      case 'Демонтаж':
      case 'Конструктив':
        return op.phase;
      case 'Стены':
      case 'Декоративные стены':
        return 'Стены';
      case 'Плиточные работы':
        return _wallTiles.contains(op.code) ? 'Стены' : 'Пол';
      case 'Черновые':
      case 'Пол':
      case 'Черновые полы':
      case 'Напольные покрытия':
        return 'Пол';
      case 'Потолок':
      case 'Потолки':
        return 'Потолок';
      case 'Электрика':
      case 'Слаботочные системы':
        return 'Электрика';
      case 'Инженерия':
        return op.code == 'electrical_rough' ? 'Электрика' : 'Инженерия';
      case 'Сантехника':
      case 'Отопление и вентиляция':
        return 'Инженерия';
      case 'Финиш':
        return switch (op.code) {
          'doors' => 'Двери и окна',
          'skirting' => 'Пол',
          'electrical_finish' => 'Электрика',
          'plumbing_finish' => 'Инженерия',
          _ => 'Оборудование и финиш',
        };
      case 'Двери и окна':
        return 'Двери и окна';
      case 'Оборудование и финиш':
        return 'Оборудование и финиш';
      case 'Сдача':
      case 'Контроль и сдача':
        return 'Контроль и сдача';
      default:
        throw StateError('Не задана группа для операции: ${op.code}');
    }
  }

  static const _wallTiles = <String>{
    'tile_surface_prime', 'tile_wall_waterproof', 'tile_wall_porcelain',
    'tile_mosaic', 'tile_large_format', 'tile_niche', 'tile_hatch',
    'tile_corners', 'tile_grout_wall',
  };

  static String subgroupOf(WorkOperation op) {
    switch (groupOf(op)) {
      case 'Подготовка':
        return op.code.contains('delivery') ||
                op.code.contains('logistics') ||
                op.code.contains('waste') ||
                op.code.contains('temp_') ||
                op.code.contains('barriers')
            ? 'Организация площадки' : 'Обмеры и подготовка';
      case 'Демонтаж':
        if (op.code.contains('floor') || op.code.contains('laminate') ||
            op.code.contains('parquet') || op.code.contains('screed') ||
            op.code.contains('skirting')) return 'Полы и основания';
        if (op.code.contains('wall') || op.code.contains('partition') ||
            op.code.contains('plaster') || op.code.contains('gkl')) {
          return 'Стены и перегородки';
        }
        return 'Оборудование и прочее';
      case 'Конструктив':
        if (op.code.contains('opening') || op.code.contains('lintel')) {
          return 'Проёмы и усиление';
        }
        if (op.code.contains('concrete') ||
            op.code.contains('masonry')) return 'Ремонт оснований';
        return 'Перегородки и изоляция';
      case 'Стены':
        if (op.phase == 'Плиточные работы' || op.code == 'wall_tile') {
          return 'Плитка и облицовка';
        }
        if (op.code.contains('plaster') || op.code.contains('beacons') ||
            op.code.contains('mesh')) return 'Штукатурка';
        if (op.code.contains('putty') || op.code.contains('sanding') ||
            op.code.contains('fiberglass')) return 'Шпаклёвка и подготовка';
        if (op.code.contains('paint') || op.code.contains('prime_finish')) {
          return 'Окраска';
        }
        if (op.code.contains('panel') || op.code.contains('decor') ||
            op.code.contains('microcement')) return 'Декоративные покрытия';
        return 'Грунтовка, обои и прочее';
      case 'Пол':
        if (op.phase == 'Плиточные работы' ||
            op.code == 'floor_tile') return 'Плитка пола';
        if (op.code.contains('warm_floor')) return 'Тёплый пол';
        if (op.code.contains('skirting') || op.code.contains('expansion')) {
          return 'Плинтусы и стыки';
        }
        if (op.code.contains('screed') || op.code.contains('base') ||
            op.phase == 'Черновые полы' ||
            op.code.contains('waterproof') ||
            op.code.contains('insulation')) return 'Основания и стяжки';
        return 'Финишные покрытия';
      case 'Потолок':
        if (op.code.contains('stretch') || op.code.contains('shadow')) {
          return 'Натяжные потолки';
        }
        if (op.code.contains('gkl') || op.code.contains('soundproof')) {
          return 'ГКЛ и изоляция';
        }
        if (op.code.contains('profile') || op.code.contains('light_') ||
            op.code.contains('cornice')) return 'Профили и ниши';
        return 'Подготовка и окраска';
      case 'Электрика':
        if (op.phase == 'Слаботочные системы') return 'Слаботочные сети';
        if (op.code.contains('panel') || op.code.contains('rcd')) {
          return 'Электрощит и защита';
        }
        if (op.code.contains('light') || op.code.contains('led') ||
            op.code.contains('track')) return 'Освещение';
        if (op.code.contains('socket') || op.code.contains('switch') ||
            op.code.contains('dimmer')) return 'Розетки и выключатели';
        if (op.code.contains('test') || op.code.contains('commission')) {
          return 'Проверки и пусконаладка';
        }
        return 'Кабели и черновой монтаж';
      case 'Инженерия':
        if (op.code.startsWith('hvac_')) return 'Кондиционирование';
        if (op.code.startsWith('vent_') || op.code == 'ventilation') {
          return 'Вентиляция';
        }
        if (op.code.startsWith('heat_')) return 'Отопление';
        if (op.code.startsWith('plumb_') ||
            op.code == 'plumbing_finish') return 'Сантехника и водоснабжение';
        return 'Черновая инженерия';
      case 'Двери и окна':
        if (op.code.contains('window') || op.code.contains('balcony')) {
          return 'Окна и откосы';
        }
        if (op.code.contains('glass')) return 'Стеклянные конструкции';
        return 'Двери и фурнитура';
      case 'Оборудование и финиш':
        if (op.code.contains('kitchen') || op.code.contains('countertop') ||
            op.code.contains('appliance') || op.code.contains('extract') ||
            op.code.contains('backsplash')) return 'Кухни и техника';
        if (op.code.contains('wardrobe') || op.code.contains('cabinet')) {
          return 'Встроенная мебель';
        }
        return 'Аксессуары и оснащение';
      case 'Контроль и сдача':
        if (op.code == 'cleaning' || op.code == 'qc_defects') {
          return 'Уборка и замечания';
        }
        if (op.code.contains('handover') || op.code.contains('asbuilt') ||
            op.code == 'acceptance' || op.code == 'qc_final_photos') {
          return 'Сдача и документация';
        }
        return 'Контроль качества';
      default:
        throw StateError('Не задан подраздел: ${op.code}');
    }
  }

  static List<WorkOperation> inGroup(String group) =>
      WorkOperationCatalog.all.where((op) => groupOf(op) == group).toList();

  static List<String> subgroups(String group) {
    final names = <String>{};
    for (final op in inGroup(group)) {
      names.add(subgroupOf(op));
    }
    return names.toList();
  }

  static List<WorkOperation> search(
    String query, {String? group, String? subgroup}) {
    final value = query.trim().toLowerCase();
    return WorkOperationCatalog.all.where((op) {
      final primary = groupOf(op);
      final secondary = subgroupOf(op);
      return (group == null || primary == group) &&
          (subgroup == null || secondary == subgroup) &&
          (value.isEmpty || op.title.toLowerCase().contains(value) ||
              op.code.toLowerCase().contains(value) ||
              primary.toLowerCase().contains(value) ||
              secondary.toLowerCase().contains(value));
    }).toList();
  }
}
