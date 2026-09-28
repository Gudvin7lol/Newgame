import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../services/device_diagnostics.dart';

class DeviceDiagnosticsScreen extends StatefulWidget {
  const DeviceDiagnosticsScreen({super.key, required this.projects});
  final List<MeasureProject> projects;

  @override
  State<DeviceDiagnosticsScreen> createState() =>
      _DeviceDiagnosticsScreenState();
}

class _DeviceDiagnosticsScreenState extends State<DeviceDiagnosticsScreen> {
  final _results = <DiagnosticResult>[];
  bool _running = false;
  String _current = '';

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _results.clear();
    });
    final steps = <(String, Future<DiagnosticResult> Function())>[
      ('Перегородка и комнаты', DeviceDiagnostics.geometry),
      ('Формат и привязка покрытия', DeviceDiagnostics.layout),
      ('Отрисовка покрытий', DeviceDiagnostics.floorRender),
      ('Отрисовка 3D', DeviceDiagnostics.sceneRender),
      ('Обмер, трубы, ZIP и PDF', DeviceDiagnostics.projectRoundTrip),
      (
        'Проверка сохранённых планов',
        () => DeviceDiagnostics.projectAudit(widget.projects),
      ),
    ];
    try {
      for (final (name, task) in steps) {
        if (!mounted) return;
        setState(() => _current = name);
        final result = await task();
        if (!mounted) return;
        setState(() => _results.add(result));
      }
    } finally {
      if (mounted)
        setState(() {
          _running = false;
          _current = '';
        });
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: DeviceDiagnostics.report(_results)),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отчёт скопирован. Вставь его в чат.')),
      );
    }
  }

  Future<void> _share() async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      DeviceDiagnostics.report(_results),
      subject: 'Замер — проверка на телефоне',
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Проверка на телефоне')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Запусти проверку на этом телефоне. Она не меняет проекты: проверяет геометрию, форматы покрытий, отрисовку и сохранённые планы.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _running ? null : _run,
          icon: const Icon(Icons.play_arrow),
          label: Text(_running ? 'Проверяю: $_current' : 'Запустить проверку'),
        ),
        if (_running) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        for (final result in _results)
          Card(
            child: ListTile(
              leading: Icon(
                result.ok ? Icons.check_circle : Icons.error,
                color: result.ok ? Colors.greenAccent : Colors.orangeAccent,
              ),
              title: Text(result.name),
              subtitle: Text('${result.detail} • ${result.elapsedMs} мс'),
            ),
          ),
        if (_results.isNotEmpty && !_running) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy),
                  label: const Text('Скопировать'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share),
                  label: const Text('Поделиться'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            DeviceDiagnostics.report(_results),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'После проверки',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Проведи пальцем раскладку пола и стены, поверни 3D, включи скрытие стен. Эти жесты и качество картинки автоматика оценить не может: если что-то скачет или пропадает, пришли запись экрана вместе с отчётом.',
        ),
      ],
    ),
  );
}
