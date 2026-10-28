import '../models/electrical_network.dart';
import '../models/models.dart';
import 'electrical_route_service.dart';

enum CableJournalStatus { measuredRoute, noRoute, invalidRoute }

/// One physical cable, counted exactly once, never one entry per core.
class CableJournalRow {
  const CableJournalRow({
    required this.cable,
    required this.circuitName,
    required this.fromLabel,
    required this.toLabel,
    required this.status,
    this.geometricMm,
    this.reserveMm,
    this.withReserveMm,
    this.problem,
  });
  final ElectricalCableRecord cable;
  final String circuitName;
  final String fromLabel;
  final String toLabel;
  final CableJournalStatus status;
  final double? geometricMm, reserveMm, withReserveMm;
  final String? problem;
  bool get hasRoute => status == CableJournalStatus.measuredRoute;
  bool get hasFullLength => withReserveMm != null;
}

class CableJournalTotals {
  const CableJournalTotals({
    required this.cableCount,
    required this.routedCount,
    required this.unknownRouteCount,
    required this.invalidRouteCount,
    required this.unknownReserveCount,
    required this.knownGeometricMm,
    required this.knownWithReserveMm,
    required this.complete,
  });
  final int cableCount, routedCount, unknownRouteCount;
  final int invalidRouteCount, unknownReserveCount;
  final double knownGeometricMm, knownWithReserveMm;
  final bool complete;
}

class ElectricalCableJournal {
  const ElectricalCableJournal({
    required this.rows, required this.groups, required this.totals,
  });
  final List<CableJournalRow> rows;
  final Map<String, List<CableJournalRow>> groups;
  final CableJournalTotals totals;
}

/// A physical cable journal from explicit topology only. Legacy lines/groups
/// cannot silently become physical cable objects or procurement quantities.
class ElectricalCableJournalService {
  const ElectricalCableJournalService._();

  static String _point(FloorPlan floor, String id) {
    final point = floor.electricalPoints.where((p) => p.id == id).firstOrNull;
    if (point == null) return 'Удалённая точка: $id';
    return point.label.trim().isEmpty ? point.type.label : point.label;
  }

  static ElectricalCableJournal create(FloorPlan floor, {String? circuitId}) {
    final network = floor.electricalNetwork;
    if (network == null) {
      return const ElectricalCableJournal(
        rows: [], groups: {},
        totals: CableJournalTotals(
          cableCount: 0, routedCount: 0, unknownRouteCount: 0,
          invalidRouteCount: 0, unknownReserveCount: 0,
          knownGeometricMm: 0, knownWithReserveMm: 0, complete: false,
        ),
      );
    }
    final circuitNames = {
      for (final c in network.circuits) c.id: c.name,
    };
    final rows = <CableJournalRow>[];
    for (final cable in network.cables) {
      if (circuitId != null && cable.circuitId != circuitId) continue;
      final name = circuitNames[cable.circuitId] ?? 'Удалённая цепь';
      final from = _point(floor, cable.fromPointId);
      final to = _point(floor, cable.toPointId);
      if (cable.route3dId == null) {
        rows.add(CableJournalRow(
          cable: cable, circuitName: name,
          fromLabel: from, toLabel: to,
          status: CableJournalStatus.noRoute,
          problem: 'Трасса в 3D не указана',
        ));
        continue;
      }
      try {
        final m = ElectricalRouteService.measureCable(floor, cable);
        rows.add(CableJournalRow(
          cable: cable, circuitName: name,
          fromLabel: from, toLabel: to,
          status: CableJournalStatus.measuredRoute,
          geometricMm: m.geometricMm,
          reserveMm: m.reserveMm,
          withReserveMm: m.procurementLengthMm,
        ));
      } on FormatException catch (e) {
        rows.add(CableJournalRow(
          cable: cable, circuitName: name,
          fromLabel: from, toLabel: to,
          status: CableJournalStatus.invalidRoute,
          problem: e.message,
        ));
      }
    }
    rows.sort((a,b) {
      final c = a.circuitName.compareTo(b.circuitName);
      return c != 0 ? c : a.cable.id.compareTo(b.cable.id);
    });
    final groups = <String, List<CableJournalRow>>{};
    for (final row in rows) {
      groups.putIfAbsent(row.cable.circuitId, () => []).add(row);
    }
    final routed = rows.where((r) => r.hasRoute).toList();
    final unknownRoutes = rows.where((r) =>
        r.status == CableJournalStatus.noRoute).length;
    final invalid = rows.where((r) =>
        r.status == CableJournalStatus.invalidRoute).length;
    final unknownReserve = routed.where((r) => !r.hasFullLength).length;
    final full = unknownRoutes == 0 && invalid == 0 && unknownReserve == 0;
    return ElectricalCableJournal(
      rows: rows,
      groups: groups,
      totals: CableJournalTotals(
        cableCount: rows.length, routedCount: routed.length,
        unknownRouteCount: unknownRoutes,
        invalidRouteCount: invalid,
        unknownReserveCount: unknownReserve,
        knownGeometricMm: routed.fold(0, (double s, r) => s + r.geometricMm!),
        knownWithReserveMm: routed.fold(0, (double s, r) =>
            s + (r.withReserveMm ?? 0)),
        complete: full && rows.isNotEmpty,
      ),
    );
  }
}
