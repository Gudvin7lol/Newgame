import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/models/electrical_network.dart';
import 'package:zamer_app/models/cost_entry.dart';
import 'package:zamer_app/models/material_purchase.dart';
import 'package:zamer_app/services/budget_service.dart';

void main() {
  test('one project keeps electric network, physical purchases and cash entries',
      () {
    final floor = FloorPlan(
      id: 'floor', name: 'Этаж',
      electricalNetwork: ElectricalNetwork(
        circuits: [
          ElectricalCircuitRecord(id: 'group', name: 'Розетки',
              kind: ElectricalCircuitKind.power),
        ],
      ),
    );
    final project = MeasureProject(
      id: 'one', name: 'Совместный объект', floors: [floor],
      costEntries: [
        CostEntry(
          id: 'pay', at: DateTime(2026, 10, 28),
          category: CostCategory.materials,
          description: 'Две пачки', amount: 2400, purchaseId: 'buy',
        ),
      ],
      materialPurchases: [
        MaterialPurchase(
          id: 'buy', at: DateTime(2026, 10, 28),
          estimateKey: 'laminate', quantity: 2, unit: 'пач.',
        ),
      ],
    );
    final restored = MeasureProject.fromJson(
      jsonDecode(jsonEncode(project.toJson())) as Map<String, dynamic>);
    expect(restored.floors.single.electricalNetwork!.circuits.single.id,
        'group');
    expect(restored.materialPurchases.single.quantity, 2);
    expect(restored.costEntries.single.purchaseId, 'buy');
    expect(BudgetService.review(restored).actualMaterials, 2400);
  });

  test('purchase calculations retain optional physical package capacity', () {
    const material = MaterialEstimate(
      name: 'Ламинат', quantity: 12, unit: 'м²',
      packages: 6, packageLabel: 'пач.',
      packageSize: 2.2,
    );
    expect(material.packageSize, 2.2);
    expect(material.packages, 6);
  });
}
