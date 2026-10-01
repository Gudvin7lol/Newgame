#!/usr/bin/env python3
"""Wire Performance/Quality UI selection into the live GPU renderer."""

from pathlib import Path

APP = Path(__file__).resolve().parents[2]
GPU = APP / 'lib' / 'renderer3d' / 'zamer_gpu_viewport.dart'
SCREEN = APP / 'lib' / 'screens' / 'floor_3d_screen.dart'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        if new in text:
            return text
        raise RuntimeError(f'could not locate {label}')
    if text.count(old) != 1:
        raise RuntimeError(f'expected one {label}, found {text.count(old)}')
    return text.replace(old, new, 1)


def patch_gpu() -> None:
    text = GPU.read_text(encoding='utf-8')

    text = replace_once(
        text,
        """    required this.walkY,
  });
""",
        """    required this.walkY,
    this.performanceMode = false,
  });
""",
        'viewport performance constructor',
    )
    text = replace_once(
        text,
        """  final double walkY;

  @override
""",
        """  final double walkY;
  final bool performanceMode;

  @override
""",
        'viewport performance field',
    )

    text = replace_once(
        text,
        """    final fingerprint = _floorFingerprint();
    if (!identical(oldWidget.floor, widget.floor) ||
        fingerprint != _lastFloorFingerprint) {
      _lastFloorFingerprint = fingerprint;
      _rebuildSceneAfterUpdate();
    }
""",
        """    final fingerprint = _floorFingerprint();
    final performanceChanged =
        oldWidget.performanceMode != widget.performanceMode;
    if (performanceChanged) _configureScene();
    if (!identical(oldWidget.floor, widget.floor) ||
        fingerprint != _lastFloorFingerprint ||
        performanceChanged) {
      _lastFloorFingerprint = fingerprint;
      _rebuildSceneAfterUpdate();
    }
""",
        'performance rebuild trigger',
    )

    text = replace_once(
        text,
        """    final scene = _scene;
    if (scene == null) return;
    scene.environmentSettings = EnvironmentSettings(
      toneMapping: ToneMappingMode.pbrNeutral,
      environmentIntensity: 0.82,
      exposure: 0.94,
      ambientOcclusionEnabled: false,
""",
        """    final scene = _scene;
    if (scene == null) return;
    final performance = widget.performanceMode;
    scene.environmentSettings = EnvironmentSettings(
      toneMapping: ToneMappingMode.pbrNeutral,
      environmentIntensity: performance ? 0.74 : 0.82,
      exposure: 0.94,
      ambientOcclusionEnabled: !performance,
""",
        'realtime environment profile',
    )
    text = replace_once(
        text,
        """    scene.antiAliasingMode = AntiAliasingMode.auto;
    scene.environmentIntensity = 0.82;
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-0.45, -1.0, -0.32)..normalize(),
      color: vm.Vector3(1.0, 0.97, 0.92),
      intensity: 1.95,
      castsShadow: true,
      cacheStaticShadows: false,
      shadowMapResolution: 512,
""",
        """    scene.antiAliasingMode = AntiAliasingMode.auto;
    scene.environmentIntensity = performance ? 0.74 : 0.82;
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-0.45, -1.0, -0.32)..normalize(),
      color: vm.Vector3(1.0, 0.97, 0.92),
      intensity: performance ? 1.72 : 1.95,
      castsShadow: !performance,
      cacheStaticShadows: false,
      shadowMapResolution: performance ? 256 : 512,
""",
        'realtime shadow profile',
    )
    text = replace_once(
        text,
        """    scene.ambientOcclusion
      ..enabled = false
      ..halfResolution = true
      ..sampleCount = 2
      ..radius = 0.20
      ..intensity = 0.55
      ..bias = 0.04;
""",
        """    scene.ambientOcclusion
      ..enabled = !performance
      ..halfResolution = true
      ..sampleCount = performance ? 2 : 4
      ..radius = performance ? 0.18 : 0.22
      ..intensity = performance ? 0.42 : 0.62
      ..bias = 0.04;
""",
        'realtime AO profile',
    )

    text = replace_once(
        text,
        """          photoQuality: photoQuality,
          walkMode: widget.walkMode,
        );
""",
        """          photoQuality: photoQuality,
          walkMode: widget.walkMode,
          performanceMode: widget.performanceMode,
        );
""",
        'LOD performance wiring',
    )

    old_light = """    lightNode.addComponent(
      PointLightComponent(
        PointLight(
          color: vm.Vector3(1.0, 0.80, 0.58),
          intensity: intensity,
          range: range,
          falloffExponent: 2.0,
        ),
      ),
    );
"""
    new_light = """    if (!widget.performanceMode) {
      lightNode.addComponent(
        PointLightComponent(
          PointLight(
            color: vm.Vector3(1.0, 0.80, 0.58),
            intensity: intensity,
            range: range,
            falloffExponent: 2.0,
          ),
        ),
      );
    }
"""
    text = replace_once(text, old_light, new_light, 'performance point lights')

    text = replace_once(
        text,
        """        SphereGeometry(radius: glowRadius, segments: 16, rings: 10),
""",
        """        SphereGeometry(
          radius: glowRadius,
          segments: widget.performanceMode ? 10 : 16,
          rings: widget.performanceMode ? 6 : 10,
        ),
""",
        'performance glow geometry',
    )

    GPU.write_text(text, encoding='utf-8')


