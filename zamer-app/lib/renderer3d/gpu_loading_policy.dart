/// Pure state policy for the 3D viewport startup/retry UI.
///
/// Keeping this independent from Flutter Scene makes retry behaviour testable
/// without a GPU context and prevents transient initialization failures from
/// looking like a permanent crash to the user.
enum ZamerGpuLoadingStage { preparing, retrying, failed }

class ZamerGpuLoadingState {
  const ZamerGpuLoadingState({
    required this.stage,
    required this.attempt,
    required this.canRetry,
  });

  final ZamerGpuLoadingStage stage;
  final int attempt;
  final bool canRetry;

  String get title => switch (stage) {
        ZamerGpuLoadingStage.preparing => 'Подготавливаем 3D',
        ZamerGpuLoadingStage.retrying => 'Восстанавливаем 3D',
        ZamerGpuLoadingStage.failed => '3D не запустился',
      };

  String get detail => switch (stage) {
        ZamerGpuLoadingStage.preparing =>
          'Создаём GPU-сцену и загружаем материалы…',
        ZamerGpuLoadingStage.retrying =>
          'Повторная инициализация GPU, попытка $attempt…',
        ZamerGpuLoadingStage.failed =>
          'Автовосстановление не помогло. Можно повторить запуск GPU.',
      };
}

ZamerGpuLoadingState zamerGpuLoadingState({
  required bool initializing,
  required int retryAttempt,
  required bool hasError,
  int automaticRetryLimit = 4,
}) {
  final safeAttempt = retryAttempt < 0 ? 0 : retryAttempt;
  if (hasError && safeAttempt >= automaticRetryLimit) {
    return ZamerGpuLoadingState(
      stage: ZamerGpuLoadingStage.failed,
      attempt: safeAttempt,
      canRetry: true,
    );
  }
  if (hasError || safeAttempt > 0) {
    return ZamerGpuLoadingState(
      stage: ZamerGpuLoadingStage.retrying,
      attempt: safeAttempt == 0 ? 1 : safeAttempt,
      canRetry: !initializing,
    );
  }
  return ZamerGpuLoadingState(
    stage: ZamerGpuLoadingStage.preparing,
    attempt: 0,
    canRetry: false,
  );
}
