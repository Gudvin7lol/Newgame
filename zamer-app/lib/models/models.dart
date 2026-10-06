import 'dart:math' as math;

class MeasureProject {
  MeasureProject({
    required this.id,
    required this.name,
    this.address = '',
    this.client = '',
    this.phone = '',
    DateTime? createdAt,
    List<FloorPlan>? floors,
    List<ProjectRevision>? revisions,
    Map<String, double>? unitPrices,
    Map<String, double>? workRates,
  }) : createdAt = createdAt ?? DateTime.now(),
       floors = floors ?? [],
       revisions = revisions ?? [],
       unitPrices = unitPrices ?? {},
       workRates = workRates ?? {};

  final String id;
  String name;
  String address;
  String client;
  String phone;
  DateTime createdAt;
  final List<FloorPlan> floors;
  final List<ProjectRevision> revisions;
  final Map<String, double> unitPrices;
  final Map<String, double> workRates;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'client': client,
    'phone': phone,
    'createdAt': createdAt.toIso8601String(),
    'floors': floors.map((e) => e.toJson()).toList(),
    'revisions': revisions.map((e) => e.toJson()).toList(),
    'unitPrices': unitPrices,
    'workRates': workRates,
  };

  factory MeasureProject.fromJson(Map<String, dynamic> json) => MeasureProject(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Без названия',
    address: json['address'] as String? ?? '',
    client: json['client'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    floors: ((json['floors'] as List?) ?? const [])
        .map((e) => FloorPlan.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    revisions: ((json['revisions'] as List?) ?? const [])
        .map(
          (e) => ProjectRevision.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    unitPrices: ((json['unitPrices'] as Map?) ?? const {}).map(
      (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
    ),
    workRates: ((json['workRates'] as Map?) ?? const {}).map(
      (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
    ),
  );
}

class ProjectRevision {
  ProjectRevision({
    required this.label,
    required this.createdAt,
    required this.floors,
    Map<String, double>? unitPrices,
    Map<String, double>? workRates,
  }) : unitPrices = unitPrices ?? {},
       workRates = workRates ?? {};

  final String label;
  final DateTime createdAt;
  // A version contains only floors, preventing recursive copies of history.
  final List<FloorPlan> floors;
  final Map<String, double> unitPrices;
  final Map<String, double> workRates;

  Map<String, dynamic> toJson() => {
    'label': label,
    'createdAt': createdAt.toIso8601String(),
    'floors': floors.map((e) => e.toJson()).toList(),
    'unitPrices': unitPrices,
    'workRates': workRates,
  };

  factory ProjectRevision.fromJson(Map<String, dynamic> json) =>
      ProjectRevision(
        label: json['label'] as String? ?? 'Версия',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        floors: ((json['floors'] as List?) ?? const [])
            .map((e) => FloorPlan.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        unitPrices: ((json['unitPrices'] as Map?) ?? const {}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ),
        workRates: ((json['workRates'] as Map?) ?? const {}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ),
      );
}

class FloorPlan {
  FloorPlan({
    required this.id,
    required this.name,
    this.defaultHeightMm = 2700,
    this.notes = '',
    List<PlanNode>? nodes,
    List<PlanWall>? walls,
    List<ControlMeasure>? measures,
    List<RoomMeta>? roomMetas,
    List<ElectricalPoint>? electricalPoints,
    List<ElectricalRun>? electricalRuns,
    List<ServiceRun>? serviceRuns,
    List<PlanObject>? planObjects,
    Map<String, DimensionRecord>? dimensionRecords,
    List<String>? carpetRoomIds,
    this.carpetAnchorX = 0,
    this.carpetAnchorY = 0,
    this.defaultSocketHeightMm = 300,
    this.defaultSwitchHeightMm = 900,
    this.defaultWallLightHeightMm = 1800,
  }) : nodes = nodes ?? [],
       walls = walls ?? [],
       measures = measures ?? [],
       roomMetas = roomMetas ?? [],
       electricalPoints = electricalPoints ?? [],
       electricalRuns = electricalRuns ?? [],
       serviceRuns = serviceRuns ?? [],
       planObjects = planObjects ?? [],
       dimensionRecords = dimensionRecords ?? {},
       carpetRoomIds = carpetRoomIds ?? [];

  final String id;
  String name;
  double defaultHeightMm;
  String notes;
  final List<PlanNode> nodes;
  final List<PlanWall> walls;
  final List<ControlMeasure> measures;
  final List<RoomMeta> roomMetas;
  final List<ElectricalPoint> electricalPoints;
  final List<ElectricalRun> electricalRuns;
  final List<ServiceRun> serviceRuns;
  final List<PlanObject> planObjects;
  final Map<String, DimensionRecord> dimensionRecords;
  final List<String> carpetRoomIds;
  double carpetAnchorX, carpetAnchorY;
  double defaultSocketHeightMm;
  double defaultSwitchHeightMm;
  double defaultWallLightHeightMm;

  PlanNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  PlanWall? wallById(String id) {
    for (final wall in walls) {
      if (wall.id == id) return wall;
    }
    return null;
  }

  RoomMeta? roomMetaByKey(String key) {
    for (final meta in roomMetas) {
      if (meta.faceKey == key) return meta;
    }
    return null;
  }

  double wallLengthMm(PlanWall wall) {
    final a = nodeById(wall.startNodeId);
    final b = nodeById(wall.endNodeId);
    if (a == null || b == null) return 0;
    return math.sqrt(math.pow(b.xMm - a.xMm, 2) + math.pow(b.yMm - a.yMm, 2));
  }

  int nodeDegree(String nodeId) {
    var d = 0;
    for (final w in walls) {
      if (w.startNodeId == nodeId || w.endNodeId == nodeId) d++;
    }
    return d;
  }

  void restoreFrom(FloorPlan other) {
    name = other.name;
    defaultHeightMm = other.defaultHeightMm;
    notes = other.notes;
    nodes
      ..clear()
      ..addAll(other.nodes.map((e) => PlanNode.fromJson(e.toJson())));
    walls
      ..clear()
      ..addAll(other.walls.map((e) => PlanWall.fromJson(e.toJson())));
    measures
      ..clear()
      ..addAll(other.measures.map((e) => ControlMeasure.fromJson(e.toJson())));
    roomMetas
      ..clear()
      ..addAll(other.roomMetas.map((e) => RoomMeta.fromJson(e.toJson())));
    electricalPoints
      ..clear()
      ..addAll(
        other.electricalPoints.map((e) => ElectricalPoint.fromJson(e.toJson())),
      );
    electricalRuns
      ..clear()
      ..addAll(
        other.electricalRuns.map((e) => ElectricalRun.fromJson(e.toJson())),
      );
    serviceRuns
      ..clear()
      ..addAll(other.serviceRuns.map((e) => ServiceRun.fromJson(e.toJson())));
    planObjects
      ..clear()
      ..addAll(other.planObjects.map((e) => PlanObject.fromJson(e.toJson())));
    dimensionRecords
      ..clear()
      ..addAll(
        other.dimensionRecords.map(
          (key, value) =>
              MapEntry(key, DimensionRecord.fromJson(value.toJson())),
        ),
      );
    carpetRoomIds
      ..clear()
      ..addAll(other.carpetRoomIds);
    carpetAnchorX = other.carpetAnchorX;
    carpetAnchorY = other.carpetAnchorY;
    defaultSocketHeightMm = other.defaultSocketHeightMm;
    defaultSwitchHeightMm = other.defaultSwitchHeightMm;
    defaultWallLightHeightMm = other.defaultWallLightHeightMm;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'defaultHeightMm': defaultHeightMm,
    'notes': notes,
    'nodes': nodes.map((e) => e.toJson()).toList(),
    'walls': walls.map((e) => e.toJson()).toList(),
    'measures': measures.map((e) => e.toJson()).toList(),
    'roomMetas': roomMetas.map((e) => e.toJson()).toList(),
    'electricalPoints': electricalPoints.map((e) => e.toJson()).toList(),
    'electricalRuns': electricalRuns.map((e) => e.toJson()).toList(),
    'serviceRuns': serviceRuns.map((e) => e.toJson()).toList(),
    'planObjects': planObjects.map((e) => e.toJson()).toList(),
    'dimensionRecords': dimensionRecords.map((k, v) => MapEntry(k, v.toJson())),
    'carpetRoomIds': carpetRoomIds.toList(),
    'carpetAnchorX': carpetAnchorX,
    'carpetAnchorY': carpetAnchorY,
    'defaultSocketHeightMm': defaultSocketHeightMm,
    'defaultSwitchHeightMm': defaultSwitchHeightMm,
    'defaultWallLightHeightMm': defaultWallLightHeightMm,
  };

  factory FloorPlan.fromJson(Map<String, dynamic> json) => FloorPlan(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Этаж',
    defaultHeightMm: (json['defaultHeightMm'] as num?)?.toDouble() ?? 2700,
    notes: json['notes'] as String? ?? '',
    nodes: ((json['nodes'] as List?) ?? const [])
        .map((e) => PlanNode.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    walls: ((json['walls'] as List?) ?? const [])
        .map((e) => PlanWall.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    measures: ((json['measures'] as List?) ?? const [])
        .map(
          (e) => ControlMeasure.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    roomMetas: ((json['roomMetas'] as List?) ?? const [])
        .map((e) => RoomMeta.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    electricalPoints: ((json['electricalPoints'] as List?) ?? const [])
        .map(
          (e) => ElectricalPoint.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    electricalRuns: ((json['electricalRuns'] as List?) ?? const [])
        .map((e) => ElectricalRun.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    serviceRuns: ((json['serviceRuns'] as List?) ?? const [])
        .map((e) => ServiceRun.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    planObjects: ((json['planObjects'] as List?) ?? const [])
        .map((e) => PlanObject.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    dimensionRecords: ((json['dimensionRecords'] as Map?) ?? const {}).map(
      (key, value) => MapEntry(
        key.toString(),
        DimensionRecord.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    ),
    carpetRoomIds: ((json['carpetRoomIds'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    carpetAnchorX: (json['carpetAnchorX'] as num?)?.toDouble() ?? 0,
    carpetAnchorY: (json['carpetAnchorY'] as num?)?.toDouble() ?? 0,
    defaultSocketHeightMm:
        (json['defaultSocketHeightMm'] as num?)?.toDouble() ?? 300,
    defaultSwitchHeightMm:
        (json['defaultSwitchHeightMm'] as num?)?.toDouble() ?? 900,
    defaultWallLightHeightMm:
        (json['defaultWallLightHeightMm'] as num?)?.toDouble() ?? 1800,
  );
}

class PlanNode {
  PlanNode({required this.id, required this.xMm, required this.yMm});
  final String id;
  double xMm;
  double yMm;

  Map<String, dynamic> toJson() => {'id': id, 'xMm': xMm, 'yMm': yMm};

  factory PlanNode.fromJson(Map<String, dynamic> json) => PlanNode(
    id: json['id'] as String,
    xMm: (json['xMm'] as num).toDouble(),
    yMm: (json['yMm'] as num).toDouble(),
  );
}

enum ProjectLayer { existing, demolition, proposed }

extension ProjectLayerLabel on ProjectLayer {
  String get label => switch (this) {
    ProjectLayer.existing => 'Существующее',
    ProjectLayer.demolition => 'Демонтаж',
    ProjectLayer.proposed => 'Новая планировка',
  };
}

enum WallType { exterior, partition }

enum WallMaterial { concrete, brick, gasBlock, drywall, wood, other }

enum OpeningType { window, door }

enum DoorSwing { leftIn, rightIn, leftOut, rightOut }

extension WallTypeLabel on WallType {
  String get label => this == WallType.exterior ? 'Наружная' : 'Перегородка';
}

extension WallMaterialLabel on WallMaterial {
  String get label => switch (this) {
    WallMaterial.concrete => 'Бетон',
    WallMaterial.brick => 'Кирпич',
    WallMaterial.gasBlock => 'Газоблок',
    WallMaterial.drywall => 'ГКЛ',
    WallMaterial.wood => 'Дерево',
    WallMaterial.other => 'Другое',
  };
}

class PlanWall {
  PlanWall({
    required this.id,
    required this.startNodeId,
    required this.endNodeId,
    this.type = WallType.partition,
    this.thicknessMm = 100,
    this.material = WallMaterial.other,
    this.heightOverrideMm,
    this.note = '',
    this.demolition = false,
    this.projectLayer = ProjectLayer.existing,
    this.curveGroupId,
    this.curveRadiusMm,
    this.curveSagittaMm,
    this.curveArcLengthMm,
    List<WallOpening>? openings,
  }) : openings = openings ?? [];

  final String id;
  String startNodeId;
  String endNodeId;
  WallType type;
  double thicknessMm;
  WallMaterial material;
  double? heightOverrideMm;
  String note;
  bool demolition;
  ProjectLayer projectLayer;
  String? curveGroupId;
  double? curveRadiusMm;
  double? curveSagittaMm;
  double? curveArcLengthMm;
  final List<WallOpening> openings;

  bool get isCurved => curveGroupId != null && curveGroupId!.isNotEmpty;

  PlanWall copyWith({String? id, String? startNodeId, String? endNodeId}) =>
      PlanWall(
        id: id ?? this.id,
        startNodeId: startNodeId ?? this.startNodeId,
        endNodeId: endNodeId ?? this.endNodeId,
        type: type,
        thicknessMm: thicknessMm,
        material: material,
        heightOverrideMm: heightOverrideMm,
        note: note,
        demolition: demolition,
        projectLayer: projectLayer,
        curveGroupId: curveGroupId,
        curveRadiusMm: curveRadiusMm,
        curveSagittaMm: curveSagittaMm,
        curveArcLengthMm: curveArcLengthMm,
        openings: openings
            .map((e) => WallOpening.fromJson(e.toJson()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'startNodeId': startNodeId,
    'endNodeId': endNodeId,
    'type': type.name,
    'thicknessMm': thicknessMm,
    'material': material.name,
    'heightOverrideMm': heightOverrideMm,
    'note': note,
    'demolition': demolition,
    'projectLayer': projectLayer.name,
    'curveGroupId': curveGroupId,
    'curveRadiusMm': curveRadiusMm,
    'curveSagittaMm': curveSagittaMm,
    'curveArcLengthMm': curveArcLengthMm,
    'openings': openings.map((e) => e.toJson()).toList(),
  };

  factory PlanWall.fromJson(Map<String, dynamic> json) => PlanWall(
    id: json['id'] as String,
    startNodeId: json['startNodeId'] as String,
    endNodeId: json['endNodeId'] as String,
    type: WallType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => WallType.partition,
    ),
    thicknessMm: (json['thicknessMm'] as num?)?.toDouble() ?? 100,
    material: WallMaterial.values.firstWhere(
      (e) => e.name == json['material'],
      orElse: () => WallMaterial.other,
    ),
    heightOverrideMm: (json['heightOverrideMm'] as num?)?.toDouble(),
    note: json['note'] as String? ?? '',
    demolition: json['demolition'] as bool? ?? false,
    projectLayer: ProjectLayer.values.firstWhere(
      (e) => e.name == json['projectLayer'],
      orElse: () => (json['demolition'] as bool? ?? false)
          ? ProjectLayer.demolition
          : ProjectLayer.existing,
    ),
    curveGroupId: json['curveGroupId'] as String?,
    curveRadiusMm: (json['curveRadiusMm'] as num?)?.toDouble(),
    curveSagittaMm: (json['curveSagittaMm'] as num?)?.toDouble(),
    curveArcLengthMm: (json['curveArcLengthMm'] as num?)?.toDouble(),
    openings: ((json['openings'] as List?) ?? const [])
        .map((e) => WallOpening.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

class WallOpening {
  WallOpening({
    required this.id,
    required this.type,
    required this.widthMm,
    required this.heightMm,
    required this.offsetFromStartMm,
    this.sillHeightMm = 0,
    this.doorSwing = DoorSwing.leftIn,
  });

  final String id;
  OpeningType type;
  double widthMm;
  double heightMm;
  double offsetFromStartMm;
  double sillHeightMm;
  DoorSwing doorSwing;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'widthMm': widthMm,
    'heightMm': heightMm,
    'offsetFromStartMm': offsetFromStartMm,
    'sillHeightMm': sillHeightMm,
    'doorSwing': doorSwing.name,
  };

  factory WallOpening.fromJson(Map<String, dynamic> json) => WallOpening(
    id: json['id'] as String,
    type: OpeningType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => OpeningType.door,
    ),
    widthMm: (json['widthMm'] as num).toDouble(),
    heightMm: (json['heightMm'] as num).toDouble(),
    offsetFromStartMm: (json['offsetFromStartMm'] as num).toDouble(),
    sillHeightMm: (json['sillHeightMm'] as num?)?.toDouble() ?? 0,
    doorSwing: DoorSwing.values.firstWhere(
      (e) => e.name == json['doorSwing'],
      orElse: () => DoorSwing.leftIn,
    ),
  );
}

enum DimensionSource { manual, rangefinder, bti, calculated }

extension DimensionSourceLabel on DimensionSource {
  String get label => switch (this) {
    DimensionSource.manual => 'Вручную',
    DimensionSource.rangefinder => 'Дальномер',
    DimensionSource.bti => 'План БТИ',
    DimensionSource.calculated => 'Расчёт',
  };
}

class DimensionChange {
  DimensionChange(this.valueMm, this.source, this.author, this.at);
  final double valueMm;
  final DimensionSource source;
  final String author;
  final DateTime at;
  Map<String, dynamic> toJson() => {
    'valueMm': valueMm,
    'source': source.name,
    'author': author,
    'at': at.toUtc().toIso8601String(),
  };
  factory DimensionChange.fromJson(Map<String, dynamic> json) =>
      DimensionChange(
        (json['valueMm'] as num).toDouble(),
        DimensionSource.values.firstWhere(
          (e) => e.name == json['source'],
          orElse: () => DimensionSource.manual,
        ),
        json['author'] as String? ?? '',
        DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      );
}

class DimensionRecord {
  DimensionRecord({
    required this.valueMm,
    required this.source,
    required this.author,
    required this.recordedAt,
    List<DimensionChange>? history,
  }) : history = history ?? [];
  double valueMm;
  DimensionSource source;
  String author;
  DateTime recordedAt;
  final List<DimensionChange> history;

  void revise(double value, DimensionSource origin, String by) {
    history.add(DimensionChange(valueMm, source, author, recordedAt));
    valueMm = value;
    source = origin;
    author = by;
    recordedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'valueMm': valueMm,
    'source': source.name,
    'author': author,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'history': history.map((e) => e.toJson()).toList(),
  };
  factory DimensionRecord.fromJson(Map<String, dynamic> json) =>
      DimensionRecord(
        valueMm: (json['valueMm'] as num).toDouble(),
        source: DimensionSource.values.firstWhere(
          (e) => e.name == json['source'],
          orElse: () => DimensionSource.manual,
        ),
        author: json['author'] as String? ?? '',
        recordedAt:
            DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
            DateTime.now(),
        history: ((json['history'] as List?) ?? const [])
            .map(
              (e) =>
                  DimensionChange.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );
}

class ControlMeasure {
  ControlMeasure({
    required this.id,
    required this.startNodeId,
    required this.endNodeId,
    required this.measuredMm,
    this.label = '',
  });

  final String id;
  String startNodeId;
  String endNodeId;
  double measuredMm;
  String label;

  Map<String, dynamic> toJson() => {
    'id': id,
    'startNodeId': startNodeId,
    'endNodeId': endNodeId,
    'measuredMm': measuredMm,
    'label': label,
  };

  factory ControlMeasure.fromJson(Map<String, dynamic> json) => ControlMeasure(
    id: json['id'] as String,
    startNodeId: json['startNodeId'] as String,
    endNodeId: json['endNodeId'] as String,
    measuredMm: (json['measuredMm'] as num).toDouble(),
    label: json['label'] as String? ?? '',
  );
}

class RoomMaterialSettings {
  RoomMaterialSettings({
    this.floorMode = 'laminate',
    this.floorWastePct = 8,
    this.floorPackageM2 = 2.2,
    this.underlayRollM2 = 10,
    this.wallPlaster = true,
    this.plasterThicknessMm = 10,
    this.plasterKgM2Mm = 1.0,
    this.plasterBagKg = 25,
    this.wallPutty = true,
    this.puttyCoats = 2,
    this.puttyKgM2Coat = 0.8,
    this.puttyBagKg = 20,
    this.wallPaint = true,
    this.paintCoats = 2,
    this.paintCoverageM2L = 10,
    this.paintCanL = 9,
    this.wallTile = false,
    this.wallTileWastePct = 10,
    this.wallTileBoxM2 = 1.44,
    this.floorTile = false,
    this.floorTileWastePct = 10,
    this.floorTileBoxM2 = 1.44,
    this.tileGlueKgM2 = 4,
    this.tileGlueBagKg = 25,
    this.laminatePlankLengthMm = 1380,
    this.laminatePlankWidthMm = 193,
    this.laminateOffsetMode = 'half',
    this.laminatePattern = 'straight',
    this.laminateOffsetXMm = 0,
    this.laminateOffsetYMm = 0,
    this.floorDirectionDeg = 0,
    this.underlayMode = 'roll',
    this.underlayRollWidthMm = 1000,
    this.underlaySheetWidthMm = 500,
    this.underlaySheetHeightMm = 1000,
    this.underlayOffsetXMm = 0,
    this.underlayOffsetYMm = 0,
    this.tileWidthMm = 600,
    this.tileHeightMm = 600,
    this.tilePattern = 'straight',
    this.tileOffsetXMm = 0,
    this.tileOffsetYMm = 0,
    this.floorTileGroutMm = 2,
    this.tileMinCutMm = 120,
    this.wallTileWidthMm = 600,
    this.wallTileHeightMm = 300,
    this.wallTilePattern = 'straight',
    this.wallTileOffsetXMm = 0,
    this.wallTileOffsetYMm = 0,
    this.wallTileFromMm = 0,
    this.wallTileToMm = 2700,
    this.floorMaterialId = 'oak-natural',
    this.floorTintArgb = 0,
    this.wallMaterialId = 'paint-warm-white',
    this.ceilingMaterialId = 'paint-warm-white',
    this.ceilingPaintColorArgb = 0,
    this.wallTileMaterialId = 'tile-light-stone',
    this.wallPaintColorArgb = 0,
    this.wallTileTintArgb = 0xFFFFFFFF,
    this.wallTileGroutMm = 1.5,
    Map<String, double>? wallTileRunOffsetX,
    Map<String, double>? wallTileRunOffsetY,
    Map<String, bool>? wallTileRunEnabled,
    Map<String, bool>? wallTileRunMirrored,
    Map<String, bool>? wallTileRunRotated,
  }) : wallTileRunOffsetX = wallTileRunOffsetX ?? {},
       wallTileRunOffsetY = wallTileRunOffsetY ?? {},
       wallTileRunEnabled = wallTileRunEnabled ?? {},
       wallTileRunMirrored = wallTileRunMirrored ?? {},
       wallTileRunRotated = wallTileRunRotated ?? {};

  String floorMode;
  double floorWastePct;
  double floorPackageM2;
  double underlayRollM2;
  bool wallPlaster;
  double plasterThicknessMm;
  double plasterKgM2Mm;
  double plasterBagKg;
  bool wallPutty;
  int puttyCoats;
  double puttyKgM2Coat;
  double puttyBagKg;
  bool wallPaint;
  int paintCoats;
  double paintCoverageM2L;
  double paintCanL;
  bool wallTile;
  double wallTileWastePct;
  double wallTileBoxM2;
  bool floorTile;
  double floorTileWastePct;
  double floorTileBoxM2;
  double tileGlueKgM2;
  double tileGlueBagKg;
  double laminatePlankLengthMm;
  double laminatePlankWidthMm;
  String laminateOffsetMode;
  String laminatePattern;
  double laminateOffsetXMm;
  double laminateOffsetYMm;
  double floorDirectionDeg;
  String underlayMode;
  double underlayRollWidthMm;
  double underlaySheetWidthMm;
  double underlaySheetHeightMm;
  double underlayOffsetXMm;
  double underlayOffsetYMm;
  double tileWidthMm;
  double tileHeightMm;
  String tilePattern;
  double tileOffsetXMm;
  double tileOffsetYMm;
  double floorTileGroutMm;
  double tileMinCutMm;
  double wallTileWidthMm;
  double wallTileHeightMm;
  String wallTilePattern;
  double wallTileOffsetXMm;
  double wallTileOffsetYMm;
  double wallTileFromMm;
  double wallTileToMm;
  String floorMaterialId;
  int floorTintArgb;
  String wallMaterialId;
  String ceilingMaterialId;
  int ceilingPaintColorArgb;
  String wallTileMaterialId;
  int wallPaintColorArgb;
  int wallTileTintArgb;
  double wallTileGroutMm;
  final Map<String, double> wallTileRunOffsetX;
  final Map<String, double> wallTileRunOffsetY;
  final Map<String, bool> wallTileRunEnabled;
  final Map<String, bool> wallTileRunMirrored;
  final Map<String, bool> wallTileRunRotated;

  double wallTileXFor(String runId) =>
      wallTileRunOffsetX[runId] ?? wallTileOffsetXMm;
  double wallTileYFor(String runId) =>
      wallTileRunOffsetY[runId] ?? wallTileOffsetYMm;
  bool wallTileEnabledFor(String runId) =>
      wallTileRunEnabled[runId] ?? wallTile;
  bool wallTileMirroredFor(String runId) => wallTileRunMirrored[runId] ?? false;
  bool wallTileRotatedFor(String runId) => wallTileRunRotated[runId] ?? false;
  double wallTileWidthFor(String runId) =>
      wallTileRotatedFor(runId) ? wallTileHeightMm : wallTileWidthMm;
  double wallTileHeightFor(String runId) =>
      wallTileRotatedFor(runId) ? wallTileWidthMm : wallTileHeightMm;

  void normalizeFormats() {
    double valid(double value, double min, double fallback) =>
        value.isFinite && value >= min && value <= 10000 ? value : fallback;
    double wrap(double value, double module) =>
        value.isFinite ? ((value % module) + module) % module : 0;
    laminatePlankLengthMm = valid(laminatePlankLengthMm, 100, 1380);
    laminatePlankWidthMm = valid(laminatePlankWidthMm, 40, 193);
    tileWidthMm = valid(tileWidthMm, 20, 600);
    tileHeightMm = valid(tileHeightMm, 20, 600);
    floorTileGroutMm = valid(floorTileGroutMm, 0.5, 2);
    wallTileWidthMm = valid(wallTileWidthMm, 20, 600);
    wallTileHeightMm = valid(wallTileHeightMm, 20, 300);
    underlayRollWidthMm = valid(underlayRollWidthMm, 20, 1000);
    underlaySheetWidthMm = valid(underlaySheetWidthMm, 20, 500);
    underlaySheetHeightMm = valid(underlaySheetHeightMm, 20, 1000);
    floorDirectionDeg = wrap(floorDirectionDeg, 360);
    final herringbone = laminatePattern == 'herringbone';
    final laminateXModule = herringbone
        ? laminatePlankLengthMm / math.sqrt2
        : laminatePlankLengthMm;
    final laminateYModule = herringbone
        ? laminatePlankWidthMm * math.sqrt2
        : laminatePlankWidthMm;
    laminateOffsetXMm = wrap(laminateOffsetXMm, laminateXModule);
    laminateOffsetYMm = wrap(laminateOffsetYMm, laminateYModule);
    tileOffsetXMm = wrap(tileOffsetXMm, tileWidthMm);
    tileOffsetYMm = wrap(tileOffsetYMm, tileHeightMm);
    underlayOffsetXMm = wrap(
      underlayOffsetXMm,
      underlayMode == 'sheet' ? underlaySheetWidthMm : underlayRollWidthMm,
    );
    underlayOffsetYMm = wrap(
      underlayOffsetYMm,
      underlayMode == 'sheet' ? underlaySheetHeightMm : underlayRollWidthMm,
    );
    wallTileOffsetXMm = wrap(wallTileOffsetXMm, wallTileWidthMm);
    wallTileOffsetYMm = wrap(wallTileOffsetYMm, wallTileHeightMm);
    wallTileRunOffsetX.updateAll((_, value) => wrap(value, wallTileWidthMm));
    wallTileRunOffsetY.updateAll((_, value) => wrap(value, wallTileHeightMm));
    if (![1.0, 1.5, 2.0].contains(wallTileGroutMm)) wallTileGroutMm = 1.5;
  }

  Map<String, dynamic> toJson() => {
    'floorMode': floorMode,
    'floorWastePct': floorWastePct,
    'floorPackageM2': floorPackageM2,
    'underlayRollM2': underlayRollM2,
    'wallPlaster': wallPlaster,
    'plasterThicknessMm': plasterThicknessMm,
    'plasterKgM2Mm': plasterKgM2Mm,
    'plasterBagKg': plasterBagKg,
    'wallPutty': wallPutty,
    'puttyCoats': puttyCoats,
    'puttyKgM2Coat': puttyKgM2Coat,
    'puttyBagKg': puttyBagKg,
    'wallPaint': wallPaint,
    'paintCoats': paintCoats,
    'paintCoverageM2L': paintCoverageM2L,
    'paintCanL': paintCanL,
    'wallTile': wallTile,
    'wallTileWastePct': wallTileWastePct,
    'wallTileBoxM2': wallTileBoxM2,
    'floorTile': floorTile,
    'floorTileWastePct': floorTileWastePct,
    'floorTileBoxM2': floorTileBoxM2,
    'tileGlueKgM2': tileGlueKgM2,
    'tileGlueBagKg': tileGlueBagKg,
    'laminatePlankLengthMm': laminatePlankLengthMm,
    'laminatePlankWidthMm': laminatePlankWidthMm,
    'laminateOffsetMode': laminateOffsetMode,
    'laminatePattern': laminatePattern,
    'laminateOffsetXMm': laminateOffsetXMm,
    'laminateOffsetYMm': laminateOffsetYMm,
    'floorDirectionDeg': floorDirectionDeg,
    'underlayMode': underlayMode,
    'underlayRollWidthMm': underlayRollWidthMm,
    'underlaySheetWidthMm': underlaySheetWidthMm,
    'underlaySheetHeightMm': underlaySheetHeightMm,
    'underlayOffsetXMm': underlayOffsetXMm,
    'underlayOffsetYMm': underlayOffsetYMm,
    'tileWidthMm': tileWidthMm,
    'tileHeightMm': tileHeightMm,
    'tilePattern': tilePattern,
    'tileOffsetXMm': tileOffsetXMm,
    'tileOffsetYMm': tileOffsetYMm,
    'floorTileGroutMm': floorTileGroutMm,
    'tileMinCutMm': tileMinCutMm,
    'wallTileWidthMm': wallTileWidthMm,
    'wallTileHeightMm': wallTileHeightMm,
    'wallTilePattern': wallTilePattern,
    'wallTileOffsetXMm': wallTileOffsetXMm,
    'wallTileOffsetYMm': wallTileOffsetYMm,
    'wallTileFromMm': wallTileFromMm,
    'wallTileToMm': wallTileToMm,
    'floorMaterialId': floorMaterialId,
    'floorTintArgb': floorTintArgb,
    'wallMaterialId': wallMaterialId,
    'ceilingMaterialId': ceilingMaterialId,
    'ceilingPaintColorArgb': ceilingPaintColorArgb,
    'wallTileMaterialId': wallTileMaterialId,
    'wallPaintColorArgb': wallPaintColorArgb,
    'wallTileTintArgb': wallTileTintArgb,
    'wallTileGroutMm': wallTileGroutMm,
    'wallTileRunOffsetX': wallTileRunOffsetX,
    'wallTileRunOffsetY': wallTileRunOffsetY,
    'wallTileRunEnabled': wallTileRunEnabled,
    'wallTileRunMirrored': wallTileRunMirrored,
    'wallTileRunRotated': wallTileRunRotated,
  };

  factory RoomMaterialSettings.fromJson(
    Map<String, dynamic> json,
  ) => RoomMaterialSettings(
    floorMode: json['floorMode'] as String? ?? 'laminate',
    floorWastePct: (json['floorWastePct'] as num?)?.toDouble() ?? 8,
    floorPackageM2: (json['floorPackageM2'] as num?)?.toDouble() ?? 2.2,
    underlayRollM2: (json['underlayRollM2'] as num?)?.toDouble() ?? 10,
    wallPlaster: json['wallPlaster'] as bool? ?? true,
    plasterThicknessMm: (json['plasterThicknessMm'] as num?)?.toDouble() ?? 10,
    plasterKgM2Mm: (json['plasterKgM2Mm'] as num?)?.toDouble() ?? 1,
    plasterBagKg: (json['plasterBagKg'] as num?)?.toDouble() ?? 25,
    wallPutty: json['wallPutty'] as bool? ?? true,
    puttyCoats: (json['puttyCoats'] as num?)?.toInt() ?? 2,
    puttyKgM2Coat: (json['puttyKgM2Coat'] as num?)?.toDouble() ?? 0.8,
    puttyBagKg: (json['puttyBagKg'] as num?)?.toDouble() ?? 20,
    wallPaint: json['wallPaint'] as bool? ?? true,
    paintCoats: (json['paintCoats'] as num?)?.toInt() ?? 2,
    paintCoverageM2L: (json['paintCoverageM2L'] as num?)?.toDouble() ?? 10,
    paintCanL: (json['paintCanL'] as num?)?.toDouble() ?? 9,
    wallTile: json['wallTile'] as bool? ?? false,
    wallTileWastePct: (json['wallTileWastePct'] as num?)?.toDouble() ?? 10,
    wallTileBoxM2: (json['wallTileBoxM2'] as num?)?.toDouble() ?? 1.44,
    floorTile: json['floorTile'] as bool? ?? false,
    floorTileWastePct: (json['floorTileWastePct'] as num?)?.toDouble() ?? 10,
    floorTileBoxM2: (json['floorTileBoxM2'] as num?)?.toDouble() ?? 1.44,
    tileGlueKgM2: (json['tileGlueKgM2'] as num?)?.toDouble() ?? 4,
    tileGlueBagKg: (json['tileGlueBagKg'] as num?)?.toDouble() ?? 25,
    laminatePlankLengthMm:
        (json['laminatePlankLengthMm'] as num?)?.toDouble() ?? 1380,
    laminatePlankWidthMm:
        (json['laminatePlankWidthMm'] as num?)?.toDouble() ?? 193,
    laminateOffsetMode: json['laminateOffsetMode'] as String? ?? 'half',
    laminatePattern: json['laminatePattern'] as String? ?? 'straight',
    laminateOffsetXMm: (json['laminateOffsetXMm'] as num?)?.toDouble() ?? 0,
    laminateOffsetYMm: (json['laminateOffsetYMm'] as num?)?.toDouble() ?? 0,
    floorDirectionDeg: (json['floorDirectionDeg'] as num?)?.toDouble() ?? 0,
    underlayMode: json['underlayMode'] as String? ?? 'roll',
    underlayRollWidthMm:
        (json['underlayRollWidthMm'] as num?)?.toDouble() ?? 1000,
    underlaySheetWidthMm:
        (json['underlaySheetWidthMm'] as num?)?.toDouble() ?? 500,
    underlaySheetHeightMm:
        (json['underlaySheetHeightMm'] as num?)?.toDouble() ?? 1000,
    underlayOffsetXMm: (json['underlayOffsetXMm'] as num?)?.toDouble() ?? 0,
    underlayOffsetYMm: (json['underlayOffsetYMm'] as num?)?.toDouble() ?? 0,
    tileWidthMm: (json['tileWidthMm'] as num?)?.toDouble() ?? 600,
    tileHeightMm: (json['tileHeightMm'] as num?)?.toDouble() ?? 600,
    tilePattern: json['tilePattern'] as String? ?? 'straight',
    tileOffsetXMm: (json['tileOffsetXMm'] as num?)?.toDouble() ?? 0,
    tileOffsetYMm: (json['tileOffsetYMm'] as num?)?.toDouble() ?? 0,
    floorTileGroutMm: (json['floorTileGroutMm'] as num?)?.toDouble() ?? 2,
    tileMinCutMm: (json['tileMinCutMm'] as num?)?.toDouble() ?? 120,
    wallTileWidthMm: (json['wallTileWidthMm'] as num?)?.toDouble() ?? 600,
    wallTileHeightMm: (json['wallTileHeightMm'] as num?)?.toDouble() ?? 300,
    wallTilePattern: json['wallTilePattern'] as String? ?? 'straight',
    wallTileOffsetXMm: (json['wallTileOffsetXMm'] as num?)?.toDouble() ?? 0,
    wallTileOffsetYMm: (json['wallTileOffsetYMm'] as num?)?.toDouble() ?? 0,
    wallTileFromMm: (json['wallTileFromMm'] as num?)?.toDouble() ?? 0,
    wallTileToMm: (json['wallTileToMm'] as num?)?.toDouble() ?? 2700,
    floorMaterialId: json['floorMaterialId'] as String? ?? 'oak-natural',
    floorTintArgb: (json['floorTintArgb'] as num?)?.toInt() ?? 0,
    wallMaterialId: json['wallMaterialId'] as String? ?? 'paint-warm-white',
    ceilingMaterialId:
        json['ceilingMaterialId'] as String? ?? 'paint-warm-white',
    ceilingPaintColorArgb:
        (json['ceilingPaintColorArgb'] as num?)?.toInt() ?? 0,
    wallTileMaterialId:
        json['wallTileMaterialId'] as String? ?? 'tile-light-stone',
    wallPaintColorArgb: (json['wallPaintColorArgb'] as num?)?.toInt() ?? 0,
    wallTileTintArgb: (json['wallTileTintArgb'] as num?)?.toInt() ?? 0xFFFFFFFF,
    wallTileGroutMm: (json['wallTileGroutMm'] as num?)?.toDouble() ?? 1.5,
    wallTileRunOffsetX: ((json['wallTileRunOffsetX'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
    ),
    wallTileRunOffsetY: ((json['wallTileRunOffsetY'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
    ),
    wallTileRunEnabled: ((json['wallTileRunEnabled'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k.toString(), v as bool),
    ),
    wallTileRunMirrored: ((json['wallTileRunMirrored'] as Map?) ?? const {})
        .map((k, v) => MapEntry(k.toString(), v as bool)),
    wallTileRunRotated: ((json['wallTileRunRotated'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k.toString(), v as bool),
    ),
  );
}

class RoomMeta {
  RoomMeta({
    required this.id,
    required this.faceKey,
    required this.name,
    this.ceilingHeightMm,
    this.notes = '',
    this.centroidX = 0,
    this.centroidY = 0,
    RoomMaterialSettings? materials,
    List<String>? photoPaths,
    CeilingSpec? ceiling,
    HeatingSpec? heating,
    List<FinishLayer>? floorLayers,
    List<FinishLayer>? wallLayers,
  }) : materials = materials ?? RoomMaterialSettings(),
       photoPaths = photoPaths ?? [],
       ceiling = ceiling ?? CeilingSpec(),
       heating = heating ?? HeatingSpec(),
       floorLayers = floorLayers ?? [],
       wallLayers = wallLayers ?? [];

  final String id;
  String faceKey;
  String name;
  double? ceilingHeightMm;
  String notes;
  double centroidX;
  double centroidY;
  RoomMaterialSettings materials;
  final List<String> photoPaths;
  CeilingSpec ceiling;
  HeatingSpec heating;
  final List<FinishLayer> floorLayers;
  final List<FinishLayer> wallLayers;

  double get floorBuildUpMm =>
      floorLayers.fold(0, (sum, e) => sum + e.thicknessMm);
  double get wallBuildUpMm =>
      wallLayers.fold(0, (sum, e) => sum + e.thicknessMm);

  Map<String, dynamic> toJson() => {
    'id': id,
    'faceKey': faceKey,
    'name': name,
    'ceilingHeightMm': ceilingHeightMm,
    'notes': notes,
    'centroidX': centroidX,
    'centroidY': centroidY,
    'materials': materials.toJson(),
    'photoPaths': photoPaths.toList(),
    'ceiling': ceiling.toJson(),
    'heating': heating.toJson(),
    'floorLayers': floorLayers.map((e) => e.toJson()).toList(),
    'wallLayers': wallLayers.map((e) => e.toJson()).toList(),
  };

  factory RoomMeta.fromJson(Map<String, dynamic> json) {
    final materials = RoomMaterialSettings.fromJson(
      Map<String, dynamic>.from((json['materials'] as Map?) ?? const {}),
    )..normalizeFormats();
    return RoomMeta(
      id: json['id'] as String,
      faceKey: json['faceKey'] as String? ?? '',
      name: json['name'] as String? ?? 'Помещение',
      ceilingHeightMm: (json['ceilingHeightMm'] as num?)?.toDouble(),
      notes: json['notes'] as String? ?? '',
      centroidX: (json['centroidX'] as num?)?.toDouble() ?? 0,
      centroidY: (json['centroidY'] as num?)?.toDouble() ?? 0,
      materials: materials,
      photoPaths: ((json['photoPaths'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      ceiling: CeilingSpec.fromJson(
        Map<String, dynamic>.from((json['ceiling'] as Map?) ?? const {}),
      ),
      heating: HeatingSpec.fromJson(
        Map<String, dynamic>.from((json['heating'] as Map?) ?? const {}),
      ),
      floorLayers: ((json['floorLayers'] as List?) ?? const [])
          .map((e) => FinishLayer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      wallLayers: ((json['wallLayers'] as List?) ?? const [])
          .map((e) => FinishLayer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class FinishLayer {
  FinishLayer({
    required this.id,
    required this.name,
    required this.thicknessMm,
  });
  final String id;
  String name;
  double thicknessMm;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'thicknessMm': thicknessMm,
  };
  factory FinishLayer.fromJson(Map<String, dynamic> json) => FinishLayer(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Слой',
    thicknessMm: (json['thicknessMm'] as num?)?.toDouble() ?? 0,
  );
}

class CeilingSpec {
  CeilingSpec({
    this.finish = 'paint',
    this.dropMm = 0,
    List<CeilingZone>? zones,
  }) : zones = zones ?? [];
  String finish;
  double dropMm;
  final List<CeilingZone> zones;

  Map<String, dynamic> toJson() => {
    'finish': finish,
    'dropMm': dropMm,
    'zones': zones.map((zone) => zone.toJson()).toList(),
  };
  factory CeilingSpec.fromJson(Map<String, dynamic> json) => CeilingSpec(
    finish: json['finish'] as String? ?? 'paint',
    dropMm: (json['dropMm'] as num?)?.toDouble() ?? 0,
    zones: ((json['zones'] as List?) ?? const [])
        .map((z) => CeilingZone.fromJson(Map<String, dynamic>.from(z as Map)))
        .toList(),
  );
}

class CeilingZone {
  CeilingZone({
    required this.id,
    required this.xMm,
    required this.yMm,
    this.widthMm = 1200,
    this.depthMm = 800,
    this.extraDropMm = 120,
  });
  final String id;
  double xMm, yMm, widthMm, depthMm, extraDropMm;

  Map<String, dynamic> toJson() => {
    'id': id,
    'xMm': xMm,
    'yMm': yMm,
    'widthMm': widthMm,
    'depthMm': depthMm,
    'extraDropMm': extraDropMm,
  };
  factory CeilingZone.fromJson(Map<String, dynamic> json) => CeilingZone(
    id: json['id'] as String,
    xMm: (json['xMm'] as num?)?.toDouble() ?? 0,
    yMm: (json['yMm'] as num?)?.toDouble() ?? 0,
    widthMm: (json['widthMm'] as num?)?.toDouble() ?? 1200,
    depthMm: (json['depthMm'] as num?)?.toDouble() ?? 800,
    extraDropMm: (json['extraDropMm'] as num?)?.toDouble() ?? 120,
  );
}

class HeatingSpec {
  HeatingSpec({
    this.enabled = false,
    this.coveragePct = 75,
    this.excludedAreaM2 = 0,
    this.spacingMm = 150,
    this.maxCircuitLengthM = 80,
  });
  bool enabled;
  double coveragePct, excludedAreaM2, spacingMm, maxCircuitLengthM;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'coveragePct': coveragePct,
    'excludedAreaM2': excludedAreaM2,
    'spacingMm': spacingMm,
    'maxCircuitLengthM': maxCircuitLengthM,
  };
  factory HeatingSpec.fromJson(Map<String, dynamic> json) => HeatingSpec(
    enabled: json['enabled'] as bool? ?? false,
    coveragePct: (json['coveragePct'] as num?)?.toDouble() ?? 75,
    excludedAreaM2: (json['excludedAreaM2'] as num?)?.toDouble() ?? 0,
    spacingMm: (json['spacingMm'] as num?)?.toDouble() ?? 150,
    maxCircuitLengthM: (json['maxCircuitLengthM'] as num?)?.toDouble() ?? 80,
  );
}

class FaceEdge {
  const FaceEdge({
    required this.wallId,
    required this.fromNodeId,
    required this.toNodeId,
  });

  final String wallId;
  final String fromNodeId;
  final String toNodeId;
}

class RoomFace {
  RoomFace({
    required this.key,
    required this.nodeIds,
    required this.edges,
    required this.innerPolygon,
    required this.signedAreaMm2,
  });

  final String key;
  final List<String> nodeIds;
  final List<FaceEdge> edges;
  final List<math.Point<double>> innerPolygon;
  final double signedAreaMm2;

  double get areaM2 {
    if (innerPolygon.length < 3) return 0;
    var s = 0.0;
    for (var i = 0; i < innerPolygon.length; i++) {
      final a = innerPolygon[i];
      final b = innerPolygon[(i + 1) % innerPolygon.length];
      s += a.x * b.y - b.x * a.y;
    }
    return s.abs() / 2 / 1000000.0;
  }

  double get perimeterM {
    if (innerPolygon.length < 2) return 0;
    var s = 0.0;
    for (var i = 0; i < innerPolygon.length; i++) {
      final a = innerPolygon[i];
      final b = innerPolygon[(i + 1) % innerPolygon.length];
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      s += math.sqrt(dx * dx + dy * dy);
    }
    return s / 1000.0;
  }

  math.Point<double> get centroid {
    if (innerPolygon.isEmpty) return const math.Point<double>(0, 0);
    var x = 0.0;
    var y = 0.0;
    for (final p in innerPolygon) {
      x += p.x;
      y += p.y;
    }
    return math.Point(x / innerPolygon.length, y / innerPolygon.length);
  }
}

class MaterialEstimate {
  const MaterialEstimate({
    required this.name,
    required this.quantity,
    required this.unit,
    this.packages,
    this.packageLabel,
    this.note = '',
  });

  final String name;
  final double quantity;
  final String unit;
  final int? packages;
  final String? packageLabel;
  final String note;
}

class PartitionTakeoff {
  const PartitionTakeoff({
    required this.wallLengthM,
    required this.netOneSideAreaM2,
    required this.boardAreaM2,
    required this.boardSheets,
    required this.studs,
    required this.trackM,
    required this.insulationM2,
  });

  final double wallLengthM;
  final double netOneSideAreaM2;
  final double boardAreaM2;
  final int boardSheets;
  final int studs;
  final double trackM;
  final double insulationM2;
}

enum ElectricalPointType {
  panel,
  junctionBox,
  ceilingLight,
  wallLight,
  switchPoint,
  socket,
  tvSocket,
  dataSocket,
  frame,
  appliance,
}

enum ElectricalModuleType { socket220, switch1, switch2, tv, data, blank }

extension ElectricalModuleTypeLabel on ElectricalModuleType {
  String get label => switch (this) {
    ElectricalModuleType.socket220 => 'Розетка 220В',
    ElectricalModuleType.switch1 => 'Выключатель 1 кл.',
    ElectricalModuleType.switch2 => 'Выключатель 2 кл.',
    ElectricalModuleType.tv => 'TV',
    ElectricalModuleType.data => 'Интернет RJ-45',
    ElectricalModuleType.blank => 'Заглушка',
  };
}

extension ElectricalPointTypeLabel on ElectricalPointType {
  String get label => switch (this) {
    ElectricalPointType.panel => 'Щит',
    ElectricalPointType.junctionBox => 'Распредкоробка',
    ElectricalPointType.ceilingLight => 'Световая точка',
    ElectricalPointType.wallLight => 'Бра',
    ElectricalPointType.switchPoint => 'Выключатель',
    ElectricalPointType.socket => 'Розетка 220В',
    ElectricalPointType.tvSocket => 'TV-розетка',
    ElectricalPointType.dataSocket => 'Интернет-розетка',
    ElectricalPointType.frame => 'Рамка устройств',
    ElectricalPointType.appliance => 'Вывод питания',
  };
}

class ElectricalPoint {
  ElectricalPoint({
    required this.id,
    required this.type,
    required this.xMm,
    required this.yMm,
    this.label = '',
    this.heightMm = 300,
    this.circuit = 'Группа 1',
    this.powerW = 0,
    this.wallId,
    this.wallOffsetMm,
    this.wallSide = 1,
    List<ElectricalModuleType>? modules,
    this.frameVertical = false,
  }) : modules = modules ?? [_defaultModuleFor(type)];

  final String id;
  ElectricalPointType type;
  double xMm;
  double yMm;
  String label;
  double heightMm;
  String circuit;
  double powerW;
  String? wallId;
  double? wallOffsetMm;
  // +1 is the left side of the oriented wall in plan coordinates.
  int wallSide;
  final List<ElectricalModuleType> modules;
  bool frameVertical;

  bool get isWallDevice => <ElectricalPointType>{
    ElectricalPointType.wallLight,
    ElectricalPointType.switchPoint,
    ElectricalPointType.socket,
    ElectricalPointType.tvSocket,
    ElectricalPointType.dataSocket,
    ElectricalPointType.frame,
    ElectricalPointType.panel,
    ElectricalPointType.appliance,
  }.contains(type);

  static ElectricalModuleType _defaultModuleFor(ElectricalPointType type) =>
      switch (type) {
        ElectricalPointType.switchPoint => ElectricalModuleType.switch1,
        ElectricalPointType.tvSocket => ElectricalModuleType.tv,
        ElectricalPointType.dataSocket => ElectricalModuleType.data,
        ElectricalPointType.frame => ElectricalModuleType.socket220,
        _ => ElectricalModuleType.socket220,
      };

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'xMm': xMm,
    'yMm': yMm,
    'label': label,
    'heightMm': heightMm,
    'circuit': circuit,
    'powerW': powerW,
    'wallId': wallId,
    'wallOffsetMm': wallOffsetMm,
    'wallSide': wallSide,
    'modules': modules.map((e) => e.name).toList(),
    'frameVertical': frameVertical,
  };

  factory ElectricalPoint.fromJson(Map<String, dynamic> json) {
    final type = ElectricalPointType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ElectricalPointType.socket,
    );
    final rawModules =
        (json['modules'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    final modules = rawModules
        .map(
          (name) => ElectricalModuleType.values.firstWhere(
            (e) => e.name == name,
            orElse: () => ElectricalModuleType.socket220,
          ),
        )
        .toList();
    return ElectricalPoint(
      id: json['id'] as String,
      type: type,
      xMm: (json['xMm'] as num).toDouble(),
      yMm: (json['yMm'] as num).toDouble(),
      label: json['label'] as String? ?? '',
      heightMm: (json['heightMm'] as num?)?.toDouble() ?? 300,
      circuit: json['circuit'] as String? ?? 'Группа 1',
      powerW: (json['powerW'] as num?)?.toDouble() ?? 0,
      wallId: json['wallId'] as String?,
      wallOffsetMm: (json['wallOffsetMm'] as num?)?.toDouble(),
      wallSide: (json['wallSide'] as num?)?.toInt() == -1 ? -1 : 1,
      modules: modules.isEmpty ? null : modules,
      frameVertical: json['frameVertical'] as bool? ?? false,
    );
  }
}

class ElectricalRun {
  ElectricalRun({
    required this.id,
    required this.startPointId,
    required this.endPointId,
    this.cable = 'ВВГнг-LS 3×1.5',
    this.reservePct = 10,
    this.routeMode = 'direct',
  });

  final String id;
  String startPointId;
  String endPointId;
  String cable;
  double reservePct;
  String routeMode;

  Map<String, dynamic> toJson() => {
    'id': id,
    'startPointId': startPointId,
    'endPointId': endPointId,
    'cable': cable,
    'reservePct': reservePct,
    'routeMode': routeMode,
  };

  factory ElectricalRun.fromJson(Map<String, dynamic> json) => ElectricalRun(
    id: json['id'] as String,
    startPointId: json['startPointId'] as String,
    endPointId: json['endPointId'] as String,
    cable: json['cable'] as String? ?? 'ВВГнг-LS 3×1.5',
    reservePct: (json['reservePct'] as num?)?.toDouble() ?? 10,
    routeMode: json['routeMode'] as String? ?? 'direct',
  );
}

enum ServiceRunType { coldWater, hotWater, drain, heating }

extension ServiceRunTypeLabel on ServiceRunType {
  String get label => switch (this) {
    ServiceRunType.coldWater => 'Холодная вода',
    ServiceRunType.hotWater => 'Горячая вода',
    ServiceRunType.drain => 'Канализация',
    ServiceRunType.heating => 'Отопление',
  };
}

class ServiceVertex {
  ServiceVertex(this.xMm, this.yMm);
  double xMm, yMm;
  Map<String, dynamic> toJson() => {'xMm': xMm, 'yMm': yMm};
  factory ServiceVertex.fromJson(Map<String, dynamic> json) => ServiceVertex(
    (json['xMm'] as num).toDouble(),
    (json['yMm'] as num).toDouble(),
  );
}

class ServiceRun {
  ServiceRun({
    required this.id,
    required this.type,
    List<ServiceVertex>? points,
    this.diameterMm = 20,
    this.slopePct = 0,
    this.note = '',
  }) : points = points ?? [];
  final String id;
  ServiceRunType type;
  final List<ServiceVertex> points;
  double diameterMm, slopePct;
  String note;

  double get lengthM {
    var result = 0.0;
    for (var i = 1; i < points.length; i++) {
      final dx = points[i].xMm - points[i - 1].xMm;
      final dy = points[i].yMm - points[i - 1].yMm;
      result += math.sqrt(dx * dx + dy * dy) / 1000;
    }
    return result;
  }

  double get fallMm => lengthM * 1000 * slopePct / 100;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'diameterMm': diameterMm,
    'slopePct': slopePct,
    'note': note,
    'points': points.map((p) => p.toJson()).toList(),
  };
  factory ServiceRun.fromJson(Map<String, dynamic> json) => ServiceRun(
    id: json['id'] as String,
    type: ServiceRunType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ServiceRunType.coldWater,
    ),
    diameterMm: (json['diameterMm'] as num?)?.toDouble() ?? 20,
    slopePct: (json['slopePct'] as num?)?.toDouble() ?? 0,
    note: json['note'] as String? ?? '',
    points: ((json['points'] as List?) ?? const [])
        .map((p) => ServiceVertex.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList(),
  );
}

enum PlanObjectType {
  ceilingZone,
  waterPoint,
  drainPoint,
  radiator,
  furniture,
  sanitary,
  beam,
  column,
  box,
  niche,
  lighting,
}

extension PlanObjectTypeLabel on PlanObjectType {
  String get label => switch (this) {
    PlanObjectType.ceilingZone => 'Потолочная зона',
    PlanObjectType.waterPoint => 'Вода',
    PlanObjectType.drainPoint => 'Канализация',
    PlanObjectType.radiator => 'Радиатор',
    PlanObjectType.furniture => 'Мебель',
    PlanObjectType.sanitary => 'Сантехника',
    PlanObjectType.beam => 'Балка',
    PlanObjectType.column => 'Колонна',
    PlanObjectType.box => 'Короб',
    PlanObjectType.niche => 'Ниша',
    PlanObjectType.lighting => 'Освещение',
  };
}

class PlanObject {
  PlanObject({
    required this.id,
    required this.type,
    required this.xMm,
    required this.yMm,
    this.widthMm = 600,
    this.depthMm = 600,
    this.heightMm = 600,
    this.elevationMm = 0,
    this.rotationDeg = 0,
    this.label = '',
    this.layer = ProjectLayer.proposed,
    this.slopePct = 0,
    this.catalogId = '',
  });

  final String id;
  PlanObjectType type;
  double xMm;
  double yMm;
  double widthMm;
  double depthMm;
  double heightMm;
  double elevationMm;
  double rotationDeg;
  String label;
  ProjectLayer layer;
  double slopePct;
  String catalogId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'xMm': xMm,
    'yMm': yMm,
    'widthMm': widthMm,
    'depthMm': depthMm,
    'heightMm': heightMm,
    'elevationMm': elevationMm,
    'rotationDeg': rotationDeg,
    'label': label,
    'layer': layer.name,
    'slopePct': slopePct,
    'catalogId': catalogId,
  };

  factory PlanObject.fromJson(Map<String, dynamic> json) => PlanObject(
    id: json['id'] as String,
    type: PlanObjectType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => PlanObjectType.furniture,
    ),
    xMm: (json['xMm'] as num?)?.toDouble() ?? 0,
    yMm: (json['yMm'] as num?)?.toDouble() ?? 0,
    widthMm: (json['widthMm'] as num?)?.toDouble() ?? 600,
    depthMm: (json['depthMm'] as num?)?.toDouble() ?? 600,
    heightMm: (json['heightMm'] as num?)?.toDouble() ?? 600,
    elevationMm: (json['elevationMm'] as num?)?.toDouble() ?? 0,
    rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0,
    label: json['label'] as String? ?? '',
    layer: ProjectLayer.values.firstWhere(
      (e) => e.name == json['layer'],
      orElse: () => ProjectLayer.proposed,
    ),
    slopePct: (json['slopePct'] as num?)?.toDouble() ?? 0,
    catalogId: json['catalogId'] as String? ?? '',
  );
}
