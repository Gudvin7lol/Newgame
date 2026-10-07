/// Render quality levels shared by realtime 3D and Photo Render.
///
/// Product naming follows the approved UI specification:
/// Performance = fastest realtime mode, Quality = normal high-quality realtime,
/// Photo = final still render at true 4K.
enum ZamerRenderQuality { interactive, high, ultra4k }

extension ZamerRenderQualitySpec on ZamerRenderQuality {
  int get width => switch (this) {
    ZamerRenderQuality.interactive => 0,
    ZamerRenderQuality.high => 2560,
    ZamerRenderQuality.ultra4k => 3840,
  };

  int get height => switch (this) {
    ZamerRenderQuality.interactive => 0,
    ZamerRenderQuality.high => 1440,
    ZamerRenderQuality.ultra4k => 2160,
  };

  String get label => switch (this) {
    ZamerRenderQuality.interactive => 'Performance',
    ZamerRenderQuality.high => 'Quality',
    ZamerRenderQuality.ultra4k => 'Photo',
  };

  String get description => switch (this) {
    ZamerRenderQuality.interactive => 'Быстрый режим для слабых устройств',
    ZamerRenderQuality.high => 'Основной realtime-режим',
    ZamerRenderQuality.ultra4k => 'Финальный рендер 3840×2160',
  };

  bool get isPhoto => this == ZamerRenderQuality.ultra4k;
}
