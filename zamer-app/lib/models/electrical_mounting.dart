/// A documented dimension, separate from the legacy drawing coordinates.
/// Unknown floor levels and survey accuracy deliberately remain nullable.
enum MountingSource { unknown, measured, document, designed }

class ElectricalMounting {
  const ElectricalMounting({
    required this.wallId,
    required this.datumNodeId,
    required this.datumName,
    required this.datumInsetMm,
    required this.distanceMm,
    required this.heightAboveFinishedFloorMm,
    required this.wallSide,
    required this.geometrySnapshot,
    this.source = MountingSource.unknown,
    this.finishedFloorAboveSlabMm,
    this.measurementUncertaintyMm,
  });

  final String wallId, datumNodeId, datumName, geometrySnapshot;
  // Positive inset and distance point from the chosen end into the wall.
  final double datumInsetMm, distanceMm, heightAboveFinishedFloorMm;
  final int wallSide;
  final MountingSource source;
  final double? finishedFloorAboveSlabMm, measurementUncertaintyMm;

  double? get heightAboveSlabMm => finishedFloorAboveSlabMm == null
      ? null
      : heightAboveFinishedFloorMm + finishedFloorAboveSlabMm!;

  Map<String, dynamic> toJson() => {
    'wallId': wallId,
    'datumNodeId': datumNodeId,
    'datumName': datumName,
    'datumInsetMm': datumInsetMm,
    'distanceMm': distanceMm,
    'heightAboveFinishedFloorMm': heightAboveFinishedFloorMm,
    'wallSide': wallSide,
    'geometrySnapshot': geometrySnapshot,
    'source': source.name,
    'finishedFloorAboveSlabMm': finishedFloorAboveSlabMm,
    'measurementUncertaintyMm': measurementUncertaintyMm,
  };

  factory ElectricalMounting.fromJson(Map<String, dynamic> j) =>
      ElectricalMounting(
        wallId: j['wallId'] as String,
        datumNodeId: j['datumNodeId'] as String,
        datumName: j['datumName'] as String,
        datumInsetMm: (j['datumInsetMm'] as num).toDouble(),
        distanceMm: (j['distanceMm'] as num).toDouble(),
        heightAboveFinishedFloorMm: (j['heightAboveFinishedFloorMm'] as num)
            .toDouble(),
        wallSide: j['wallSide'] as int,
        geometrySnapshot: j['geometrySnapshot'] as String,
        source: MountingSource.values.firstWhere(
          (v) => v.name == j['source'],
          orElse: () => MountingSource.unknown,
        ),
        finishedFloorAboveSlabMm: (j['finishedFloorAboveSlabMm'] as num?)
            ?.toDouble(),
        measurementUncertaintyMm: (j['measurementUncertaintyMm'] as num?)
            ?.toDouble(),
      );
}
