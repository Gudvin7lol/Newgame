import 'dart:math' as math;
import 'dart:ui' as ui;

/// Small prefiltered alpha mask, shared by all instances of a catalog item.
/// The foreground artwork and its physical footprint remain untouched.
class TopViewContactShadow {
  TopViewContactShadow._(this.image, this.footprint);

  final ui.Image image;
  final ui.Rect footprint;

  int get decodedBytes => image.width * image.height * 4;

  static Future<TopViewContactShadow> create({
    required ui.Image source,
    required ui.Rect sourceRect,
    required double widthMm,
    required double depthMm,
    bool isRug = false,
  }) async {
    final scale = 256 / math.max(widthMm, depthMm);
    final width = (widthMm * scale).ceil();
    final depth = (depthMm * scale).ceil();
    final softSigma = math.max(.5, (isRug ? 5 : 28) * scale);
    final tightSigma = math.max(.35, 6 * scale);
    final padding = (softSigma * 4 + 2).ceil();
    final footprint = ui.Rect.fromLTWH(
      padding.toDouble(), padding.toDouble(),
      width.toDouble(), depth.toDouble(),
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    // Rasterize the silhouette first: a subsequent blur must not sample
    // neighboring furniture in a shared atlas.
    final maskRecorder = ui.PictureRecorder();
    ui.Canvas(maskRecorder).drawImageRect(
      source, sourceRect,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), depth.toDouble()),
      ui.Paint()
        // Nearest sampling cannot pull alpha from outside the source crop.
        // The cached mask is smoothed by the two blur passes below.
        ..filterQuality = ui.FilterQuality.none
        ..colorFilter = const ui.ColorFilter.mode(
          ui.Color(0xFF1C211E), ui.BlendMode.srcIn,
        ),
    );
    final maskPicture = maskRecorder.endRecording();
    final mask = await maskPicture.toImage(width, depth);
    maskPicture.dispose();
    try {
      canvas.drawImage(
        mask, footprint.topLeft,
        ui.Paint()
          ..color = ui.Color.fromRGBO(255, 255, 255, isRug ? .15 : .27)
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: softSigma, sigmaY: softSigma,
            tileMode: ui.TileMode.decal,
          ),
      );
      if (!isRug) {
        canvas.drawImage(
          mask, footprint.topLeft,
          ui.Paint()
            ..color = const ui.Color.fromRGBO(255, 255, 255, .19)
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: tightSigma, sigmaY: tightSigma,
              tileMode: ui.TileMode.decal,
            ),
        );
      }
      final picture = recorder.endRecording();
      try {
        return TopViewContactShadow._(
          await picture.toImage(width + padding * 2, depth + padding * 2),
          footprint,
        );
      } finally {
        picture.dispose();
      }
    } finally {
      mask.dispose();
    }
  }

  /// Paint in the same local coordinates as the object's foreground.
  /// Contact occlusion is symmetric, so rotating a chair cannot rotate a light.
  void paint(ui.Canvas canvas, ui.Rect destination) {
    final sx = destination.width / footprint.width;
    final sy = destination.height / footprint.height;
    final outer = ui.Rect.fromLTRB(
      destination.left - footprint.left * sx,
      destination.top - footprint.top * sy,
      destination.right + (image.width - footprint.right) * sx,
      destination.bottom + (image.height - footprint.bottom) * sy,
    );
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      outer,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }
}
