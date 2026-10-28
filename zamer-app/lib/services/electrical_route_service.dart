import '../models/electrical_network.dart';
import '../models/electrical_route_3d.dart';
import '../models/models.dart';

/// Geometric measurements only, never electrical safety approval or an
/// estimate of cable capacity, installation feasibility or procurement.
class ElectricalRouteMeasurement {
  const ElectricalRouteMeasurement({
    required this.geometricMm,
    required this.reserveMm,
    required this.legLengthsMm,
  });
  final double geometricMm;
  final double? reserveMm;
  final List<double> legLengthsMm;
  double? get procurementLengthMm =>
      reserveMm == null ? null : geometricMm + reserveMm!;
}

class ElectricalRouteService {
  const ElectricalRouteService._();

  static ElectricalRouteVertex endpoint(ElectricalPoint point) =>
      ElectricalRouteVertex(
        xMm: point.xMm, yMm: point.yMm, zMm: point.heightMm,
      );

  static ElectricalRouteVertex step(
    ElectricalRouteVertex from, String axis, double signedMm,
  ) {
    if (!signedMm.isFinite || signedMm == 0 || signedMm.abs() > 10000000) {
      throw const FormatException('Введите ненулевой размер участка в мм.');
    }
    return switch (axis) {
      'X' => ElectricalRouteVertex(
          xMm: from.xMm + signedMm, yMm: from.yMm, zMm: from.zMm),
      'Y' => ElectricalRouteVertex(
          xMm: from.xMm, yMm: from.yMm + signedMm, zMm: from.zMm),
      'Z' => ElectricalRouteVertex(
          xMm: from.xMm, yMm: from.yMm, zMm: from.zMm + signedMm),
      _ => throw const FormatException('Неизвестная ось участка.'),
    };
  }

  /// All dimensions are project-world mm, never pixels or a screen scale.
  static ElectricalRouteMeasurement measure(
    FloorPlan floor,
    ElectricalRoute3d route, {
    double? reserveMm,
  }) {
    if (route.id.trim().isEmpty ||
        route.fromPointId == route.toPointId ||
        route.vertices.length < 2 ||
        route.methods.length != route.vertices.length - 1) {
      throw const FormatException('Не закончена геометрия кабельной трассы.');
    }
    final a = floor.electricalPoints
        .where((p) => p.id == route.fromPointId).firstOrNull;
    final b = floor.electricalPoints
        .where((p) => p.id == route.toPointId).firstOrNull;
    if (a == null || b == null) {
      throw const FormatException('Концевая точка трассы удалена.');
    }
    if (reserveMm != null &&
        (!reserveMm.isFinite || reserveMm < 0 || reserveMm > 10000000)) {
      throw const FormatException('Укажите допустимый монтажный запас.');
    }
    if (route.vertices.any((v) => !v.finite ||
        v.xMm.abs() > 10000000 || v.yMm.abs() > 10000000 ||
        v.zMm.abs() > 10000000)) {
      throw const FormatException('В трассе есть недопустимые координаты.');
    }
    if (route.vertices.first.distanceTo(endpoint(a)) > .5 ||
        route.vertices.last.distanceTo(endpoint(b)) > .5) {
      throw const FormatException(
          'Точки или высоты изменились: перепроверьте концы трассы.');
    }
    final lengths = <double>[];
    for (var i = 1; i < route.vertices.length; i++) {
      final prev = route.vertices[i - 1];
      final next = route.vertices[i];
      final dx = (next.xMm - prev.xMm).abs();
      final dy = (next.yMm - prev.yMm).abs();
      final dz = (next.zMm - prev.zMm).abs();
      if ([dx, dy, dz].where((n) => n > .001).length != 1) {
        throw FormatException(
            'Участок $i должен идти строго по одной оси X, Y или Z.');
      }
      final length = prev.distanceTo(next);
      if (!length.isFinite || length < .001) {
        throw const FormatException('Обнаружен участок нулевой длины.');
      }
      lengths.add(length);
    }
    return ElectricalRouteMeasurement(
      geometricMm: lengths.fold(0.0, (a, b) => a + b),
      reserveMm: reserveMm,
      legLengthsMm: lengths,
    );
  }

  static ElectricalRouteMeasurement measureCable(
    FloorPlan floor, ElectricalCableRecord cable,
  ) {
    final network = floor.electricalNetwork;
    final route = network?.routes3d.where(
        (r) => r.id == cable.route3dId).firstOrNull;
    if (route == null ||
        (route.fromPointId != cable.fromPointId &&
         route.toPointId != cable.fromPointId) ||
        (route.fromPointId != cable.toPointId &&
         route.toPointId != cable.toPointId)) {
      throw const FormatException('Кабель не связан с подходящей 3D-трассой.');
    }
    return measure(floor, route, reserveMm: cable.explicitReserveMm);
  }

  /// Replace an existing route only if no other cable uses that same route,
  /// preventing an edit to one cable from silently moving another cable.
  static void upsertForCable(
    FloorPlan floor,
    ElectricalNetwork draft,
    String cableId,
    ElectricalRoute3d route, {
    double? reserveMm,
  }) {
    final cable = draft.cables.where((c) => c.id == cableId).firstOrNull;
    if (cable == null) {
      throw const FormatException('Кабель удалён из схемы.');
    }
    if (route.fromPointId != cable.fromPointId ||
        route.toPointId != cable.toPointId) {
      throw const FormatException('Трасса не соответствует концам кабеля.');
    }
    measure(floor, route, reserveMm: reserveMm);
    final same = draft.routes3d.where((r) => r.id == route.id).firstOrNull;
    if (same != null && draft.cables.any(
      (c) => c.id != cableId && c.route3dId == route.id)) {
      throw const FormatException(
          'Общая трасса используется другим кабелем. Создайте отдельную копию.');
    }
    final path = ElectricalRoute3d.fromJson(route.toJson());
    final existingIndex = draft.routes3d.indexWhere((r) => r.id == path.id);
    if (existingIndex < 0) {
      draft.routes3d.add(path);
    } else {
      draft.routes3d[existingIndex] = path;
    }
    cable.route3dId = path.id;
    cable.explicitReserveMm = reserveMm;
  }

  static void clearCableRoute(ElectricalNetwork draft, String cableId) {
    final cable = draft.cables.where((c) => c.id == cableId).firstOrNull;
    if (cable == null) {
      throw const FormatException('Кабель удалён из схемы.');
    }
    final former = cable.route3dId;
    cable.route3dId = null;
    cable.explicitReserveMm = null;
    if (former != null && !draft.cables.any((c) => c.route3dId == former)) {
      draft.routes3d.removeWhere((r) => r.id == former);
    }
  }
}
