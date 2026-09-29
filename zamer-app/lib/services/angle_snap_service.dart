class AngleSnapService {
  const AngleSnapService._();

  /// Magnetically snaps a free rotation to the nearest quarter turn when the
  /// gesture is close enough. Values outside the threshold remain untouched,
  /// so two-finger rotation still feels continuous instead of jumping between
  /// 90-degree sectors.
  static double snapQuarterTurn(
    double angleDeg, {
    double thresholdDeg = 8,
  }) {
    if (!angleDeg.isFinite || !thresholdDeg.isFinite || thresholdDeg < 0) {
      return angleDeg;
    }
    final nearest = (angleDeg / 90).round() * 90.0;
    return (angleDeg - nearest).abs() <= thresholdDeg ? nearest : angleDeg;
  }

  static bool isQuarterTurnSnapped(
    double angleDeg, {
    double epsilonDeg = 0.001,
  }) {
    if (!angleDeg.isFinite) return false;
    final nearest = (angleDeg / 90).round() * 90.0;
    return (angleDeg - nearest).abs() <= epsilonDeg;
  }
}
