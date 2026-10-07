import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/design_system/zamer_components.dart';

void main() {
  testWidgets('ZPanel provides Material for list-tile based controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZPanel(
            child: SwitchListTile.adaptive(
              title: const Text('Плитка на этой стене'),
              value: true,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Плитка на этой стене'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
