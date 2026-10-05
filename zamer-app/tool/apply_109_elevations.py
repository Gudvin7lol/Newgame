from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if old not in text:
        raise SystemExit(f'Patch anchor not found in {path}: {old[:100]!r}')
    path.write_text(text.replace(old, new, 1))


screen = ROOT / 'lib/screens/elevations_screen.dart'
replace_once(
    screen,
    "import '../widgets/elevation_painter.dart';\n",
    "import '../widgets/elevation_painter.dart';\nimport '../widgets/large_elevation_viewer.dart';\n",
)

old = r'''  Future<void> _openLargeElevation(
    RoomFace face,
    ElevationRun run,
    double height,
    RoomMaterialSettings settings,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Развёртка • ${run.lengthMm.round()} мм')),
          body: StatefulBuilder(
            builder: (context, refresh) => LayoutBuilder(
              builder: (context, constraints) {
                final drawing = Size(
                  math.max(constraints.maxWidth - 24, run.lengthMm * .25),
                  math.max(constraints.maxHeight * .8, height * .25),
                );
                return InteractiveViewer(
                  constrained: false,
                  minScale: .35,
                  maxScale: 6,
                  boundaryMargin: const EdgeInsets.all(240),
                  child: GestureDetector(
                    onPanUpdate: settings.wallTileEnabledFor(run.id)
                        ? (d) {
                            _panRunTile(settings, run, height, drawing, d);
                            refresh(() {});
                          }
                        : null,
                    onPanEnd: settings.wallTileEnabledFor(run.id)
                        ? (_) => widget.onChanged()
                        : null,
                    child: SizedBox.fromSize(
                      size: drawing,
                      child: CustomPaint(
                        painter: ElevationPainter(
                          floor: widget.floor,
                          face: face,
                          run: run,
                          heightMm: height,
                          settings: settings,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
'''
new = r'''  Future<void> _openLargeElevation(
    RoomFace face,
    ElevationRun run,
    double height,
    RoomMaterialSettings settings,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => LargeElevationViewer(
          floor: widget.floor,
          face: face,
          run: run,
          heightMm: height,
          settings: settings,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (mounted) setState(() {});
  }
'''
replace_once(screen, old, new)

pubspec = ROOT / 'pubspec.yaml'
replace_once(pubspec, 'version: 1.5.6+108', 'version: 1.5.6+109')

print('Applied Zamer 1.5.6+109 elevations integration')
