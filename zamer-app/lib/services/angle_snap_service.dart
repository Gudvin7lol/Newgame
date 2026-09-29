class AngleSnapService {
  const AngleSnapService._();

  static double _angularDistance(double a, double b) {
    final wrapped = ((a - b + 180) % 360 + 360) % 360 - 180;
    return wrapped.abs();
  }

  /// Magnetically snaps a free rotation to the nearest quarter turn when the
  /// gesture is close enough. Values outside the threshold remain untouched,
  /// so two-finger rotation still feels continuous instead of jumping between
  /// 90-degree sectors.
  static double snapQuarterTurn(double angleDeg, {double thresholdDeg = 8}) {
    return snapQuarterTurnWithLock(
      angleDeg,
      engageThresholdDeg: thresholdDeg,
      releaseThresholdDeg: thresholdDeg,
    ).angleDeg;
  }

  /// Stateful-friendly quarter-turn snapping with hysteresis.
  ///
  /// Once a gesture has locked to 0/90/180/270 it stays locked until the raw
  /// angle moves beyond [releaseThresholdDeg]. This avoids the visible jitter
  /// caused by repeatedly entering and leaving one threshold at the edge.
  static ({double angleDeg, double? lockedAngleDeg}) snapQuarterTurnWithLock(
    double angleDeg, {
    double? lockedAngleDeg,
    double engageThresholdDeg = 7,
    double releaseThresholdDeg = 12,
  }) {
    if (!angleDeg.isFinite ||
        !engageThresholdDeg.isFinite ||
        !releaseThresholdDeg.isFinite ||
        engageThresholdDeg < 0 ||
        releaseThresholdDeg < 0) {
      return (angleDeg: angleDeg, lockedAngleDeg: null);
    }
    final release = releaseThresholdDeg < engageThresholdDeg
        ? engageThresholdDeg
        : releaseThresholdDeg;
    if (lockedAngleDeg != null &&
        lockedAngleDeg.isFinite &&
        _angularDistance(angleDeg, lockedAngleDeg) <= release) {
      return (angleDeg: lockedAngleDeg, lockedAngleDeg: lockedAngleDeg);
    }

    final nearest = (angleDeg / 90).round() * 90.0;
    if (_angularDistance(angleDeg, nearest) <= engageThresholdDeg) {
      return (angleDeg: nearest, lockedAngleDeg: nearest);
    }
    return (angleDeg: angleDeg, lockedAngleDeg: null);
  }

  static bool isQuarterTurnSnapped(
    double angleDeg, {
    double epsilonDeg = 0.001,
  }) {
    if (!angleDeg.isFinite) return false;
    final nearest = (angleDeg / 90).round() * 90.0;
    return _angularDistance(angleDeg, nearest) <= epsilonDeg;
  }
}
