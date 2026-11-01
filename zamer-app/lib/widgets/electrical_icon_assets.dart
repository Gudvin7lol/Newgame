import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../design_system/zamer_electric_glass.dart';

ZamerElectricKind electricIconKind(ElectricalPointType type) => switch (type) {
  ElectricalPointType.socket || ElectricalPointType.frame => ZamerElectricKind.socket,
  ElectricalPointType.switchPoint => ZamerElectricKind.switchPoint,
  ElectricalPointType.ceilingLight || ElectricalPointType.wallLight => ZamerElectricKind.light,
  ElectricalPointType.tvSocket => ZamerElectricKind.tv,
  ElectricalPointType.dataSocket => ZamerElectricKind.internet,
  ElectricalPointType.panel => ZamerElectricKind.board,
  ElectricalPointType.junctionBox => ZamerElectricKind.box,
  ElectricalPointType.appliance => ZamerElectricKind.cableOutlet,
};

/// Owned by one editor; decoded once, never during paint.
class ElectricalIconAssets {
  final images = <ZamerElectricKind, ui.Image>{};
  bool _disposed = false;

  Future<void> load() async {
    for (final kind in ZamerElectricKind.values) {
      if (_disposed) return;
      final name = ZamerElectricIcon.names[kind]!.$1;
      final data = await rootBundle.load('assets/electric/icons/${name}_plan.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(
          data.offsetInBytes, data.lengthInBytes));
      try {
        final frame = await codec.getNextFrame();
        if (_disposed) { frame.image.dispose(); return; }
        images[kind] = frame.image;
      } finally { codec.dispose(); }
    }
  }

  void dispose() {
    _disposed = true;
    for (final image in images.values) { image.dispose(); }
    images.clear();
  }
}
