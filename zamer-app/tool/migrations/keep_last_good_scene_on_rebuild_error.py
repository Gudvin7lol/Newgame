from pathlib import Path

VIEWPORT = Path('zamer-app/lib/renderer3d/zamer_gpu_viewport.dart')
TEST = Path('zamer-app/test/live_rebuild_recovery_test.dart')

text = VIEWPORT.read_text(encoding='utf-8')

method_start = text.find('  Future<void> _rebuildSceneAfterUpdate() async {')
method_end = text.find('\n\n  int _floorFingerprint()', method_start)
if method_start < 0 or method_end < 0:
    raise SystemExit('live rebuild method anchors not found')

replacement = r'''  void _scheduleLiveRebuildRetry() {
    if (!mounted) return;
    _retryTimer?.cancel();
    _retryAttempt++;
    final delay = Duration(
      milliseconds: math.min(2500, 250 + _retryAttempt * 250),
    );
    _retryTimer = Timer(delay, () {
      if (!mounted) return;
      _rebuildSceneAfterUpdate();
    });
  }

  Future<void> _rebuildSceneAfterUpdate() async {
    if (_liveRebuildInProgress) {
      _liveRebuildPending = true;
      return;
    }
    _liveRebuildInProgress = true;
    try {
      do {
        _liveRebuildPending = false;
        try {
          await _rebuildScene();
          if (!mounted) return;
          _retryTimer?.cancel();
          _retryAttempt = 0;
          if (!_ready && _loadError != null) {
            _scheduleRetry(immediate: true);
          }
        } catch (error) {
          if (!mounted) return;

          // A staged rebuild never touches the active scene until the new graph
          // is complete. If that preparation fails, keep the last good frame
          // visible and retry the latest floor state with backoff. Falling back
          // to a blank/error viewport here would throw away the very stability
          // benefit of staged scene replacement.
          if (_ready && _scene != null) {
            _liveRebuildPending = false;
            _scheduleLiveRebuildRetry();
            break;
          }

          setState(() {
            _loadError = error;
            _ready = false;
          });
          // There is no usable scene yet, so a full GPU initialization retry is
          // appropriate for first-load/context failures.
          _scheduleRetry(immediate: true);
        }
      } while (mounted && _liveRebuildPending);
    } finally {
      _liveRebuildInProgress = false;
    }
  }'''

text = text[:method_start] + replacement + text[method_end:]
VIEWPORT.write_text(text, encoding='utf-8')

TEST.parent.mkdir(parents=True, exist_ok=True)
TEST.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('failed live rebuild keeps the last valid GPU scene visible', () {
    final source = File('lib/renderer3d/zamer_gpu_viewport.dart').readAsStringSync();
    final retryStart = source.indexOf('void _scheduleLiveRebuildRetry()');
    final rebuildStart = source.indexOf('Future<void> _rebuildSceneAfterUpdate() async');
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
''', encoding='utf-8')

print('Live rebuild recovery applied.')
