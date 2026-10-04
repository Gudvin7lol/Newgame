import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/design_system/zamer_system_states.dart';
import 'package:zamer_app/design_system/zamer_theme.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ZamerTheme.dark,
      home: Scaffold(body: child),
    );

void main() {
  test('system state semantic colors stay distinct', () {
    expect(ZSystemStateKind.success.color, isNot(ZSystemStateKind.error.color));
    expect(ZSystemStateKind.warning.color, isNot(ZSystemStateKind.loading.color));
    expect(ZSystemStateKind.empty.icon, Icons.description_outlined);
  });

  testWidgets('empty project offers create and import actions', (tester) async {
    var created = false;
    var imported = false;
    await tester.pumpWidget(
      _host(
        ZEmptyProjectState(
          onCreateRoom: () => created = true,
          onImportPlan: () => imported = true,
        ),
      ),
    );

    expect(find.text('Начните с первого помещения'), findsOneWidget);
    expect(find.text('Создать помещение'), findsOneWidget);
    expect(find.text('Импортировать план'), findsOneWidget);

    await tester.tap(find.text('Создать помещение'));
    await tester.tap(find.text('Импортировать план'));
    expect(created, isTrue);
    expect(imported, isTrue);
  });

  testWidgets('3D loading exposes progress and remaining context', (tester) async {
    await tester.pumpWidget(
      _host(
        const ZThreeDLoadingState(
          progress: .68,
          remainingLabel: 'Осталось около 20 секунд',
        ),
      ),
    );

    expect(find.text('Строим сцену и материалы'), findsOneWidget);
    expect(find.text('68%'), findsOneWidget);
    expect(find.text('Осталось около 20 секунд'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('sync error keeps retry and local save recovery', (tester) async {
    var retried = false;
    var savedLocal = false;
    await tester.pumpWidget(
      _host(
        ZSyncErrorState(
          onRetry: () => retried = true,
          onSaveLocal: () => savedLocal = true,
        ),
      ),
    );

    expect(find.text('Не удалось сохранить изменения'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.tap(find.text('Сохранить локально'));
    expect(retried, isTrue);
    expect(savedLocal, isTrue);
  });

  testWidgets('ready state exposes open project and PDF actions', (tester) async {
    var opened = false;
    var pdf = false;
    await tester.pumpWidget(
      _host(
        ZProjectReadyState(
          onOpenProject: () => opened = true,
          onBuildPdf: () => pdf = true,
        ),
      ),
    );

    expect(find.text('Проект готов'), findsOneWidget);
    await tester.tap(find.text('Открыть проект'));
    await tester.tap(find.text('Собрать PDF'));
    expect(opened, isTrue);
    expect(pdf, isTrue);
  });

  testWidgets('inline state banner keeps one clear action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _host(
        ZSystemStateBanner(
          kind: ZSystemStateKind.error,
          title: 'Ошибка синхронизации',
          message: 'Изменения не сохранены',
          actionLabel: 'Повторить',
          onAction: () => retried = true,
        ),
      ),
    );

    expect(find.text('Ошибка синхронизации'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    expect(retried, isTrue);
  });
}
