/// A purchase of physical material quantities, not a monetary payment.
/// Financial settlement is recorded separately in CostEntry. These two
/// histories must not be summed as money or treated as accepted work.
class MaterialPurchase {
  const MaterialPurchase({
    required this.id,
    required this.at,
    required this.estimateKey,
    required this.quantity,
    required this.unit,
    this.note = '',
    this.reversesId,
  });

  final String id, estimateKey, unit, note;
  final DateTime at;
  final double quantity;
  final String? reversesId;
  bool get isReversal => reversesId != null;
  double get signedQuantity => isReversal ? -quantity : quantity;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'estimateKey': estimateKey,
    'quantity': quantity,
    'unit': unit,
    'note': note,
    'reversesId': reversesId,
  };

  factory MaterialPurchase.fromJson(Map<String, dynamic> json) {
    final quantity = (json['quantity'] as num?)?.toDouble() ?? 0;
    if (!quantity.isFinite || quantity <= 0) {
      throw const FormatException('Некорректное количество закупки');
    }
    return MaterialPurchase(
      id: json['id']?.toString() ?? '',
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
      estimateKey: json['estimateKey']?.toString() ?? '',
      quantity: quantity,
      unit: json['unit']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      reversesId: json['reversesId']?.toString(),
    );
  }
}
