import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/design_system/zamer_components.dart';
import 'package:zamer_app/design_system/zamer_theme.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ZamerTheme.dark,
      home: Scaffold(
        body: SizedBox(width: 390, height: 844, child: child),
      ),
    );

void main() {
  testWidgets('empty project state exposes create and import actions', (
    tester,
  ) async {
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
    await tester.tap(find.text('Создать помещение'));
    expect(created, isTrue);
    await tester.tap(find.text('Импортировать план'));
    expect(imported, isTrue);
  });

  testWidgets('3D loading state shows progress and remaining time', (
    tester,
  ) async {
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
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('sync error keeps retry and local-save recovery actions', (
    tester,
  ) async {
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
    expect(retried, isTrue);
    await tester.tap(find.text('Сохранить локально'));
    expect(savedLocal, isTrue);
  });

  testWidgets('success and warning states share the same Master language', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ZSuccessState(
          title: 'Готово',
          subtitle: 'Проект успешно обработан.',
        ),
      ),
    );
    expect(find.text('Готово'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pumpWidget(
      _host(
        const ZWarningState(
          title: 'Проверьте размеры',
          subtitle: 'Есть потенциальная проблема, работа не заблокирована.',
        ),
      ),
    );
    expect(find.text('Проверьте размеры'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('legacy loading and empty calls inherit the new system view', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ZLoadingState(
          title: 'Загружаем проекты',
          progress: .5,
        ),
      ),
    );
    expect(find.byType(ZSystemStateView), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        const ZEmptyState(
          icon: Icons.home_work_outlined,
          title: 'Пока пусто',
          subtitle: 'Добавьте первый элемент.',
        ),
      ),
    );
    expect(find.byType(ZSystemStateView), findsOneWidget);
    expect(find.text('Пока пусто'), findsOneWidget);
  });
}
