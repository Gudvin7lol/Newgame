import 'dart:math' as math;

import '../models/models.dart';
import '../models/work_board.dart';
import 'geometry_service.dart';
import 'engineering_service.dart';
import 'work_surface_service.dart';

enum WorkQuantityBasis { floorArea, wallArea, ceilingArea, skirting, package }

class WorkOperation {
  const WorkOperation(this.code, this.title, this.phase, this.basis,
      this.hoursPerUnit, this.requiredCodes, {this.optional = false, this.catalogOnly = false});
  final String code, title, phase;
  final WorkQuantityBasis basis;
  final double hoursPerUnit;
  /// Required when both operations are selected in the same room.
  final List<String> requiredCodes;
  final bool optional;
  /// Catalogue-only items must be selected explicitly; not auto-applied per room.
  final bool catalogOnly;
}

/// Every entry can be selected in the manual operation catalogue. Only
/// entries supported by the 2D geometry/materials are auto-selected.
class WorkOperationCatalog {
  static const all = <WorkOperation>[
    WorkOperation('survey', 'Обмер и разметка', 'Подготовка', WorkQuantityBasis.package, 2, []),
    WorkOperation('protection', 'Защита и укрытие помещения', 'Подготовка', WorkQuantityBasis.floorArea, .25, ['survey']),
    WorkOperation('demolition', 'Демонтаж старой отделки', 'Демонтаж', WorkQuantityBasis.wallArea, .65, ['protection'], optional: true),
    WorkOperation('partitions', 'Возведение перегородок', 'Конструктив', WorkQuantityBasis.wallArea, 1.5, ['demolition'], optional: true),
    WorkOperation('electrical_rough', 'Электромонтаж: черновой этап', 'Инженерия', WorkQuantityBasis.package, 12, ['partitions'], optional: true),
    WorkOperation('plumbing_rough', 'Сантехника: черновой этап', 'Инженерия', WorkQuantityBasis.package, 12, ['partitions'], optional: true),
    WorkOperation('ventilation', 'Вентиляция и воздуховоды', 'Инженерия', WorkQuantityBasis.package, 10, ['partitions'], optional: true),
    WorkOperation('floor_base', 'Подготовка основания пола', 'Черновые', WorkQuantityBasis.floorArea, .4, ['demolition']),
    WorkOperation('floor_waterproof', 'Гидроизоляция пола', 'Черновые', WorkQuantityBasis.floorArea, .5, ['floor_base'], optional: true),
    WorkOperation('wall_primer', 'Грунтовка стен', 'Стены', WorkQuantityBasis.wallArea, .17, ['demolition', 'electrical_rough', 'plumbing_rough']),
    WorkOperation('wall_plaster', 'Штукатурка стен', 'Стены', WorkQuantityBasis.wallArea, 1.15, ['wall_primer']),
    WorkOperation('wall_waterproof', 'Гидроизоляция стен', 'Стены', WorkQuantityBasis.wallArea, .5, ['wall_plaster'], optional: true),
    WorkOperation('wall_putty', 'Шпаклёвка и шлифовка стен', 'Стены', WorkQuantityBasis.wallArea, .75, ['wall_plaster']),
    WorkOperation('wall_prime_finish', 'Грунтовка перед финишем стен', 'Стены', WorkQuantityBasis.wallArea, .15, ['wall_putty']),
    WorkOperation('wall_paint', 'Окраска стен', 'Стены', WorkQuantityBasis.wallArea, .55, ['wall_prime_finish']),
    WorkOperation('wall_wallpaper', 'Поклейка обоев', 'Стены', WorkQuantityBasis.wallArea, .5, ['wall_prime_finish'], optional: true),
    WorkOperation('wall_tile', 'Укладка плитки стен', 'Стены', WorkQuantityBasis.wallArea, 1.3, ['wall_plaster', 'wall_waterproof']),
    WorkOperation('warm_floor', 'Монтаж тёплого пола', 'Пол', WorkQuantityBasis.floorArea, .65, ['floor_waterproof'], optional: true),
    WorkOperation('screed', 'Устройство стяжки пола', 'Пол', WorkQuantityBasis.floorArea, .85, ['floor_base', 'warm_floor'], optional: true),
    WorkOperation('floor_underlay', 'Укладка подложки', 'Пол', WorkQuantityBasis.floorArea, .18, ['floor_base', 'screed']),
    WorkOperation('floor_laminate', 'Укладка ламината', 'Пол', WorkQuantityBasis.floorArea, .7, ['floor_underlay']),
    WorkOperation('floor_tile', 'Укладка плитки пола', 'Пол', WorkQuantityBasis.floorArea, 1.15, ['floor_base', 'floor_waterproof', 'screed']),
    WorkOperation('ceiling_base', 'Подготовка основания потолка', 'Потолок', WorkQuantityBasis.ceilingArea, .4, ['electrical_rough']),
    WorkOperation('ceiling_gkl', 'Монтаж потолка ГКЛ', 'Потолок', WorkQuantityBasis.ceilingArea, 1.2, ['ceiling_base']),
    WorkOperation('ceiling_stretch', 'Монтаж натяжного потолка', 'Потолок', WorkQuantityBasis.ceilingArea, .75, ['ceiling_base']),
    WorkOperation('ceiling_prime', 'Грунтовка потолка', 'Потолок', WorkQuantityBasis.ceilingArea, .2, ['ceiling_base']),
    WorkOperation('ceiling_paint', 'Окраска потолка', 'Потолок', WorkQuantityBasis.ceilingArea, .55, ['ceiling_prime']),
    WorkOperation('doors', 'Установка межкомнатных дверей', 'Финиш', WorkQuantityBasis.package, 4, ['floor_laminate', 'floor_tile', 'wall_paint'], optional: true),
    WorkOperation('skirting', 'Монтаж плинтуса', 'Финиш', WorkQuantityBasis.skirting, .35, ['floor_laminate', 'floor_tile']),
    WorkOperation('electrical_finish', 'Установка электрофурнитуры и света', 'Финиш', WorkQuantityBasis.package, 6, ['electrical_rough', 'wall_paint', 'ceiling_paint'], optional: true),
    WorkOperation('plumbing_finish', 'Установка сантехприборов', 'Финиш', WorkQuantityBasis.package, 8, ['plumbing_rough', 'wall_tile', 'floor_tile'], optional: true),
    WorkOperation('fixtures', 'Монтаж оборудования и аксессуаров', 'Финиш', WorkQuantityBasis.package, 4, ['wall_paint', 'floor_laminate'], optional: true),
    WorkOperation('cleaning', 'Уборка после ремонта', 'Сдача', WorkQuantityBasis.floorArea, .2, []),
    WorkOperation('acceptance', 'Приёмка помещения', 'Сдача', WorkQuantityBasis.package, 2, ['cleaning']),
    // Подготовка
    WorkOperation('site_logistics', 'Организация складирования и проходов', 'Подготовка', WorkQuantityBasis.package, 4, ['survey'], optional: true, catalogOnly: true),
    WorkOperation('site_temp_power', 'Временное электроснабжение площадки', 'Подготовка', WorkQuantityBasis.package, 4, ['survey'], optional: true, catalogOnly: true),
    WorkOperation('site_temp_water', 'Временное водоснабжение', 'Подготовка', WorkQuantityBasis.package, 3, ['survey'], optional: true, catalogOnly: true),
    WorkOperation('site_dust_barriers', 'Установка пылезащитных перегородок', 'Подготовка', WorkQuantityBasis.skirting, .45, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('site_layout', 'Разметка осей и отметок', 'Подготовка', WorkQuantityBasis.floorArea, .15, ['survey'], optional: true, catalogOnly: true),
    WorkOperation('site_moisture_check', 'Контроль влажности основания', 'Подготовка', WorkQuantityBasis.package, 2, ['survey'], optional: true, catalogOnly: true),
    WorkOperation('site_delivery', 'Приёмка и разгрузка материалов', 'Подготовка', WorkQuantityBasis.package, 5, ['survey'], optional: true, catalogOnly: true),
    WorkOperation('site_waste_loading', 'Вынос и погрузка строительного мусора', 'Подготовка', WorkQuantityBasis.package, 5, ['demolition'], optional: true, catalogOnly: true),
    // Демонтаж
    WorkOperation('demo_wallpaper', 'Снятие обоев', 'Демонтаж', WorkQuantityBasis.wallArea, .25, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_wall_paint', 'Удаление старой краски со стен', 'Демонтаж', WorkQuantityBasis.wallArea, .45, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_wall_plaster', 'Удаление штукатурки', 'Демонтаж', WorkQuantityBasis.wallArea, .8, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_wall_tile', 'Демонтаж настенной плитки', 'Демонтаж', WorkQuantityBasis.wallArea, .7, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_floor_tile', 'Демонтаж напольной плитки', 'Демонтаж', WorkQuantityBasis.floorArea, .9, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_laminate', 'Демонтаж ламината и подложки', 'Демонтаж', WorkQuantityBasis.floorArea, .24, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_parquet', 'Демонтаж паркета', 'Демонтаж', WorkQuantityBasis.floorArea, .6, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_screed', 'Демонтаж стяжки', 'Демонтаж', WorkQuantityBasis.floorArea, 1.25, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_skirting', 'Демонтаж плинтусов', 'Демонтаж', WorkQuantityBasis.skirting, .16, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_gkl', 'Демонтаж гипсокартонных конструкций', 'Демонтаж', WorkQuantityBasis.wallArea, .65, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_partition', 'Демонтаж ненесущих перегородок', 'Демонтаж', WorkQuantityBasis.wallArea, 1.3, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_ceiling', 'Разборка подвесного потолка', 'Демонтаж', WorkQuantityBasis.ceilingArea, .4, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_door_block', 'Демонтаж дверного блока', 'Демонтаж', WorkQuantityBasis.package, 1.7, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_window_block', 'Демонтаж оконного блока', 'Демонтаж', WorkQuantityBasis.package, 2.8, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_sanitary', 'Демонтаж сантехнических приборов', 'Демонтаж', WorkQuantityBasis.package, 3, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('demo_electrical', 'Демонтаж электрофурнитуры', 'Демонтаж', WorkQuantityBasis.package, 2, ['protection'], optional: true, catalogOnly: true),
    // Конструктив
    WorkOperation('struct_gas_partition', 'Кладка перегородок из газоблока', 'Конструктив', WorkQuantityBasis.wallArea, 1.45, ['demolition'], optional: true, catalogOnly: true),
    WorkOperation('struct_brick_partition', 'Кладка кирпичных перегородок', 'Конструктив', WorkQuantityBasis.wallArea, 2.25, ['demolition'], optional: true, catalogOnly: true),
    WorkOperation('struct_gkl_frame', 'Монтаж каркаса перегородки ГКЛ', 'Конструктив', WorkQuantityBasis.wallArea, .95, ['demolition'], optional: true, catalogOnly: true),
    WorkOperation('struct_gkl_sheathing', 'Обшивка перегородки гипсокартоном', 'Конструктив', WorkQuantityBasis.wallArea, .85, ['struct_gkl_frame'], optional: true, catalogOnly: true),
    WorkOperation('struct_partition_wool', 'Звукоизоляция перегородки минватой', 'Конструктив', WorkQuantityBasis.wallArea, .35, ['struct_gkl_frame'], optional: true, catalogOnly: true),
    WorkOperation('struct_partition_joint', 'Армирование и заделка швов ГКЛ', 'Конструктив', WorkQuantityBasis.wallArea, .42, ['struct_gkl_sheathing'], optional: true, catalogOnly: true),
    WorkOperation('struct_repair_masonry', 'Локальный ремонт кладки', 'Конструктив', WorkQuantityBasis.wallArea, 1.15, ['demolition'], optional: true, catalogOnly: true),
    WorkOperation('struct_level_opening', 'Подготовка и выравнивание дверного проёма', 'Конструктив', WorkQuantityBasis.package, 3, ['survey'], optional: true, catalogOnly: true),
    WorkOperation('struct_lintel', 'Установка перемычки по проекту', 'Конструктив', WorkQuantityBasis.package, 5, ['struct_level_opening'], optional: true, catalogOnly: true),
    WorkOperation('struct_opening_engineered', 'Усиление проёма по инженерному проекту', 'Конструктив', WorkQuantityBasis.package, 18, ['survey'], optional: true, catalogOnly: true),
    WorkOperation('struct_concrete_repair', 'Ремонт бетонного основания', 'Конструктив', WorkQuantityBasis.floorArea, .65, ['demolition'], optional: true, catalogOnly: true),
    WorkOperation('struct_soundproof_wall', 'Монтаж звукоизоляции стен', 'Конструктив', WorkQuantityBasis.wallArea, .8, ['struct_repair_masonry'], optional: true, catalogOnly: true),
    // Электрика
    WorkOperation('elec_marking', 'Разметка электромонтажных точек', 'Электрика', WorkQuantityBasis.package, 3, ['survey'], optional: true, catalogOnly: true),
    WorkOperation('elec_grooving', 'Штробление под кабельные линии', 'Электрика', WorkQuantityBasis.skirting, .48, ['elec_marking'], optional: true, catalogOnly: true),
    WorkOperation('elec_socket_drilling', 'Подготовка отверстий под подрозетники', 'Электрика', WorkQuantityBasis.package, 1.2, ['elec_marking'], optional: true, catalogOnly: true),
    WorkOperation('elec_socket_boxes', 'Установка подрозетников', 'Электрика', WorkQuantityBasis.package, .6, ['elec_socket_drilling'], optional: true, catalogOnly: true),
    WorkOperation('elec_conduit', 'Прокладка гофры и кабель-каналов', 'Электрика', WorkQuantityBasis.skirting, .35, ['elec_grooving'], optional: true, catalogOnly: true),
    WorkOperation('elec_power_cable', 'Прокладка силового кабеля', 'Электрика', WorkQuantityBasis.skirting, .3, ['elec_conduit'], optional: true, catalogOnly: true),
    WorkOperation('elec_light_cable', 'Прокладка осветительного кабеля', 'Электрика', WorkQuantityBasis.skirting, .25, ['elec_conduit'], optional: true, catalogOnly: true),
    WorkOperation('elec_panel_niche', 'Подготовка ниши электрощита', 'Электрика', WorkQuantityBasis.package, 4, ['elec_marking'], optional: true, catalogOnly: true),
    WorkOperation('elec_panel_assemble', 'Компоновка и сборка электрощита', 'Электрика', WorkQuantityBasis.package, 12, ['elec_panel_niche'], optional: true, catalogOnly: true),
    WorkOperation('elec_panel_mount', 'Монтаж и подключение электрощита', 'Электрика', WorkQuantityBasis.package, 6, ['elec_panel_assemble'], optional: true, catalogOnly: true),
    WorkOperation('elec_outlets', 'Монтаж розеток', 'Электрика', WorkQuantityBasis.package, .45, ['electrical_rough'], optional: true, catalogOnly: true),
    WorkOperation('elec_switches', 'Монтаж выключателей', 'Электрика', WorkQuantityBasis.package, .45, ['electrical_rough'], optional: true, catalogOnly: true),
    WorkOperation('elec_dimmers', 'Монтаж диммеров и реле', 'Электрика', WorkQuantityBasis.package, .8, ['electrical_rough'], optional: true, catalogOnly: true),
    WorkOperation('elec_light_points', 'Монтаж потолочных светоточек', 'Электрика', WorkQuantityBasis.package, .8, ['electrical_rough'], optional: true, catalogOnly: true),
    WorkOperation('elec_wall_lights', 'Монтаж настенных светильников', 'Электрика', WorkQuantityBasis.package, .9, ['electrical_rough'], optional: true, catalogOnly: true),
    WorkOperation('elec_track_light', 'Монтаж трекового освещения', 'Электрика', WorkQuantityBasis.skirting, .75, ['electrical_rough'], optional: true, catalogOnly: true),
    WorkOperation('elec_led_strip', 'Монтаж LED-ленты с профилем', 'Электрика', WorkQuantityBasis.skirting, .7, ['electrical_rough'], optional: true, catalogOnly: true),
    WorkOperation('elec_led_supply', 'Подключение LED-блоков питания', 'Электрика', WorkQuantityBasis.package, 1.2, ['elec_led_strip'], optional: true, catalogOnly: true),
    WorkOperation('elec_equpotential', 'Устройство уравнивания потенциалов', 'Электрика', WorkQuantityBasis.package, 3, ['electrical_rough'], optional: true, catalogOnly: true),
    WorkOperation('elec_insulation_test', 'Измерение сопротивления изоляции', 'Электрика', WorkQuantityBasis.package, 3, ['elec_power_cable'], optional: true, catalogOnly: true),
    WorkOperation('elec_rcd_test', 'Проверка УЗО и дифавтоматов', 'Электрика', WorkQuantityBasis.package, 2, ['elec_panel_mount'], optional: true, catalogOnly: true),
    WorkOperation('elec_commission', 'Пусконаладка электросистемы', 'Электрика', WorkQuantityBasis.package, 5, ['elec_panel_mount'], optional: true, catalogOnly: true),
    // Слаботочные системы
    WorkOperation('low_data_cable', 'Прокладка кабеля витой пары', 'Слаботочные системы', WorkQuantityBasis.skirting, .28, ['electrical_rough'], optional: true, catalogOnly: true),
    WorkOperation('low_tv_cable', 'Прокладка коаксиального кабеля', 'Слаботочные системы', WorkQuantityBasis.skirting, .28, ['electrical_rough'], optional: true, catalogOnly: true),
    WorkOperation('low_fiber', 'Прокладка оптоволоконной линии', 'Слаботочные системы', WorkQuantityBasis.skirting, .32, ['electrical_rough'], optional: true, catalogOnly: true),
    WorkOperation('low_network_outlet', 'Монтаж сетевой розетки RJ-45', 'Слаботочные системы', WorkQuantityBasis.package, .75, ['low_data_cable'], optional: true, catalogOnly: true),
    WorkOperation('low_router_rack', 'Монтаж телекоммуникационного шкафа', 'Слаботочные системы', WorkQuantityBasis.package, 4, ['low_data_cable'], optional: true, catalogOnly: true),
    WorkOperation('low_intercom', 'Монтаж домофонной панели', 'Слаботочные системы', WorkQuantityBasis.package, 2.5, ['low_data_cable'], optional: true, catalogOnly: true),
    WorkOperation('low_video', 'Монтаж камеры видеонаблюдения', 'Слаботочные системы', WorkQuantityBasis.package, 3, ['low_data_cable'], optional: true, catalogOnly: true),
    WorkOperation('low_sensors', 'Монтаж датчиков протечки и движения', 'Слаботочные системы', WorkQuantityBasis.package, 1.2, ['low_data_cable'], optional: true, catalogOnly: true),
    WorkOperation('low_smarthome', 'Подключение контроллера умного дома', 'Слаботочные системы', WorkQuantityBasis.package, 6, ['low_data_cable'], optional: true, catalogOnly: true),
    WorkOperation('low_tests', 'Тестирование слаботочных линий', 'Слаботочные системы', WorkQuantityBasis.package, 4, ['low_data_cable'], optional: true, catalogOnly: true),
    // Сантехника
    WorkOperation('plumb_marking', 'Разметка водопроводных и канализационных точек', 'Сантехника', WorkQuantityBasis.package, 3, ['survey'], optional: true, catalogOnly: true),
    WorkOperation('plumb_grooves', 'Подготовка каналов для труб', 'Сантехника', WorkQuantityBasis.skirting, .55, ['plumb_marking'], optional: true, catalogOnly: true),
    WorkOperation('plumb_water_cold', 'Прокладка ХВС', 'Сантехника', WorkQuantityBasis.skirting, .65, ['plumb_grooves'], optional: true, catalogOnly: true),
    WorkOperation('plumb_water_hot', 'Прокладка ГВС', 'Сантехника', WorkQuantityBasis.skirting, .65, ['plumb_grooves'], optional: true, catalogOnly: true),
    WorkOperation('plumb_waste', 'Прокладка канализационных труб', 'Сантехника', WorkQuantityBasis.skirting, .85, ['plumb_marking'], optional: true, catalogOnly: true),
    WorkOperation('plumb_manifold', 'Монтаж коллектора и запорной арматуры', 'Сантехника', WorkQuantityBasis.package, 5, ['plumb_water_cold'], optional: true, catalogOnly: true),
    WorkOperation('plumb_filters', 'Монтаж фильтров и редукторов', 'Сантехника', WorkQuantityBasis.package, 3, ['plumb_water_cold'], optional: true, catalogOnly: true),
    WorkOperation('plumb_leak_protection', 'Монтаж защиты от протечек', 'Сантехника', WorkQuantityBasis.package, 3, ['plumb_water_cold'], optional: true, catalogOnly: true),
    WorkOperation('plumb_pressure_test', 'Опрессовка водопроводных линий', 'Сантехника', WorkQuantityBasis.package, 3, ['plumb_water_hot', 'plumb_water_cold'], optional: true, catalogOnly: true),
    WorkOperation('plumb_wall_frames', 'Монтаж инсталляции подвесного унитаза', 'Сантехника', WorkQuantityBasis.package, 5, ['plumbing_rough'], optional: true, catalogOnly: true),
    WorkOperation('plumb_toilet', 'Установка унитаза', 'Сантехника', WorkQuantityBasis.package, 2, ['plumbing_rough'], optional: true, catalogOnly: true),
    WorkOperation('plumb_bidet', 'Установка биде', 'Сантехника', WorkQuantityBasis.package, 2.5, ['plumbing_rough'], optional: true, catalogOnly: true),
    WorkOperation('plumb_sink', 'Установка раковины и сифона', 'Сантехника', WorkQuantityBasis.package, 2.5, ['plumbing_rough'], optional: true, catalogOnly: true),
    WorkOperation('plumb_tap', 'Установка смесителя', 'Сантехника', WorkQuantityBasis.package, 1.25, ['plumbing_rough'], optional: true, catalogOnly: true),
    WorkOperation('plumb_bath', 'Установка ванны и обвязки', 'Сантехника', WorkQuantityBasis.package, 5, ['plumbing_rough'], optional: true, catalogOnly: true),
    WorkOperation('plumb_shower_tray', 'Монтаж душевого поддона', 'Сантехника', WorkQuantityBasis.package, 4, ['plumbing_rough'], optional: true, catalogOnly: true),
    WorkOperation('plumb_shower_drain', 'Установка душевого трапа', 'Сантехника', WorkQuantityBasis.package, 4, ['plumb_waste'], optional: true, catalogOnly: true),
    WorkOperation('plumb_shower_partition', 'Монтаж душевого ограждения', 'Сантехника', WorkQuantityBasis.package, 4, ['wall_tile'], optional: true, catalogOnly: true),
    WorkOperation('plumb_towel_drier', 'Монтаж полотенцесушителя', 'Сантехника', WorkQuantityBasis.package, 3, ['plumbing_rough'], optional: true, catalogOnly: true),
    WorkOperation('plumb_appliance', 'Подключение стиральной и посудомоечной машины', 'Сантехника', WorkQuantityBasis.package, 2, ['plumbing_rough'], optional: true, catalogOnly: true),
    WorkOperation('plumb_seal_tests', 'Проверка соединений и герметичности', 'Сантехника', WorkQuantityBasis.package, 2, ['plumb_pressure_test'], optional: true, catalogOnly: true),
    // Отопление и вентиляция
    WorkOperation('heat_radiator_remove', 'Демонтаж радиатора', 'Отопление и вентиляция', WorkQuantityBasis.package, 1.5, ['protection'], optional: true, catalogOnly: true),
    WorkOperation('heat_radiator_install', 'Монтаж радиатора отопления', 'Отопление и вентиляция', WorkQuantityBasis.package, 3, ['plumbing_rough'], optional: true, catalogOnly: true),
    WorkOperation('heat_pipework', 'Прокладка труб отопления', 'Отопление и вентиляция', WorkQuantityBasis.skirting, .8, ['plumbing_rough'], optional: true, catalogOnly: true),
    WorkOperation('heat_manifold', 'Монтаж коллектора отопления', 'Отопление и вентиляция', WorkQuantityBasis.package, 5, ['heat_pipework'], optional: true, catalogOnly: true),
    WorkOperation('heat_floor_circuit', 'Укладка контуров водяного тёплого пола', 'Отопление и вентиляция', WorkQuantityBasis.floorArea, .75, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('heat_floor_electric', 'Монтаж электрических нагревательных матов', 'Отопление и вентиляция', WorkQuantityBasis.floorArea, .45, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('heat_insulation', 'Теплоизоляция трубопроводов', 'Отопление и вентиляция', WorkQuantityBasis.skirting, .26, ['heat_pipework'], optional: true, catalogOnly: true),
    WorkOperation('heat_pressure_test', 'Опрессовка системы отопления', 'Отопление и вентиляция', WorkQuantityBasis.package, 4, ['heat_pipework'], optional: true, catalogOnly: true),
    WorkOperation('vent_ducts', 'Монтаж воздуховодов', 'Отопление и вентиляция', WorkQuantityBasis.skirting, .85, ['partitions'], optional: true, catalogOnly: true),
    WorkOperation('vent_exhaust_fan', 'Монтаж вытяжного вентилятора', 'Отопление и вентиляция', WorkQuantityBasis.package, 2, ['vent_ducts'], optional: true, catalogOnly: true),
    WorkOperation('vent_diffusers', 'Установка вентрешёток и диффузоров', 'Отопление и вентиляция', WorkQuantityBasis.package, .8, ['vent_ducts'], optional: true, catalogOnly: true),
    WorkOperation('vent_airflow_test', 'Проверка расхода воздуха', 'Отопление и вентиляция', WorkQuantityBasis.package, 3, ['vent_ducts'], optional: true, catalogOnly: true),
    WorkOperation('hvac_split_lines', 'Прокладка трассы кондиционера', 'Отопление и вентиляция', WorkQuantityBasis.skirting, .9, ['electrical_rough'], optional: true, catalogOnly: true),
    WorkOperation('hvac_split_unit', 'Монтаж внутреннего блока кондиционера', 'Отопление и вентиляция', WorkQuantityBasis.package, 4, ['hvac_split_lines'], optional: true, catalogOnly: true),
    WorkOperation('hvac_commission', 'Пусконаладка кондиционирования', 'Отопление и вентиляция', WorkQuantityBasis.package, 4, ['hvac_split_unit'], optional: true, catalogOnly: true),
    // Черновые полы
    WorkOperation('rough_subfloor_repair', 'Ремонт трещин основания пола', 'Черновые полы', WorkQuantityBasis.floorArea, .45, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('rough_floor_primer', 'Грунтование основания пола', 'Черновые полы', WorkQuantityBasis.floorArea, .13, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('rough_floor_insulation', 'Укладка теплоизоляции пола', 'Черновые полы', WorkQuantityBasis.floorArea, .35, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('rough_floor_acoustic', 'Укладка звукоизоляции пола', 'Черновые полы', WorkQuantityBasis.floorArea, .32, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('rough_dpm', 'Пароизоляция основания пола', 'Черновые полы', WorkQuantityBasis.floorArea, .24, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('rough_floor_mesh', 'Армирование стяжки сеткой', 'Черновые полы', WorkQuantityBasis.floorArea, .35, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('rough_dry_screed', 'Устройство сухой стяжки', 'Черновые полы', WorkQuantityBasis.floorArea, 1, ['rough_floor_insulation'], optional: true, catalogOnly: true),
    WorkOperation('rough_selflevel', 'Наливной пол и финишное выравнивание', 'Черновые полы', WorkQuantityBasis.floorArea, .6, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('rough_screed_beacons', 'Установка маяков для стяжки', 'Черновые полы', WorkQuantityBasis.floorArea, .28, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('rough_floor_plywood', 'Настил фанеры на основание', 'Черновые полы', WorkQuantityBasis.floorArea, .65, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('rough_floor_joists', 'Устройство лаг пола', 'Черновые полы', WorkQuantityBasis.floorArea, 1.15, ['floor_base'], optional: true, catalogOnly: true),
    // Декоративные стены
    WorkOperation('wall_remove_dust', 'Обеспыливание стен', 'Декоративные стены', WorkQuantityBasis.wallArea, .08, ['demolition'], optional: true, catalogOnly: true),
    WorkOperation('wall_beacons', 'Установка штукатурных маяков', 'Декоративные стены', WorkQuantityBasis.wallArea, .3, ['wall_primer'], optional: true, catalogOnly: true),
    WorkOperation('wall_mesh', 'Армирование штукатурного слоя', 'Декоративные стены', WorkQuantityBasis.wallArea, .42, ['wall_primer'], optional: true, catalogOnly: true),
    WorkOperation('wall_plaster_cement', 'Цементная штукатурка стен', 'Декоративные стены', WorkQuantityBasis.wallArea, 1.35, ['wall_primer'], optional: true, catalogOnly: true),
    WorkOperation('wall_plaster_gypsum', 'Гипсовая штукатурка стен', 'Декоративные стены', WorkQuantityBasis.wallArea, 1.05, ['wall_primer'], optional: true, catalogOnly: true),
    WorkOperation('wall_putty_base', 'Базовая шпаклёвка стен', 'Декоративные стены', WorkQuantityBasis.wallArea, .48, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('wall_putty_finish', 'Финишная шпаклёвка стен', 'Декоративные стены', WorkQuantityBasis.wallArea, .38, ['wall_putty_base'], optional: true, catalogOnly: true),
    WorkOperation('wall_sanding', 'Шлифование стен', 'Декоративные стены', WorkQuantityBasis.wallArea, .28, ['wall_putty_finish'], optional: true, catalogOnly: true),
    WorkOperation('wall_fiberglass', 'Поклейка стеклохолста', 'Декоративные стены', WorkQuantityBasis.wallArea, .48, ['wall_putty_base'], optional: true, catalogOnly: true),
    WorkOperation('wall_decorative_plaster', 'Декоративная штукатурка стен', 'Декоративные стены', WorkQuantityBasis.wallArea, .95, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('wall_microcement', 'Микроцемент на стенах', 'Декоративные стены', WorkQuantityBasis.wallArea, 1.65, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('wall_panel_mdf', 'Монтаж панелей МДФ', 'Декоративные стены', WorkQuantityBasis.wallArea, .95, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('wall_panel_pvc', 'Монтаж ПВХ-панелей', 'Декоративные стены', WorkQuantityBasis.wallArea, .65, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('wall_3d_panels', 'Монтаж декоративных 3D-панелей', 'Декоративные стены', WorkQuantityBasis.wallArea, 1.05, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('wall_niche', 'Отделка ниш и откосов стен', 'Декоративные стены', WorkQuantityBasis.package, 4, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('wall_paint_extra_coat', 'Дополнительный слой краски', 'Декоративные стены', WorkQuantityBasis.wallArea, .33, ['wall_paint'], optional: true, catalogOnly: true),
    WorkOperation('wall_decor_seal', 'Защитный лак на декоративном покрытии', 'Декоративные стены', WorkQuantityBasis.wallArea, .32, ['wall_decorative_plaster'], optional: true, catalogOnly: true),
    // Плиточные работы
    WorkOperation('tile_surface_prime', 'Грунтовка под облицовку', 'Плиточные работы', WorkQuantityBasis.wallArea, .18, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('tile_floor_waterproof', 'Обмазочная гидроизоляция под плитку пола', 'Плиточные работы', WorkQuantityBasis.floorArea, .48, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('tile_wall_waterproof', 'Обмазочная гидроизоляция стен', 'Плиточные работы', WorkQuantityBasis.wallArea, .5, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('tile_floor_porcelain', 'Укладка керамогранита на пол', 'Плиточные работы', WorkQuantityBasis.floorArea, 1.2, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('tile_wall_porcelain', 'Укладка керамогранита на стены', 'Плиточные работы', WorkQuantityBasis.wallArea, 1.45, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('tile_mosaic', 'Укладка мозаики', 'Плиточные работы', WorkQuantityBasis.wallArea, 1.8, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('tile_large_format', 'Монтаж крупноформатных плит', 'Плиточные работы', WorkQuantityBasis.wallArea, 2.4, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('tile_niche', 'Облицовка плиткой ниш', 'Плиточные работы', WorkQuantityBasis.package, 6, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('tile_hatch', 'Монтаж скрытого люка под плитку', 'Плиточные работы', WorkQuantityBasis.package, 4, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('tile_corners', 'Установка плиточных профилей и уголков', 'Плиточные работы', WorkQuantityBasis.skirting, .24, ['wall_tile'], optional: true, catalogOnly: true),
    WorkOperation('tile_grout_wall', 'Затирка швов плитки стен', 'Плиточные работы', WorkQuantityBasis.wallArea, .4, ['wall_tile'], optional: true, catalogOnly: true),
    WorkOperation('tile_grout_floor', 'Затирка швов плитки пола', 'Плиточные работы', WorkQuantityBasis.floorArea, .35, ['floor_tile'], optional: true, catalogOnly: true),
    WorkOperation('tile_silicone', 'Герметизация примыканий плитки', 'Плиточные работы', WorkQuantityBasis.skirting, .35, ['floor_tile'], optional: true, catalogOnly: true),
    WorkOperation('tile_cleaning', 'Очистка облицовки от затирки', 'Плиточные работы', WorkQuantityBasis.floorArea, .18, ['tile_grout_floor'], optional: true, catalogOnly: true),
    // Потолки
    WorkOperation('ceil_dust', 'Очистка потолка', 'Потолки', WorkQuantityBasis.ceilingArea, .14, ['ceiling_base'], optional: true, catalogOnly: true),
    WorkOperation('ceil_plaster', 'Штукатурка потолка', 'Потолки', WorkQuantityBasis.ceilingArea, 1.35, ['ceiling_base'], optional: true, catalogOnly: true),
    WorkOperation('ceil_base_putty', 'Шпаклёвка потолка базовая', 'Потолки', WorkQuantityBasis.ceilingArea, .7, ['ceiling_base'], optional: true, catalogOnly: true),
    WorkOperation('ceil_finish_putty', 'Шпаклёвка потолка финишная', 'Потолки', WorkQuantityBasis.ceilingArea, .5, ['ceil_base_putty'], optional: true, catalogOnly: true),
    WorkOperation('ceil_sanding', 'Шлифование потолка', 'Потолки', WorkQuantityBasis.ceilingArea, .35, ['ceil_finish_putty'], optional: true, catalogOnly: true),
    WorkOperation('ceil_gkl_frame', 'Монтаж каркаса ГКЛ потолка', 'Потолки', WorkQuantityBasis.ceilingArea, .85, ['ceiling_base'], optional: true, catalogOnly: true),
    WorkOperation('ceil_gkl_sheet', 'Обшивка потолка ГКЛ', 'Потолки', WorkQuantityBasis.ceilingArea, .65, ['ceil_gkl_frame'], optional: true, catalogOnly: true),
    WorkOperation('ceil_soundproof', 'Звукоизоляция потолка', 'Потолки', WorkQuantityBasis.ceilingArea, .65, ['ceiling_base'], optional: true, catalogOnly: true),
    WorkOperation('ceil_shadow_profile', 'Монтаж теневого профиля', 'Потолки', WorkQuantityBasis.skirting, .65, ['ceiling_stretch'], optional: true, catalogOnly: true),
    WorkOperation('ceil_light_niche', 'Монтаж потолочной ниши под свет', 'Потолки', WorkQuantityBasis.skirting, 1.1, ['ceiling_base'], optional: true, catalogOnly: true),
    WorkOperation('ceil_cornice', 'Монтаж потолочного карниза', 'Потолки', WorkQuantityBasis.skirting, .4, ['ceiling_paint'], optional: true, catalogOnly: true),
    WorkOperation('ceil_stretch_profile', 'Монтаж багета натяжного потолка', 'Потолки', WorkQuantityBasis.skirting, .45, ['ceiling_base'], optional: true, catalogOnly: true),
    WorkOperation('ceil_stretch_fabric', 'Натяжка полотна потолка', 'Потолки', WorkQuantityBasis.ceilingArea, .55, ['ceil_stretch_profile'], optional: true, catalogOnly: true),
    WorkOperation('ceil_light_holes', 'Устройство отверстий под освещение', 'Потолки', WorkQuantityBasis.package, .7, ['ceiling_stretch'], optional: true, catalogOnly: true),
    // Напольные покрытия
    WorkOperation('finish_spc', 'Укладка SPC-покрытия', 'Напольные покрытия', WorkQuantityBasis.floorArea, .7, ['floor_underlay'], optional: true, catalogOnly: true),
    WorkOperation('finish_engineered_wood', 'Укладка инженерной доски', 'Напольные покрытия', WorkQuantityBasis.floorArea, 1.2, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('finish_parquet', 'Укладка штучного паркета', 'Напольные покрытия', WorkQuantityBasis.floorArea, 1.8, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('finish_parquet_sanding', 'Шлифование паркета', 'Напольные покрытия', WorkQuantityBasis.floorArea, 1.05, ['finish_parquet'], optional: true, catalogOnly: true),
    WorkOperation('finish_parquet_lacquer', 'Лакировка паркета', 'Напольные покрытия', WorkQuantityBasis.floorArea, .7, ['finish_parquet_sanding'], optional: true, catalogOnly: true),
    WorkOperation('finish_linoleum', 'Настил линолеума', 'Напольные покрытия', WorkQuantityBasis.floorArea, .5, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('finish_carpet', 'Настил ковролина', 'Напольные покрытия', WorkQuantityBasis.floorArea, .55, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('finish_cork', 'Укладка пробкового покрытия', 'Напольные покрытия', WorkQuantityBasis.floorArea, .85, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('finish_polymer', 'Полимерное покрытие пола', 'Напольные покрытия', WorkQuantityBasis.floorArea, 1, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('finish_microcement', 'Микроцемент на полу', 'Напольные покрытия', WorkQuantityBasis.floorArea, 1.4, ['floor_base'], optional: true, catalogOnly: true),
    WorkOperation('finish_floor_expansion', 'Монтаж порожков и деформационных профилей', 'Напольные покрытия', WorkQuantityBasis.skirting, .48, ['floor_laminate'], optional: true, catalogOnly: true),
    WorkOperation('finish_skirting_mdf', 'Монтаж МДФ-плинтуса', 'Напольные покрытия', WorkQuantityBasis.skirting, .43, ['floor_laminate'], optional: true, catalogOnly: true),
    WorkOperation('finish_skirting_hidden', 'Монтаж скрытого плинтуса', 'Напольные покрытия', WorkQuantityBasis.skirting, .9, ['floor_base'], optional: true, catalogOnly: true),
    // Двери и окна
    WorkOperation('joinery_door_frame', 'Установка дверной коробки', 'Двери и окна', WorkQuantityBasis.package, 2.4, ['doors'], optional: true, catalogOnly: true),
    WorkOperation('joinery_door_leaf', 'Навеска дверного полотна', 'Двери и окна', WorkQuantityBasis.package, 1.6, ['joinery_door_frame'], optional: true, catalogOnly: true),
    WorkOperation('joinery_door_hardware', 'Установка замков и петель', 'Двери и окна', WorkQuantityBasis.package, 1.2, ['joinery_door_leaf'], optional: true, catalogOnly: true),
    WorkOperation('joinery_door_casing', 'Монтаж наличников', 'Двери и окна', WorkQuantityBasis.package, 1.25, ['joinery_door_frame'], optional: true, catalogOnly: true),
    WorkOperation('joinery_sliding_door', 'Монтаж раздвижной двери', 'Двери и окна', WorkQuantityBasis.package, 5.5, ['floor_laminate'], optional: true, catalogOnly: true),
    WorkOperation('joinery_hidden_door', 'Монтаж скрытой двери', 'Двери и окна', WorkQuantityBasis.package, 6, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('joinery_door_stop', 'Монтаж дверного ограничителя', 'Двери и окна', WorkQuantityBasis.package, .4, ['joinery_door_leaf'], optional: true, catalogOnly: true),
    WorkOperation('joinery_window_sill', 'Монтаж подоконника', 'Двери и окна', WorkQuantityBasis.skirting, 1, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('joinery_window_slope', 'Устройство оконных откосов', 'Двери и окна', WorkQuantityBasis.wallArea, 1.25, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('joinery_window_trim', 'Монтаж оконных откосных профилей', 'Двери и окна', WorkQuantityBasis.skirting, .6, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('joinery_window_fittings', 'Регулировка оконной фурнитуры', 'Двери и окна', WorkQuantityBasis.package, 1.5, ['survey'], optional: true, catalogOnly: true),
    WorkOperation('joinery_window_reseal', 'Герметизация оконных примыканий', 'Двери и окна', WorkQuantityBasis.skirting, .48, ['survey'], optional: true, catalogOnly: true),
    WorkOperation('joinery_balcony_door', 'Установка балконного дверного блока', 'Двери и окна', WorkQuantityBasis.package, 5, ['survey'], optional: true, catalogOnly: true),
    WorkOperation('joinery_glass_partition', 'Монтаж стеклянной перегородки', 'Двери и окна', WorkQuantityBasis.wallArea, 2.2, ['floor_base'], optional: true, catalogOnly: true),
    // Оборудование и финиш
    WorkOperation('finish_kitchen_modules', 'Монтаж кухонных модулей', 'Оборудование и финиш', WorkQuantityBasis.package, 10, ['floor_laminate'], optional: true, catalogOnly: true),
    WorkOperation('finish_countertop', 'Монтаж столешницы', 'Оборудование и финиш', WorkQuantityBasis.skirting, 1, ['finish_kitchen_modules'], optional: true, catalogOnly: true),
    WorkOperation('finish_backsplash', 'Монтаж кухонного фартука', 'Оборудование и финиш', WorkQuantityBasis.wallArea, 1.3, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('finish_wardrobe', 'Сборка встроенного шкафа', 'Оборудование и финиш', WorkQuantityBasis.package, 9, ['floor_laminate'], optional: true, catalogOnly: true),
    WorkOperation('finish_cabinets', 'Навеска шкафов и тумб', 'Оборудование и финиш', WorkQuantityBasis.package, 3, ['wall_paint'], optional: true, catalogOnly: true),
    WorkOperation('finish_mirror', 'Монтаж зеркал', 'Оборудование и финиш', WorkQuantityBasis.package, 1.5, ['wall_paint'], optional: true, catalogOnly: true),
    WorkOperation('finish_accessories', 'Монтаж аксессуаров и держателей', 'Оборудование и финиш', WorkQuantityBasis.package, 2, ['wall_tile'], optional: true, catalogOnly: true),
    WorkOperation('finish_blinds', 'Монтаж жалюзи и рулонных штор', 'Оборудование и финиш', WorkQuantityBasis.package, 2, ['wall_paint'], optional: true, catalogOnly: true),
    WorkOperation('finish_curtain_rail', 'Монтаж карниза для штор', 'Оборудование и финиш', WorkQuantityBasis.skirting, .5, ['wall_paint'], optional: true, catalogOnly: true),
    WorkOperation('finish_appliance_oven', 'Встройка духового шкафа', 'Оборудование и финиш', WorkQuantityBasis.package, 2.5, ['finish_kitchen_modules'], optional: true, catalogOnly: true),
    WorkOperation('finish_appliance_hob', 'Врезка и монтаж варочной панели', 'Оборудование и финиш', WorkQuantityBasis.package, 2.5, ['finish_countertop'], optional: true, catalogOnly: true),
    WorkOperation('finish_extract', 'Монтаж кухонной вытяжки', 'Оборудование и финиш', WorkQuantityBasis.package, 3, ['finish_kitchen_modules'], optional: true, catalogOnly: true),
    // Контроль и сдача
    WorkOperation('qc_geometry', 'Контроль размеров и геометрии', 'Контроль и сдача', WorkQuantityBasis.package, 2, ['survey'], optional: true, catalogOnly: true),
    WorkOperation('qc_plaster', 'Приёмка штукатурки', 'Контроль и сдача', WorkQuantityBasis.wallArea, .12, ['wall_plaster'], optional: true, catalogOnly: true),
    WorkOperation('qc_screed', 'Контроль стяжки и влажности', 'Контроль и сдача', WorkQuantityBasis.floorArea, .12, ['screed'], optional: true, catalogOnly: true),
    WorkOperation('qc_waterproof', 'Контроль сплошности гидроизоляции', 'Контроль и сдача', WorkQuantityBasis.floorArea, .14, ['floor_waterproof'], optional: true, catalogOnly: true),
    WorkOperation('qc_wiring', 'Проверка скрытых электрических трасс', 'Контроль и сдача', WorkQuantityBasis.package, 3, ['electrical_rough'], optional: true, catalogOnly: true),
    WorkOperation('qc_plumbing', 'Контроль скрытых сантехнических линий', 'Контроль и сдача', WorkQuantityBasis.package, 3, ['plumbing_rough'], optional: true, catalogOnly: true),
    WorkOperation('qc_tiles', 'Контроль качества плиточных работ', 'Контроль и сдача', WorkQuantityBasis.floorArea, .14, ['floor_tile'], optional: true, catalogOnly: true),
    WorkOperation('qc_finish', 'Приёмка чистовой отделки', 'Контроль и сдача', WorkQuantityBasis.package, 3, ['cleaning'], optional: true, catalogOnly: true),
    WorkOperation('qc_defects', 'Устранение замечаний по приёмке', 'Контроль и сдача', WorkQuantityBasis.package, 5, ['qc_finish'], optional: true, catalogOnly: true),
    WorkOperation('qc_final_photos', 'Фотофиксация завершённых работ', 'Контроль и сдача', WorkQuantityBasis.package, 2, ['cleaning'], optional: true, catalogOnly: true),
    WorkOperation('qc_asbuilt', 'Подготовка исполнительных схем', 'Контроль и сдача', WorkQuantityBasis.package, 6, ['cleaning'], optional: true, catalogOnly: true),
    WorkOperation('qc_handover', 'Передача исполнительной документации', 'Контроль и сдача', WorkQuantityBasis.package, 2, ['acceptance'], optional: true, catalogOnly: true),
  ];
  static final byCode = {for (final op in all) op.code: op};
}

class WorkGenerationPlan {
  const WorkGenerationPlan(this.tasks, this.skippedExisting,
      this.skippedRooms, this.roomsProcessed);
  final List<WorkTask> tasks;
  final int skippedExisting, skippedRooms, roomsProcessed;
  int get reviewCount => tasks.where((t) => t.needsQuantityReview).length;
  double get totalEstimatedHours =>
      tasks.fold<double>(0, (sum, task) => sum + task.hours);
}

class WorkGenerationService {
  /// Preview does not write to the project, geometry or timeline.
  /// Optional work has deliberately unverified scope; the user must
  /// confirm its quantity before reporting progress.
  static WorkGenerationPlan preview(MeasureProject project, {
    DateTime? begin,
    bool includeOptional = false,
    Set<String>? roomIds,
  }) {
    final board = project.workBoard;
    final existing = <String, WorkTask>{
      for (final task in board.tasks)
        if (task.generatedKey != null) task.generatedKey!: task,
    };
    final drafts = <WorkTask>[];
    var duplicates = 0, roomsSkipped = 0, roomsProcessed = 0;
    final started = board.calendar.nextWorkday(begin ?? DateTime.now());
    for (final floor in project.floors) {
      for (final face in GeometryService.roomFaces(floor)) {
        final room = floor.roomMetaByKey(face.key);
        if (room == null || room.id.isEmpty ||
            face.areaM2 <= 0 || !face.areaM2.isFinite) {
          roomsSkipped++;
          continue;
        }
        if (roomIds != null && !roomIds.contains(room.id)) continue;
        roomsProcessed++;
        final s = room.materials;
        final tileFloor = s.floorMode == 'tile' || s.floorTile;
        final assignedWalls = WorkSurfaceService.hasAssignments(
          board, floor, room);
        final paintArea = WorkSurfaceService.areaForCode(
          board, floor, face, 'wall_paint');
        final tileArea = WorkSurfaceService.areaForCode(
          board, floor, face, 'wall_tile');
        final needsPaint = assignedWalls ? paintArea > .0001 : s.wallPaint;
        final needsTile = assignedWalls ? tileArea > .0001 : s.wallTile;
        final desired = <String>{
          'survey', 'protection', 'floor_base', 'ceiling_base',
          'cleaning', 'acceptance',
          if (s.wallPlaster || s.wallPutty || needsPaint || needsTile)
            'wall_primer',
          if (s.wallPlaster || s.wallPutty || needsPaint || needsTile)
            'wall_plaster',
          if (needsPaint && (s.wallPutty || s.wallPaint || assignedWalls))
            'wall_putty',
          if (needsPaint) 'wall_prime_finish',
          if (needsPaint) 'wall_paint',
          if (needsTile) 'wall_tile',
          if (room.heating.enabled) 'warm_floor',
          if (tileFloor) 'floor_tile',
          if (!tileFloor) 'floor_underlay',
          if (!tileFloor) 'floor_laminate',
          if (room.ceiling.finish == 'drywall') 'ceiling_gkl',
          if (room.ceiling.finish == 'stretch') 'ceiling_stretch',
          if (room.ceiling.finish != 'stretch' &&
              room.ceiling.finish != 'drywall') 'ceiling_prime',
          if (room.ceiling.finish != 'stretch' &&
              room.ceiling.finish != 'drywall') 'ceiling_paint',
          'skirting',
        };
        if (includeOptional) {
          desired.addAll(WorkOperationCatalog.all
              .where((op) => op.optional && !op.catalogOnly && !{
                'wall_wallpaper', // alternate finish to the modeled paint
                'warm_floor', // only if enabled in room specification
                'ceiling_gkl', 'ceiling_stretch',
              }.contains(op.code))
              .where((op) =>
                  (op.code != 'wall_waterproof' || needsTile) &&
                  (op.code != 'floor_waterproof' || tileFloor || room.heating.enabled))
              .map((op) => op.code));
          // Keep one floor finish and one ceiling finish, as configured.
        }

        final inRoom = <String, WorkTask>{};
        for (final op in WorkOperationCatalog.all) {
          if (!desired.contains(op.code)) continue;
          final key = 'generated:${floor.id}:${room.id}:${op.code}';
          if (existing[key] case final WorkTask saved) {
            inRoom[op.code] = saved;
            duplicates++;
            continue;
          }
          final area = face.areaM2;
          final quantity = op.code == 'warm_floor'
              ? EngineeringService.warmFloor(face, room.heating).areaM2
              : WorkSurfaceService.finishCodes.contains(op.code)
                  ? WorkSurfaceService.areaForCode(
                      board, floor, face, op.code)
                  : switch (op.basis) {
            WorkQuantityBasis.floorArea => area,
            WorkQuantityBasis.wallArea =>
              GeometryService.roomNetWallAreaM2(floor, face),
            WorkQuantityBasis.ceilingArea => area,
            WorkQuantityBasis.skirting =>
              GeometryService.roomSkirtingM(floor, face),
            WorkQuantityBasis.package => 1.0,
          };
          if (!quantity.isFinite || quantity <= 0) continue;
          final prior = <WorkTask>[
            for (final code in op.requiredCodes)
              if (inRoom[code] != null) inRoom[code]!,
          ];
          if (op.code == 'cleaning') {
            prior.addAll(inRoom.entries
                .where((entry) => entry.key != 'survey' &&
                    entry.key != 'protection' &&
                    entry.key != 'cleaning' &&
                    entry.key != 'acceptance')
                .map((entry) => entry.value));
          }
          final predecessors = {for (final task in prior) task.id}.toList();
          final latest = prior.isEmpty ? null : prior.reduce(
            (a, b) => a.finish.isAfter(b.finish) ? a : b,
          );
          final taskStart = latest == null
              ? started
              : board.calendar.firstDayAfter(latest.finish, 0);
          final hours = math.max(1.0, quantity * op.hoursPerUnit);
          final days = math.max(1, (hours / 8).ceil());
          final taskFinish = board.calendar.finishForDuration(taskStart, days);
          final task = WorkTask(
            id: key, generatedKey: key, operationCode: op.code,
            title: op.title, category: op.phase,
            floorId: floor.id, roomId: room.id, roomName: room.name,
            start: taskStart, finish: taskFinish,
            quantity: double.parse(quantity.toStringAsFixed(2)),
            hours: double.parse(hours.toStringAsFixed(1)),
            unit: switch (op.basis) {
              WorkQuantityBasis.package => 'компл.',
              WorkQuantityBasis.skirting => 'м',
              _ => 'м²',
            },
            requiredPredecessorIds: predecessors,
            predecessorId: latest?.id,
            surfaceWallIds: WorkSurfaceService.finishCodes.contains(op.code)
              ? WorkSurfaceService.wallIdsForCode(board, floor, face, op.code)
              : null,
            needsQuantityReview: includeOptional && op.optional,
          );
          inRoom[op.code] = task;
          drafts.add(task);
        }
        // Parallel engineering rough-in shares one acceptance barrier for
        // subsequent finishes. Peers do not block each other's start.
        const roughGroup = <String>[
          'electrical_rough', 'plumbing_rough', 'ventilation',
        ];
        for (final code in roughGroup) {
          final work = inRoom[code];
          if (work == null || !drafts.contains(work)) continue;
          for (final peerCode in roughGroup) {
            final peer = inRoom[peerCode];
            if (peer != null && peer.id != work.id &&
                !work.coStageTaskIds.contains(peer.id)) {
              work.coStageTaskIds.add(peer.id);
            }
          }
        }
      }
    }
    return WorkGenerationPlan(
      List.unmodifiable(drafts), duplicates, roomsSkipped, roomsProcessed);
  }

  /// Checks the entire proposed batch before committing anything.
  static String? apply(WorkBoard board, WorkGenerationPlan plan) {
    final ids = board.tasks.map((t) => t.id).toSet();
    final keys = board.tasks.map((t) => t.generatedKey).toSet();
    final incomingIds = <String>{};
    for (final task in plan.tasks) {
      if (!incomingIds.add(task.id) || ids.contains(task.id) ||
          keys.contains(task.generatedKey)) {
        return 'График изменился. Выполните предварительный расчёт заново.';
      }
    }
    board.tasks.addAll(plan.tasks);
    if (plan.tasks.isNotEmpty) {
      board.log('Автоматически создано задач: ${plan.tasks.length}. '
        'Помещений: ${plan.roomsProcessed}.');
    }
    return null;
  }
}
