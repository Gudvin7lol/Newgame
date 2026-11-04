/// User-entered manufacturer/installation limits for ONE junction box.
/// No default numerical capacity is inferred from diameter or appearance.
/// A passing comparison does NOT prove installation or code compliance.
class ElectricalJunctionCapacity {
  const ElectricalJunctionCapacity({
    required this.junctionPointId,
    this.boxModel = '',
    this.maxCableEntries,
    this.maxConductorEnds,
    this.maxConnectorCount,
    this.maxEndsPerConnector,
    this.note = '',
  });

  final String junctionPointId, boxModel, note;
  final int? maxCableEntries;
  final int? maxConductorEnds;
  final int? maxConnectorCount;
  final int? maxEndsPerConnector;

  void validate() {
    if (junctionPointId.trim().isEmpty ||
        [maxCableEntries, maxConductorEnds, maxConnectorCount,
          maxEndsPerConnector].whereType<int>()
            .any((v) => v < 1 || v > 10000)) {
      throw const FormatException('Проверьте ограничения вместимости РК.');
    }
  }

  bool get hasEnteredLimits => [
    maxCableEntries, maxConductorEnds,
    maxConnectorCount, maxEndsPerConnector,
  ].any((value) => value != null);

  Map<String, dynamic> toJson() => {
    'junctionPointId': junctionPointId,
    'boxModel': boxModel,
    'maxCableEntries': maxCableEntries,
    'maxConductorEnds': maxConductorEnds,
    'maxConnectorCount': maxConnectorCount,
    'maxEndsPerConnector': maxEndsPerConnector,
    'note': note,
  };

  factory ElectricalJunctionCapacity.fromJson(Map<String, dynamic> json) {
    final item = ElectricalJunctionCapacity(
      junctionPointId: json['junctionPointId'] as String,
      boxModel: json['boxModel'] as String? ?? '',
      maxCableEntries: (json['maxCableEntries'] as num?)?.toInt(),
      maxConductorEnds: (json['maxConductorEnds'] as num?)?.toInt(),
      maxConnectorCount: (json['maxConnectorCount'] as num?)?.toInt(),
      maxEndsPerConnector: (json['maxEndsPerConnector'] as num?)?.toInt(),
      note: json['note'] as String? ?? '',
    );
    item.validate();
    return item;
  }
}
