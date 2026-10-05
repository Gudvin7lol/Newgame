import 'package:flutter/material.dart';

import 'gpu_loading_policy.dart';

/// Stable loading/recovery surface for the GPU viewport.
///
/// Keeping this widget independent from Flutter Scene means a failed GPU
/// context cannot take the recovery controls down with it.
class ZamerGpuLoadingOverlay extends StatelessWidget {
  const ZamerGpuLoadingOverlay({
    super.key,
    required this.state,
    required this.onRetry,
  });

  final ZamerGpuLoadingState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = state.stage == ZamerGpuLoadingStage.failed;
    return ColoredBox(
      color: const Color(0xFFF3F5F7),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (failed)
                  const Icon(Icons.warning_amber_rounded, size: 34)
                else
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                const SizedBox(height: 14),
                Text(
                  state.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.detail,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (state.canRetry) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const ValueKey('gpu-retry'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Повторить запуск 3D'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
