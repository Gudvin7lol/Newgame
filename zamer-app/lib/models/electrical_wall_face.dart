/// Evidence for a wall-face finish thickness. Unknown is distinct from 0 mm.
enum WallFinishSource { unknown, design, document, measured }

/// Explicit finish build-up outside the structural wall core, on one side.
/// The core width still comes from PlanWall.thicknessMm and must be surveyed
/// separately; no implied confirmation of a wall's thickness is stored here.
class WallFaceFinish {
  const WallFaceFinish({
    required this.thicknessMm,
    this.source = WallFinishSource.unknown,
    this.note = '',
  });
  final double thicknessMm;
  final WallFinishSource source;
  final String note;

  Map<String, dynamic> toJson() => {
    'thicknessMm': thicknessMm,
    'source': source.name,
    'note': note,
  };

  factory WallFaceFinish.fromJson(Map<String, dynamic> data) =>
      WallFaceFinish(
        thicknessMm: (data['thicknessMm'] as num).toDouble(),
        source: WallFinishSource.values.firstWhere(
          (s) => s.name == data['source'],
          orElse: () => WallFinishSource.unknown,
        ),
        note: data['note'] as String? ?? '',
      );
}
