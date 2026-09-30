import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measurement review exposes production issue filters', () {
    final source = File(
      'lib/screens/measurement_review_screen.dart',
    ).readAsStringSync();

    for (final required in const [
      'MeasurementIssueKind? _filter',
      'Незамкнутый контур',
      'Несоответствие размеров',
      'Отступ проёма не подтверждён',
      'Высота не подтверждена',
      'Нет контрольной диагонали',
      '_FilterChip(',
      'ZPressEffect(',
    ]) {
      expect(
        source.contains(required),
        isTrue,
        reason: 'Missing geometry review production element: $required',
      );
    }
  });
}
