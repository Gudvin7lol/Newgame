import '../models/models.dart';

/// 2D scene compositing order only. It never changes the order saved in the
/// project nor changes collision volumes. Low seating parts are painted below
/// table/counter tops when a user slides a chair partly under a table.
class PlanObjectPaintOrder {
  const PlanObjectPaintOrder._();

  static int layer(PlanObject object) {
    final id = object.catalogId.toLowerCase();
    if (id.startsWith('rug-') || id == 'rug-2000x1400') return 0;
    if (id == 'chair' || id.startsWith('dining-chair') ||
        id == 'office-chair' || id == 'bar-stool' ||
        id.startsWith('stool-') || id.startsWith('ottoman')) return 1;
    if (id.startsWith('table-') || id.startsWith('dining-table') ||
        id.startsWith('coffee-table') || id == 'desk' ||
        id.startsWith('office-desk') || id.startsWith('kitchen-')) return 3;
    return 2;
  }

  static List<PlanObject> ordered(Iterable<PlanObject> objects) {
    final indexed = objects.toList(growable: false).asMap().entries.toList();
    indexed.sort((a, b) {
      final category = layer(a.value).compareTo(layer(b.value));
      return category != 0 ? category : a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList(growable: false);
  }
}
