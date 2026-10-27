import 'dart:math' as math;

/// All coordinates are explicit project-world millimetres. Z is the height
/// relative to the model's finished-floor datum. A saved path is NOT a
/// verification that this datum or the wiring position was surveyed.
enum ElectricalPathSource { unspecified, drawing, measured }
enum ElectricalInstallationMethod {
  unspecified,
  inWall,
  aboveCeiling,
  inFloor,
  exposed,
  conduit,
  tray,
}

class ElectricalRouteVertex {
  const ElectricalRouteVertex({
    required this.xMm, required this.yMm, required this.zMm,
  });

  final double xMm, yMm, zMm;
  bool get finite => xMm.isFinite && yMm.isFinite && zMm.isFinite;
  double distanceTo(ElectricalRouteVertex b) {
    final dx = xMm - b.xMm;
    final dy = yMm - b.yMm;
    final dz = zMm - b.zMm;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  Map<String, dynamic> toJson() => {
    'xMm': xMm, 'yMm': yMm, 'zMm': zMm,
  };

  factory ElectricalRouteVertex.fromJson(Map<String, dynamic> j) =>
      ElectricalRouteVertex(
        xMm: (j['xMm'] as num).toDouble(),
        yMm: (j['yMm'] as num).toDouble(),
        zMm: (j['zMm'] as num).toDouble(),
      );
}

class ElectricalRoute3d {
  ElectricalRoute3d({
    required this.id,
    required this.fromPointId,
    required this.toPointId,
    required List<ElectricalRouteVertex> vertices,
    required List<ElectricalInstallationMethod> methods,
    this.source = ElectricalPathSource.unspecified,
    this.note = '',
  }) : vertices = vertices, methods = methods;

  final String id;
  final String fromPointId, toPointId;
  /// Deliberately independent of legacy ElectricalRun geometry.
  final List<ElectricalRouteVertex> vertices;
  /// Per leg; length must equal vertices.length - 1.
  final List<ElectricalInstallationMethod> methods;
  ElectricalPathSource source;
  String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromPointId': fromPointId,
    'toPointId': toPointId,
    'vertices': vertices.map((v) => v.toJson()).toList(),
    'methods': methods.map((m) => m.name).toList(),
    'source': source.name,
    'note': note,
  };

  factory ElectricalRoute3d.fromJson(Map<String, dynamic> j) =>
      ElectricalRoute3d(
        id: j['id'] as String,
        fromPointId: j['fromPointId'] as String,
        toPointId: j['toPointId'] as String,
        vertices: ((j['vertices'] as List?) ?? const [])
            .map((v) => ElectricalRouteVertex.fromJson(
                Map<String, dynamic>.from(v as Map)))
            .toList(),
        methods: ((j['methods'] as List?) ?? const [])
            .map((m) => ElectricalInstallationMethod.values.firstWhere(
                (e) => e.name == m,
                orElse: () => ElectricalInstallationMethod.unspecified))
            .toList(),
        source: ElectricalPathSource.values.firstWhere(
            (e) => e.name == j['source'],
            orElse: () => ElectricalPathSource.unspecified),
        note: j['note'] as String? ?? '',
      );
}
