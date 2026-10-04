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

/// Master Concept 08: empty project with one dominant and one alternative step.
class ZEmptyProjectState extends StatelessWidget {
  const ZEmptyProjectState({
    super.key,
    required this.onCreate,
    required this.onImport,
  });

  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => ZSystemStateView(
        kind: ZSystemStateKind.empty,
        icon: Icons.add_home_work_outlined,
        title: 'Начните с первого помещения',
        message: 'Добавьте помещение вручную или импортируйте план, чтобы начать замеры.',
        primaryLabel: 'Создать помещение',
        onPrimary: onCreate,
        secondaryLabel: 'Импортировать план',
        onSecondary: onImport,
      );
}

/// Master Concept 08: 3D preparation state with explicit progress and ETA.
class Z3DLoadingState extends StatelessWidget {
  const Z3DLoadingState({
    super.key,
    this.progress,
    this.remainingLabel,
  });

  final double? progress;
  final String? remainingLabel;

  @override
  Widget build(BuildContext context) => ZSystemStateView(
        kind: ZSystemStateKind.loading,
        title: 'Строим сцену и материалы',
        message: 'Подготавливаем геометрию, текстуры и освещение. Это займёт немного времени.',
        progress: progress,
        remainingLabel: remainingLabel,
      );
}

/// Master Concept 08: recoverable save/sync failure.
class ZSyncErrorState extends StatelessWidget {
  const ZSyncErrorState({
    super.key,
    required this.onRetry,
    required this.onSaveLocal,
    this.title = 'Не удалось сохранить изменения',
    this.message = 'Проверьте подключение и попробуйте снова. Проект можно сохранить локально.',
  });

  final VoidCallback onRetry;
  final VoidCallback onSaveLocal;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => ZSystemStateView(
        kind: ZSystemStateKind.error,
        title: title,
        message: message,
        primaryLabel: 'Повторить',
        onPrimary: onRetry,
        secondaryLabel: 'Сохранить локально',
        onSecondary: onSaveLocal,
      );
}

/// Master Concept 08: finished processing with a clear next step and PDF action.
class ZProjectReadyState extends StatelessWidget {
  const ZProjectReadyState({
    super.key,
    required this.onOpen,
    required this.onPdf,
    this.preview,
  });

  final VoidCallback onOpen;
  final VoidCallback onPdf;
  final Widget? preview;

  @override
  Widget build(BuildContext context) => ZSystemStateView(
        kind: ZSystemStateKind.success,
        title: 'Проект готов',
        message: '3D-модель и чертежи собраны. Можно открыть проект или экспортировать документацию.',
        primaryLabel: 'Открыть проект',
        onPrimary: onOpen,
        secondaryLabel: 'Собрать PDF',
        onSecondary: onPdf,
        preview: preview,
      );
}
