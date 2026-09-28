import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/services/object_catalog.dart';

void main() {
  test('v0.9 catalog object id survives JSON round trip', () {
    final item = ObjectCatalog.byId('bed-160');
    final object = PlanObject(
      id: 'o1',
      type: item.type,
      xMm: 1200,
      yMm: 900,
      widthMm: item.widthMm,
      depthMm: item.depthMm,
      heightMm: item.heightMm,
      catalogId: item.id,
      label: item.name,
    );
    final copy = PlanObject.fromJson(object.toJson());
    expect(copy.catalogId, 'bed-160');
    expect(copy.label, contains('Кровать'));
    expect(ObjectCatalog.byId(copy.catalogId).widthMm, 1700);
  });

  test('electrical frame orientation survives JSON', () {
    final point = ElectricalPoint(
      id: 'e1',
      type: ElectricalPointType.frame,
      xMm: 0,
      yMm: 0,
      frameVertical: true,
      modules: const [
        ElectricalModuleType.socket220,
        ElectricalModuleType.tv,
        ElectricalModuleType.data,
      ],
    );
    final copy = ElectricalPoint.fromJson(point.toJson());
    expect(copy.frameVertical, isTrue);
    expect(copy.modules.length, 3);
  });

  test('object catalog contains furniture, sanitary and heating models', () {
    expect(ObjectCatalog.items.any((e) => e.id == 'sofa-3'), isTrue);
    expect(ObjectCatalog.items.any((e) => e.id == 'toilet'), isTrue);
    expect(ObjectCatalog.items.any((e) => e.id == 'radiator'), isTrue);
  });
}