def patch_screen() -> None:
    text = SCREEN.read_text(encoding='utf-8')
    text = replace_once(
        text,
        """                  walkX: _walkX,
                  walkY: _walkY,
                ),
""",
        """                  walkX: _walkX,
                  walkY: _walkY,
                  performanceMode:
                      _graphicsMode == ZGraphicsMode.performance,
                ),
""",
        'screen performance argument',
    )

    text = replace_once(
        text,
        """              child: _ThreeDMasterHeader(),
""",
        """              child: _ThreeDMasterHeader(graphicsMode: _graphicsMode),
""",
        'dynamic 3D header call',
    )
    text = replace_once(
        text,
        """class _ThreeDMasterHeader extends StatelessWidget {
  const _ThreeDMasterHeader();

  @override
""",
        """class _ThreeDMasterHeader extends StatelessWidget {
  const _ThreeDMasterHeader({required this.graphicsMode});

  final ZGraphicsMode graphicsMode;

  @override
""",
        'dynamic 3D header class',
    )
    text = replace_once(
        text,
        """        child: const Row(
          children: [
            Icon(Icons.view_in_ar_outlined, size: 20, color: ZamerColors.accent),
            SizedBox(width: ZamerSpace.sm),
            Text(
              '3D',
              style: TextStyle(
                color: ZamerColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Spacer(),
            _ThreeDStatus(icon: Icons.layers_outlined, label: 'Сцена'),
            SizedBox(width: ZamerSpace.md),
            _ThreeDStatus(icon: Icons.auto_awesome_outlined, label: 'Quality'),
          ],
        ),
""",
        """        child: Row(
          children: [
            const Icon(
              Icons.view_in_ar_outlined,
              size: 20,
              color: ZamerColors.accent,
            ),
            const SizedBox(width: ZamerSpace.sm),
            const Text(
              '3D',
              style: TextStyle(
                color: ZamerColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            const _ThreeDStatus(icon: Icons.layers_outlined, label: 'Сцена'),
            const SizedBox(width: ZamerSpace.md),
            _ThreeDStatus(icon: graphicsMode.icon, label: graphicsMode.label),
          ],
        ),
""",
        'dynamic 3D header contents',
    )

    SCREEN.write_text(text, encoding='utf-8')


def main() -> None:
    patch_gpu()
    patch_screen()
    print('Wired Performance/Quality profiles into live ZAMER 3D')


if __name__ == '__main__':
    main()
