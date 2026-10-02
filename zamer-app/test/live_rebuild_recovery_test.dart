import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('failed live rebuild keeps the last valid GPU scene visible', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart')
        .readAsStringSync();
    final retryStart = source.indexOf('void _scheduleLiveRebuildRetry()');
    final rebuildStart = source.indexOf(
      'Future<void> _rebuildSceneAfterUpdate() async',
    );
    final rebuildEnd = source.indexOf('int _floorFingerprint()', rebuildStart);

    expect(retryStart, greaterThanOrEqualTo(0));
    expect(rebuildStart, greaterThan(retryStart));
    expect(rebuildEnd, greaterThan(rebuildStart));

    final retry = source.substring(retryStart, rebuildStart);
    final rebuild = source.substring(rebuildStart, rebuildEnd);
    expect(retry, contains('_retryTimer = Timer(delay'));
    expect(retry, contains('_rebuildSceneAfterUpdate();'));

    final keepOld = rebuild.indexOf('if (_ready && _scene != null)');
    final markFailed = rebuild.indexOf('_loadError = error;');
    expect(keepOld, greaterThanOrEqualTo(0));
    expect(markFailed, greaterThan(keepOld));

    final recoveryBranch = rebuild.substring(keepOld, markFailed);
    expect(recoveryBranch, contains('_scheduleLiveRebuildRetry();'));
    expect(recoveryBranch, contains('break;'));
    expect(recoveryBranch, isNot(contains('_ready = false')));
    expect(rebuild, contains('_retryAttempt = 0;'));
  });
}
