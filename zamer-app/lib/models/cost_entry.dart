/// An actual paid cost, independent from estimates or scheduled progress.
/// Existing records keep their values after geometry or rates change.
enum CostCategory { materials, labor }

class CostEntry {
  const CostEntry({
    required this.id,
    required this.at,
    required this.category,
    required this.description,
    required this.amount,
    this.taskId,
    this.estimateKey,
    this.reversesId,
  });

  final String id;
  final DateTime at;
  final CostCategory category;
  final String description;
  final double amount;
  /// Link to a WorkTask for attributable labor payments, if known.
  final String? taskId;
  /// Link to an estimate row, stable across display-name changes when possible.
  final String? estimateKey;
  /// Non-null for a compensating record. Paid originals are not rewritten.
  final String? reversesId;
  bool get isReversal => reversesId != null;
  double get signedAmount => isReversal ? -amount : amount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'category': category.name,
    'description': description,
    'amount': amount,
    'taskId': taskId,
    'estimateKey': estimateKey,
    'reversesId': reversesId,
  };

  factory CostEntry.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category']?.toString();
    final amount = (json['amount'] as num?)?.toDouble() ?? 0;
    if (!amount.isFinite || amount <= 0) {
      throw const FormatException('Некорректная сумма фактического расхода');
    }
    return CostEntry(
      id: json['id']?.toString() ?? '',
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
      category: rawCategory == CostCategory.labor.name
          ? CostCategory.labor : CostCategory.materials,
      description: json['description']?.toString() ?? '',
      amount: amount,
      taskId: json['taskId']?.toString(),
      estimateKey: json['estimateKey']?.toString(),
      reversesId: json['reversesId']?.toString(),
    );
  }
}
