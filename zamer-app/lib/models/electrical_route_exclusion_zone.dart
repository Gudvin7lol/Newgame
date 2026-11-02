import 'electrical_route_3d.dart';

/// Explicit 3D *no-route* prism in project millimetres. Unknown geometry
/// is not an empty exclusion; the tool only knows about saved regions.
class ElectricalRouteExclusionZone {
  const ElectricalRouteExclusionZone({
    required this.id,
    required this.name,
    required this.minXMm,
    required this.maxXMm,
    required this.minYMm,
    required this.maxYMm,
    required this.minZMm,
    required this.maxZMm,
    this.note = '',
  });
  final String id, name, note;
  final double minXMm, maxXMm, minYMm, maxYMm, minZMm, maxZMm;

  void validate() {
    if (id.trim().isEmpty || name.trim().isEmpty ||
        ![minXMm,maxXMm,minYMm,maxYMm,minZMm,maxZMm]
          .every((n) => n.isFinite && n.abs() < 10000000) ||
        minXMm >= maxXMm || minYMm >= maxYMm ||
        minZMm >= maxZMm) {
      throw const FormatException(
          'Запретная зона: укажите название и допустимые границы X/Y/Z.');
    }
  }

  /// Segment vs axis-aligned box, slab clipping, including boundaries.
  /// A route touching an excluded boundary is considered blocked.
  bool intersects(ElectricalRouteVertex a, ElectricalRouteVertex b) {
    validate();
    if (!a.finite || !b.finite) return true;
    const epsilon = 1e-9;
    var low = 0.0, high = 1.0;
    final axes = <({double a, double delta, double min, double max})>[
      (a:a.xMm,delta:b.xMm-a.xMm,min:minXMm,max:maxXMm),
      (a:a.yMm,delta:b.yMm-a.yMm,min:minYMm,max:maxYMm),
      (a:a.zMm,delta:b.zMm-a.zMm,min:minZMm,max:maxZMm),
    ];
    for (final axis in axes) {
      if (axis.delta.abs() < epsilon) {
        if (axis.a < axis.min || axis.a > axis.max) return false;
        continue;
      }
      final t1 = (axis.min - axis.a) / axis.delta;
      final t2 = (axis.max - axis.a) / axis.delta;
      final enter = t1 < t2 ? t1 : t2;
      final leave = t1 > t2 ? t1 : t2;
      if (enter > low) low = enter;
      if (leave < high) high = leave;
      if (low > high) return false;
    }
    return true;
  }

  /// Return a point INSIDE the actual intersected portion of this volume.
  /// Unlike the midpoint of the entire cable leg, this is an accurate plan
  /// camera target even for a very long cable with a small distant obstacle.
  /// Non-finite geometry has no trustworthy coordinate to navigate to.
  ElectricalRouteVertex? intersectionMidpoint(
      ElectricalRouteVertex a, ElectricalRouteVertex b) {
    validate();
    if (!a.finite || !b.finite) return null;
    const epsilon = 1e-9;
    var enter = 0.0, leave = 1.0;
    for (final axis in <({double origin, double delta, double min, double max})>[
      (origin:a.xMm,delta:b.xMm-a.xMm,min:minXMm,max:maxXMm),
      (origin:a.yMm,delta:b.yMm-a.yMm,min:minYMm,max:maxYMm),
      (origin:a.zMm,delta:b.zMm-a.zMm,min:minZMm,max:maxZMm),
    ]) {
      if (axis.delta.abs() < epsilon) {
        if (axis.origin < axis.min || axis.origin > axis.max) return null;
        continue;
      }
      final first = (axis.min - axis.origin) / axis.delta;
      final last = (axis.max - axis.origin) / axis.delta;
      final lo = first < last ? first : last;
      final hi = first > last ? first : last;
      if (lo > enter) enter = lo;
      if (hi < leave) leave = hi;
      if (enter > leave) return null;
    }
    final t = (enter + leave) / 2;
    return ElectricalRouteVertex(
      xMm:a.xMm + (b.xMm - a.xMm) * t,
      yMm:a.yMm + (b.yMm - a.yMm) * t,
      zMm:a.zMm + (b.zMm - a.zMm) * t,
    );
  }

  Map<String,dynamic> toJson() => {
    'id':id,'name':name,'note':note,
    'minXMm':minXMm,'maxXMm':maxXMm,
    'minYMm':minYMm,'maxYMm':maxYMm,
    'minZMm':minZMm,'maxZMm':maxZMm,
  };

  factory ElectricalRouteExclusionZone.fromJson(Map<String,dynamic> json) {
    double value(String key) => (json[key] as num).toDouble();
    final zone = ElectricalRouteExclusionZone(
      id:json['id'] as String,
      name:json['name'] as String,
      note:json['note'] as String? ?? '',
      minXMm:value('minXMm'),maxXMm:value('maxXMm'),
      minYMm:value('minYMm'),maxYMm:value('maxYMm'),
      minZMm:value('minZMm'),maxZMm:value('maxZMm'),
    );
    zone.validate();
    return zone;
  }
}
