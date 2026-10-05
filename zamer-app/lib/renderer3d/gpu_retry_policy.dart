import 'dart:math' as math;

/// Retry policy for first-load GPU/context failures.
///
/// The viewport must not spin forever when a device cannot create a GPU scene.
/// Automatic recovery is bounded; after the limit the UI can expose an
/// explicit manual retry without scheduling more background work.
class ZamerGpuRetryPolicy {
  const ZamerGpuRetryPolicy._();

  static const int automaticRetryLimit = 4;

  static bool shouldScheduleAutomaticRetry({
    required bool ready,
    required int retryAttempt,
  }) {
    if (ready) return false;
    final safeAttempt = math.max(0, retryAttempt);
    return safeAttempt < automaticRetryLimit;
  }

  static Duration delayForAttempt(int retryAttempt, {bool immediate = false}) {
    if (immediate) return Duration.zero;
    final safeAttempt = math.max(1, retryAttempt);
    return Duration(milliseconds: math.min(3200, 350 + safeAttempt * 350));
  }
}
