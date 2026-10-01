from pathlib import Path

path = Path('zamer-app/lib/renderer3d/zamer_gpu_viewport.dart')
source = path.read_text(encoding='utf-8')

old = '''  void _applyCutaway(PerspectiveCamera camera) {
    if (!_ready) return;
    for (final ceiling in _ceilingNodes) {
      ceiling.visible = widget.walkMode;
    }
    if (!widget.cutaway || widget.walkMode) {
      for (final wall in _wallVisuals) {
        wall.node.visible = true;
      }
      return;
    }

    final camera2 = vm.Vector2(camera.position.x, camera.position.z);
    if (camera2.length2 < 0.0001) return;
    final cameraDir = camera2.normalized();
    for (final wall in _wallVisuals) {
      final wallPos = vm.Vector2(wall.x, wall.z);
      final radial = wallPos.length;
      if (radial < 0.08) {
        wall.node.visible = true;
        continue;
      }
      // Hide only the near-facing shell. Unlike the old wall-index heuristic,
      // this remains stable for rotated, concave and multi-room plans.
      final towardCamera = wallPos.normalized().dot(cameraDir);
      wall.node.visible = towardCamera < 0.30;
    }
  }
'''

new = '''  void _applyCutaway(PerspectiveCamera camera) {
    if (!_ready) return;
    for (final ceiling in _ceilingNodes) {
      ceiling.visible = widget.walkMode;
    }
    if (!widget.cutaway || widget.walkMode || widget.tilt >= 1.32) {
      for (final wall in _wallVisuals) {
        wall.node.visible = true;
      }
      return;
    }

    final bounds = _geometry?.bounds;
    if (bounds == null) return;
    final camera2 = vm.Vector2(camera.position.x, camera.position.z);

    // Cutaway must use the same panned orbit target as the camera. The old
    // implementation compared every wall with world origin (0, 0), so after
    // panning or in multi-room plans it could hide an unrelated wall on the
    // opposite side of the project.
    final maxDimension = math.max(bounds.widthMm, bounds.depthMm) / 1000;
    final zoom = widget.zoom.clamp(0.15, 10.0).toDouble();
    final distance = math.max(1.1, math.max(3.0, maxDimension * 1.52) / zoom);
    final panScale = distance / 900;
    final target2 = vm.Vector2(
      -widget.pan.dx * panScale,
      -widget.pan.dy * panScale,
    );
    final cameraFromTarget = camera2 - target2;
    if (cameraFromTarget.length2 < 0.0001) return;

    final cameraDir = cameraFromTarget.normalized();
    final cameraDistance = cameraFromTarget.length;
    final halfFov =
        widget.cameraFovDegrees.clamp(18.0, 90.0).toDouble() * math.pi / 360;
    final corridorHalfWidth = math.max(
      0.75,
      math.tan(halfFov) * cameraDistance * 1.15,
    );

    for (final wall in _wallVisuals) {
      final wallPos = vm.Vector2(wall.x, wall.z);
      final relative = wallPos - target2;
      final radial = relative.length;
      if (radial < 0.08) {
        wall.node.visible = true;
        continue;
      }

      final axial = relative.dot(cameraDir);
      final lateral =
          (relative.x * cameraDir.y - relative.y * cameraDir.x).abs();
      final towardCamera = relative.normalized().dot(cameraDir);
      final inOcclusionBand = axial > 0.08 && axial < cameraDistance * 0.92;
      final inViewCorridor = lateral < corridorHalfWidth + 0.25;

      // Hide only the camera-side walls that can actually obstruct the current
      // target. Side/rear walls stay visible, and a panned camera no longer
      // cuts walls around the stale world origin.
      wall.node.visible = !(
        towardCamera >= 0.30 && inOcclusionBand && inViewCorridor
      );
    }
  }
'''

if new in source:
    print('Camera-relative cutaway already applied.')
elif old not in source:
    raise SystemExit('Expected legacy cutaway block was not found; refusing unsafe patch.')
else:
    path.write_text(source.replace(old, new, 1), encoding='utf-8')
    print('Applied camera-relative cutaway.')
