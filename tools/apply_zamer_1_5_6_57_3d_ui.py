from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'zamer-app'


def replace_between(text: str, start: str, end: str, block: str, label: str) -> str:
    a = text.find(start)
    if a < 0:
        raise SystemExit(f'{label}: start marker missing')
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f'{label}: end marker missing')
    return text[:a] + block + text[b:]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


pubspec_path = APP / 'pubspec.yaml'
pubspec = pubspec_path.read_text()
if 'version: 1.5.6+57' in pubspec:
    print('1.5.6+57 already applied')
    raise SystemExit(0)
if 'version: 1.5.6+56' not in pubspec:
    raise SystemExit('unexpected version, refusing +57 patch')

screen_path = APP / 'lib/screens/floor_3d_screen.dart'
screen = screen_path.read_text()
start = '  @override\n  Widget build(BuildContext context) {\n'
end = '}\n\nclass _WalkJoystick extends StatefulWidget {\n'
new_build = r'''  Future<void> _showWalkSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Настройки прогулки',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.speed, size: 19),
                    const SizedBox(width: 8),
                    const SizedBox(width: 96, child: Text('Скорость')),
                    Expanded(
                      child: Slider(
                        value: _walkStepMm,
                        min: 55,
                        max: 220,
                        divisions: 11,
                        label: '${_walkStepMm.round()} мм',
                        onChanged: (value) {
                          setState(() => _walkStepMm = value);
                          setSheet(() {});
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.visibility_outlined, size: 19),
                    const SizedBox(width: 8),
                    const SizedBox(width: 96, child: Text('Осмотр')),
                    Expanded(
                      child: Slider(
                        value: _lookSensitivity,
                        min: 0.005,
                        max: 0.018,
                        divisions: 13,
                        label: '${(_lookSensitivity * 1000).round()}',
                        onChanged: (value) {
                          setState(() => _lookSensitivity = value);
                          setSheet(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Левый стик отвечает только за движение. Осмотр выполняется одним пальцем прямо по сцене.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A0A6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.floor.walls.isEmpty) {
      return const Center(child: Text('Построй стены, чтобы увидеть 3D.'));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ZamerGpuViewport(
                  key: _gpuKey,
                  floor: widget.floor,
                  rotation: _rotation,
                  tilt: _tilt,
                  zoom: _zoom,
                  cutaway: !_walkMode && _cutaway,
                  pan: _pan,
                  walkMode: _walkMode,
                  walkX: _walkX,
                  walkY: _walkY,
                ),
                if (_walkMode)
                  const IgnorePointer(
                    child: Center(
                      child: SizedBox.square(
                        dimension: 18,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Color(0xCCF1C79E), width: 1.4),
                            ),
                          ),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 3,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0xFFF1C79E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xD9111A1F),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFF2A3941)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _walkMode ? 'В центр комнаты' : 'Сбросить вид',
                    onPressed: _reset,
                    icon: const Icon(Icons.my_location_outlined),
                  ),
                  if (!_walkMode)
                    IconButton(
                      tooltip: 'Вид сверху',
                      onPressed: _topView,
                      icon: const Icon(Icons.vertical_align_top),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_walkMode)
          Positioned(
            left: 10,
            bottom: 78,
            child: SafeArea(
              top: false,
              right: false,
              child: _WalkJoystick(
                onStep: (forward, sideways) => _walk(
                  forward * _walkStepMm,
                  sideways * _walkStepMm,
                ),
              ),
            ),
          ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 8,
          child: SafeArea(
            top: false,
            child: Card(
              elevation: 0,
              color: const Color(0xF5111A1F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF2A3941)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                child: Row(
                  children: _walkMode
                      ? [
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.home_outlined,
                              label: 'Обзор',
                              onTap: _toggleWalk,
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.blur_on,
                              label: 'Сквозь',
                              selected: _noclip,
                              onTap: () => setState(() => _noclip = !_noclip),
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.tune_rounded,
                              label: 'Настройки',
                              onTap: _showWalkSettingsSheet,
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.my_location_outlined,
                              label: 'Центр',
                              onTap: _reset,
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: _rendering
                                  ? Icons.hourglass_top_rounded
                                  : Icons.photo_camera_outlined,
                              label: 'Рендер',
                              onTap: _rendering ? null : _showRenderSheet,
                            ),
                          ),
                        ]
                      : [
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.view_in_ar_outlined,
                              label: 'Обзор',
                              selected: true,
                              onTap: _reset,
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.directions_walk,
                              label: 'Прогулка',
                              onTap: _toggleWalk,
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.layers_clear_outlined,
                              label: 'Разрез',
                              selected: _cutaway,
                              onTap: () => setState(() => _cutaway = !_cutaway),
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: Icons.vertical_align_top,
                              label: 'Сверху',
                              onTap: _topView,
                            ),
                          ),
                          Expanded(
                            child: _SceneAction(
                              icon: _rendering
                                  ? Icons.hourglass_top_rounded
                                  : Icons.photo_camera_outlined,
                              label: 'Рендер',
                              onTap: _rendering ? null : _showRenderSheet,
                            ),
                          ),
                        ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SceneAction extends StatelessWidget {
  const _SceneAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? const Color(0xFF22170F)
        : const Color(0xFFD7DDDF);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? const Color(0xFFF1C79E) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? .45 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 19, color: foreground),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 9.5,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

'''
screen = replace_between(screen, start, end, new_build, 'replace 3D screen layout')
screen_path.write_text(screen)

pubspec_path.write_text(pubspec.replace('version: 1.5.6+56', 'version: 1.5.6+57', 1))

changelog_path = APP / 'CHANGELOG.md'
changelog = changelog_path.read_text()
entry = '''## 1.5.6+57 — 3D по мастер-концепту

- Экран 3D перестроен по странице 3 мастер-концепта: сцена занимает почти всю доступную площадь, а постоянные технические слайдеры убраны из основного вида.
- Нижняя панель стала компактной и контекстной: в обзоре доступны «Обзор / Прогулка / Разрез / Сверху / Рендер», в прогулке — «Обзор / Сквозь / Настройки / Центр / Рендер».
- Вращение, наклон, масштаб и перемещение остаются жестами прямо по сцене; дублирующие слайдеры больше не отнимают половину экрана.
- Джойстик Walk Mode перенесён поверх 3D-сцены и больше не растягивает отдельную большую панель управления под рендером.
- Скорость движения и чувствительность осмотра перенесены в отдельный bottom sheet «Настройки прогулки».
- Центральный ориентир прогулки заменён на компактный песочный прицел в визуальном языке мастер-концепта.
- Быстрый сброс и вид сверху вынесены в небольшую плавающую панель справа, а состояние «Разрез» и «Сквозь стены» видно непосредственно на активной кнопке.

'''
if not changelog.startswith('## 1.5.6+57'):
    changelog_path.write_text(entry + changelog)

print('Applied Zamer 1.5.6+57 3D UI pass')
