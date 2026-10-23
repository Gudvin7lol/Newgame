import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invalid node-drag release restores original room and skips saving', () {
    final source = File('lib/screens/plan_editor_master_v4_screen.dart')
        .readAsStringSync();
    final end = source.indexOf('Future<void> _nodeDragEnd(');
    final cancel = source.indexOf('void _nodeDragCancel()', end);
    expect(end, greaterThanOrEqualTo(0));
    expect(cancel, greaterThan(end));
    final code = source.substring(end, cancel);
    final invalidGuard = code.indexOf('if (rejected != null)');
    final restored = code.indexOf('floor.restoreFrom(beforeDrag)', invalidGuard);
    final returnAfterRollback = code.indexOf('return;', restored);
    final commit = code.indexOf('await _changed()', invalidGuard);
    expect(invalidGuard, greaterThanOrEqualTo(0));
    expect(restored, greaterThan(invalidGuard));
    expect(returnAfterRollback, greaterThan(restored));
    expect(commit, greaterThan(returnAfterRollback),
        reason: 'An invalid release must not persist an intermediate position');
    expect(code, contains('Перемещение отменено'));
  });
}
