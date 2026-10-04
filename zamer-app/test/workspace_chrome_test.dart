import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/design_system/zamer_theme.dart';
import 'package:zamer_app/design_system/zamer_tokens.dart';
import 'package:zamer_app/widgets/workspace_mode_context.dart';
import 'package:zamer_app/widgets/workspace_navigation.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ZamerTheme.dark,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('master navigation keeps the five approved pages', (
    tester,
  ) async {
    var selected = -1;
    var homePressed = false;
    var profilePressed = false;

    await tester.pumpWidget(
      _host(
        Align(
          alignment: Alignment.bottomCenter,
          child: ZWorkspacePrimaryNav(
            selectedIndex: 0,
            onSelected: (value) => selected = value,
            onHome: () => homePressed = true,
            onProfile: () => profilePressed = true,
          ),
        ),
      ),
    );

    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('Замер'), findsOneWidget);
    expect(find.text('3D'), findsOneWidget);
    expect(find.text('Развёртки'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);

    await tester.tap(find.text('3D'));
    expect(selected, 1);

    await tester.tap(find.text('Главная'));
    expect(homePressed, isTrue);

    await tester.tap(find.text('Профиль'));
    expect(profilePressed, isTrue);
  });

  testWidgets('primary app nav uses Master size and routes every destination', (
    tester,
  ) async {
    var destination = -1;
    await tester.pumpWidget(
      _host(
        Align(
          alignment: Alignment.bottomCenter,
          child: ZPrimaryAppNav(
            selectedIndex: 3,
            onHome: () => destination = 0,
            onMeasure: () => destination = 1,
            on3D: () => destination = 2,
            onElevations: () => destination = 3,
            onProfile: () => destination = 4,
          ),
        ),
      ),
    );

    expect(find.byType(ZPrimaryAppNav), findsOneWidget);
    expect(find.text('Развёртки'), findsOneWidget);

    await tester.tap(find.text('Профиль'));
    expect(destination, 4);
    await tester.tap(find.text('Главная'));
    expect(destination, 0);

    final navSize = tester.getSize(find.byType(ZPrimaryAppNav));
    expect(navSize.height, greaterThanOrEqualTo(ZamerSize.bottomNavigation));
  });

  testWidgets('workspace subnavigation selects its working page', (
    tester,
  ) async {
    var selected = -1;
    await tester.pumpWidget(
      _host(
        ZWorkspaceSubnav(
          items: const [
            ('Электрика', Icons.electrical_services_outlined),
            ('Объекты', Icons.chair_alt_outlined),
            ('Инженерия', Icons.plumbing_outlined),
          ],
          selectedIndex: 1,
          onSelected: (value) => selected = value,
        ),
      ),
    );

    expect(find.text('Электрика'), findsOneWidget);
    expect(find.text('Объекты'), findsOneWidget);
    expect(find.text('Инженерия'), findsOneWidget);

    await tester.tap(find.text('Инженерия'));
    expect(selected, 2);
  });

  testWidgets('context strip exposes current mode and project metrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ZWorkspaceContextStrip(
          icon: Icons.architecture_outlined,
          title: 'Обмер и геометрия',
          subtitle: 'Стены, помещения, проёмы и контроль размеров',
          metrics: [
            ZWorkspaceMetric(
              icon: Icons.architecture_outlined,
              value: 'План',
              emphasized: true,
            ),
            ZWorkspaceMetric(
              icon: Icons.square_foot_outlined,
              value: '8',
              label: 'стен',
            ),
            ZWorkspaceMetric(
              icon: Icons.grid_view_outlined,
              value: '2',
              label: 'пом.',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Обмер и геометрия'), findsOneWidget);
    expect(find.text('План'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('стен'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('пом.'), findsOneWidget);
  });
}
