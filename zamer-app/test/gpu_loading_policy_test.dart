import 'package:flutter_test/flutter_test.dart';
import 'package:zamer/renderer3d/gpu_loading_policy.dart';

void main() {
  test('first load is a preparing state without manual retry', () {
    final state = zamerGpuLoadingState(
      initializing: true,
      retryAttempt: 0,
      hasError: false,
    );

    expect(state.stage, ZamerGpuLoadingStage.preparing);
    expect(state.canRetry, isFalse);
    expect(state.attempt, 0);
  });

  test('transient GPU error remains an automatic recovery state', () {
    final state = zamerGpuLoadingState(
      initializing: false,
      retryAttempt: 2,
      hasError: true,
    );

    expect(state.stage, ZamerGpuLoadingStage.retrying);
    expect(state.canRetry, isTrue);
    expect(state.attempt, 2);
    expect(state.detail, contains('2'));
  });

  test('repeated failures expose an explicit manual recovery state', () {
    final state = zamerGpuLoadingState(
      initializing: false,
      retryAttempt: 4,
      hasError: true,
    );

    expect(state.stage, ZamerGpuLoadingStage.failed);
    expect(state.canRetry, isTrue);
    expect(state.title, '3D не запустился');
  });

  test('negative retry counters cannot leak into UI state', () {
    final state = zamerGpuLoadingState(
      initializing: false,
      retryAttempt: -3,
      hasError: false,
    );

    expect(state.stage, ZamerGpuLoadingStage.preparing);
    expect(state.attempt, 0);
  });
}
