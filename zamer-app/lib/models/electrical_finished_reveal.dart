/// A pair of explicitly entered *finished* opening-edge stations on ONE
/// oriented wall face. Positions are absolute millimetres from wall start.
/// Not to be confused with WallOpening rough geometry or door-frame edges.
///
/// This is a recorded measurement/design input, not automatic site approval.
/// The geometrySnapshot catches changes to wall/finish/opening geometry.
enum OpeningRevealSource { unspecified, designed, document, measured }

class ElectricalFinishedReveal {
  const ElectricalFinishedReveal({
    required this.startUMm,
    required this.endUMm,
    required this.geometrySnapshot,
    this.source = OpeningRevealSource.unspecified,
    this.uncertaintyMm,
    this.note = '',
  });

  final double startUMm, endUMm;
  final String geometrySnapshot;
  final OpeningRevealSource source;
  final double? uncertaintyMm;
  final String note;

  Map<String, dynamic> toJson() => {
    'startUMm': startUMm,
    'endUMm': endUMm,
    'geometrySnapshot': geometrySnapshot,
    'source': source.name,
    'uncertaintyMm': uncertaintyMm,
    'note': note,
  };

  factory ElectricalFinishedReveal.fromJson(Map<String, dynamic> j) =>
      ElectricalFinishedReveal(
        startUMm: (j['startUMm'] as num).toDouble(),
        endUMm: (j['endUMm'] as num).toDouble(),
        geometrySnapshot: j['geometrySnapshot'] as String? ?? '',
        source: OpeningRevealSource.values.firstWhere(
          (v) => v.name == j['source'],
          orElse: () => OpeningRevealSource.unspecified,
        ),
        uncertaintyMm: (j['uncertaintyMm'] as num?)?.toDouble(),
        note: j['note'] as String? ?? '',
      );
}
