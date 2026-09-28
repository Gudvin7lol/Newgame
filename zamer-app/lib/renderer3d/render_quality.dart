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
    ZamerRenderQuality.interactive => 'Интерактив',
    ZamerRenderQuality.high => 'Высокое',
    ZamerRenderQuality.ultra4k => '4K',
  };
}
