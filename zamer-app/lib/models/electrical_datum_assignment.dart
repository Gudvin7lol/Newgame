/// An explicit, read-only dimensional reference assigned to one electrical
/// device centre. This does NOT change its position, cable, or P1 mounting.
/// The saved reference is PROJECT DATA, not an approved drilling point.
class ElectricalDatumAssignment {
  const ElectricalDatumAssignment({
    required this.wallId,
    required this.wallSide,
    required this.datumId,
    required this.datumTitle,
    required this.datumUMm,
    required this.pointUMm,
    required this.pointHeightMm,
    required this.fromDatumMm,
    required this.geometrySnapshot,
  });

  final String wallId, datumId, datumTitle, geometrySnapshot;
  final int wallSide;
  final double datumUMm, pointUMm, pointHeightMm, fromDatumMm;

  Map<String, dynamic> toJson() => {
    'wallId': wallId,
    'wallSide': wallSide,
    'datumId': datumId,
    'datumTitle': datumTitle,
    'datumUMm': datumUMm,
    'pointUMm': pointUMm,
    'pointHeightMm': pointHeightMm,
    'fromDatumMm': fromDatumMm,
    'geometrySnapshot': geometrySnapshot,
  };

  factory ElectricalDatumAssignment.fromJson(Map<String, dynamic> j) =>
      ElectricalDatumAssignment(
        wallId: j['wallId'] as String,
        wallSide: (j['wallSide'] as num).toInt(),
        datumId: j['datumId'] as String,
        datumTitle: j['datumTitle'] as String,
        datumUMm: (j['datumUMm'] as num).toDouble(),
        pointUMm: (j['pointUMm'] as num).toDouble(),
        pointHeightMm: (j['pointHeightMm'] as num).toDouble(),
        fromDatumMm: (j['fromDatumMm'] as num).toDouble(),
        geometrySnapshot: j['geometrySnapshot'] as String,
      );
}
