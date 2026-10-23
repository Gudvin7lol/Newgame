import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/models/models.dart';
import 'package:zamer_app/widgets/cad_contact_shadow_painter.dart';

Future<ui.Image> _shadowImage(double elevationMm) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    const Rect.fromLTWH(0, 0, 160, 160),
  );
  CadContactShadowPainter.drawObject(
    canvas,
    PlanObject(
      id: 'test-furniture',
      catalogId: 'wardrobe-3',
      type: PlanObjectType.furniture,
      xMm: 0,
      yMm: 0,
      widthMm: 800,
      depthMm: 600,
      heightMm: 1800,
      elevationMm: elevationMm,
      rotationDeg: 45,
    ),
    center: const Offset(80, 80),
    mmToPx: .1,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(160, 160);
  } finally {
    picture.dispose();
  }
}

Future<int> _centerAlpha(ui.Image image) async {
  final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return pixels.getUint8(((80 * 160) + 80) * 4 + 3);
}

void main() {
  test('floor-mounted furniture has a single contact shadow', () async {
    final image = await _shadowImage(0);
    try {
      expect(await _centerAlpha(image), greaterThan(0));
    } finally {
      image.dispose();
    }
  });

  test('elevated wall-hung furniture does not shadow the floor', () async {
    final image = await _shadowImage(1200);
    try {
      expect(await _centerAlpha(image), 0);
    } finally {
      image.dispose();
    }
  });

  test('10-mm elevation is still grounded but 11-mm is not', () async {
    final onFloor = await _shadowImage(10);
    final raised = await _shadowImage(11);
    try {
      expect(await _centerAlpha(onFloor), greaterThan(0));
      expect(await _centerAlpha(raised), 0);
    } finally {
      onFloor.dispose();
      raised.dispose();
    }
  });
}
