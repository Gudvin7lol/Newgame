import 'package:flutter/material.dart';

import 'zamer_system_states.dart';

/// Compatibility adapter. Existing screens keep their current call sites while
/// inheriting the Master Concept system-state language.
class ZLoadingState extends StatelessWidget {
  const ZLoadingState({
    super.key,
    required this.title,
    this.subtitle,
    this.progress,
  });

  final String title;
  final String? subtitle;
  final double? progress;

  @override
  Widget build(BuildContext context) => ZSystemStateView(
        kind: ZSystemStateKind.loading,
        title: title,
        message: subtitle ?? 'Подготавливаем данные. Это займёт немного времени.',
        progress: progress,
      );
}

class ZEmptyState extends StatelessWidget {
  const ZEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => ZSystemStateView(
        kind: ZSystemStateKind.empty,
        icon: icon,
        title: title,
        message: subtitle,
        primaryLabel: actionLabel,
        onPrimary: onAction,
      );
}

class ZErrorState extends StatelessWidget {
  const ZErrorState({
    super.key,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ZSystemStateView(
        kind: ZSystemStateKind.error,
        title: title,
        message: subtitle,
        primaryLabel: onRetry == null ? null : 'Повторить',
        onPrimary: onRetry,
      );
}

class ZSuccessState extends StatelessWidget {
  const ZSuccessState({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.preview,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget? preview;

  @override
  Widget build(BuildContext context) => ZSystemStateView(
        kind: ZSystemStateKind.success,
        title: title,
        message: subtitle,
        primaryLabel: actionLabel,
        onPrimary: onAction,
        secondaryLabel: secondaryLabel,
        onSecondary: onSecondary,
        preview: preview,
      );
}

class ZWarningState extends StatelessWidget {
  const ZWarningState({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => ZSystemStateView(
        kind: ZSystemStateKind.warning,
        title: title,
        message: subtitle,
        primaryLabel: actionLabel,
        onPrimary: onAction,
        secondaryLabel: secondaryLabel,
        onSecondary: onSecondary,
      );
}
