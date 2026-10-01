import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/zamer_gpu_viewport.dart';

void main() {
  test(
    'Photo Studio time presets are materially different lighting profiles',
    () {
      final day = zamerPhotoLightingProfile(ZamerPhotoTime.day);
      final sunset = zamerPhotoLightingProfile(ZamerPhotoTime.sunset);
      final evening = zamerPhotoLightingProfile(ZamerPhotoTime.evening);
      final night = zamerPhotoLightingProfile(ZamerPhotoTime.night);

      expect(
        day.environmentIntensity,
        greaterThan(sunset.environmentIntensity),
      );
      expect(
        sunset.environmentIntensity,
        greaterThan(evening.environmentIntensity),
      );
      expect(
        evening.environmentIntensity,
        greaterThan(night.environmentIntensity),
      );
      expect(sunset.temperature, greaterThan(day.temperature));
      expect(night.temperature, lessThan(0));
      expect(day.lightIntensity, greaterThan(night.lightIntensity));
      expect(day.backgroundTop, isNot(night.backgroundTop));
    },
  );

  test(
    'Photo Studio preview and export share real HDR, time and lens controls',
    () {
      final photo = File('lib/screens/photo_studio_screen.dart')
          .readAsStringSync();
      final gpu = File('lib/renderer3d/zamer_gpu_viewport.dart')
          .readAsStringSync();

      expect(photo.contains('photoPreview: true'), isTrue);
      expect(photo.contains('photoTime: _time'), isTrue);
      expect(photo.contains('photoHdr: _hdr'), isTrue);
      expect(photo.contains('cameraFovDegrees: _lensFov(_lens)'), isTrue);
      expect(photo.contains("<= 0.5 => 78"), isTrue);
      expect(photo.contains("<= 1.0 => 46"), isTrue);
      expect(photo.contains("<= 2.0 => 28"), isTrue);
      expect(photo.contains('_zoom = (widget.zoom * value)'), isFalse);

      expect(gpu.contains('final double cameraFovDegrees;'), isTrue);
      expect(
        gpu.contains('widget.cameraFovDegrees.clamp(18.0, 90.0).toDouble()'),
        isTrue,
      );
      expect(
        gpu.contains('screenSpaceReflectionsEnabled: exportQuality && hdr'),
        isTrue,
      );
      expect(
        gpu.contains('shadowMapResolution: exportQuality ? 2048 : 1024'),
        isTrue,
      );
      expect(
        gpu.contains('zamerPhotoLightingProfile(widget.photoTime)'),
        isTrue,
      );
    },
  );
}
