import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/gpu_retry_policy.dart';

void main() {
  group('ZamerGpuRetryPolicy', () {
    test('allows only the bounded automatic retry budget', () {
      expect(
        ZamerGpuRetryPolicy.shouldScheduleAutomaticRetry(
          ready: false,
          retryAttempt: 0,
        ),
        isTrue,
      );
      expect(
        ZamerGpuRetryPolicy.shouldScheduleAutomaticRetry(
          ready: false,
          retryAttempt: ZamerGpuRetryPolicy.automaticRetryLimit - 1,
        ),
        isTrue,
      );
      expect(
        ZamerGpuRetryPolicy.shouldScheduleAutomaticRetry(
          ready: false,
          retryAttempt: ZamerGpuRetryPolicy.automaticRetryLimit,
        ),
        isFalse,
      );
    });

    test('never retries automatically after a usable scene is ready', () {
      expect(
        ZamerGpuRetryPolicy.shouldScheduleAutomaticRetry(
          ready: true,
          retryAttempt: 0,
        ),
        isFalse,
      );
    });

    test('backoff is deterministic and capped', () {
      expect(ZamerGpuRetryPolicy.delayForAttempt(1), const Duration(milliseconds: 700));
      expect(ZamerGpuRetryPolicy.delayForAttempt(2), const Duration(milliseconds: 1050));
      expect(ZamerGpuRetryPolicy.delayForAttempt(100), const Duration(milliseconds: 3200));
      expect(
        ZamerGpuRetryPolicy.delayForAttempt(100, immediate: true),
        Duration.zero,
      );
    });
  });
}
