import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/design_system/zamer_graphics_selector.dart';
import 'package:zamer_app/design_system/zamer_theme.dart';
import 'package:zamer_app/widgets/projects_home_widgets.dart';
import 'package:zamer_app/widgets/workspace_navigation.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ZamerTheme.dark,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('home navigation exposes the five master pages', (tester) async {
    await tester.pumpWidget(
      _host(
        ZHomeNavBar(
          onProjects: () {},
          onCatalog: () {},
          onLearn: () {},
          onMore: () {},
        ),
      ),
    );

    for (final label in const [
      'Главная',
      'Замер',
      '3D',
      'Оснащение',
      'Развёртки',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('workspace navigation matches the master page contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ZWorkspacePrimaryNav(
          selectedIndex: 1,
          onSelected: (_) {},
          onHome: () {},
        ),
      ),
    );

    for (final label in const [
      'Главная',
      'Замер',
      '3D',
      'Оснащение',
      'Развёртки',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('graphics selector keeps Performance Quality Photo modes', (
    tester,
  ) async {
    var selected = ZGraphicsMode.quality;

    await tester.pumpWidget(
      MaterialApp(
        theme: ZamerTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: ZGraphicsModeSelector(
                value: selected,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Performance'), findsOneWidget);
    expect(find.text('Quality'), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);

    await tester.tap(find.text('Photo'));
    await tester.pump();
    expect(selected, ZGraphicsMode.photo);
  });
}
