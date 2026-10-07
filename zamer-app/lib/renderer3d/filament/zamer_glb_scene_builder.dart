import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/material_catalog.dart';
import '../zamer_scene_geometry.dart';

/// Converts the engine-neutral Zamer scene into a compact glTF 2.0 / GLB scene.
///
/// GLB is the boundary between the CAD/editor model and the renderer. This keeps
/// the room model independent from Filament and lets glTF-native furniture and
/// PBR assets join the same scene later without another renderer rewrite.
class ZamerGlbSceneBuilder {
  const ZamerGlbSceneBuilder();

  Uint8List build(
    FloorPlan floor, {
    bool includeCeiling = false,
  }) {
    final geometry = ZamerSceneGeometry.fromFloor(
      FloorPlan.fromJson(floor.toJson()),
    );
    final glb = _GlbBuilder();

    for (final surface in geometry.floors) {
      final material = _materialForId(
        glb,
        surface.materialId,
        name: 'floor:${surface.materialId}',
      );
      glb.addFloor(
        name: 'floor:${surface.roomKey}',
        polygon: surface.polygonMm,
        bounds: geometry.bounds,
        material: material,
        y: 0.006,
      );
      if (includeCeiling) {
        final ceiling = glb.material(
          key: 'ceiling-white',
          name: 'Потолок',
          color: const Color(0xFFF2F0EA),
          roughness: 0.82,
        );
        glb.addFloor(
          name: 'ceiling:${surface.roomKey}',
          polygon: surface.polygonMm,
          bounds: geometry.bounds,
          material: ceiling,
          y: surface.ceilingHeightMm / 1000,
          normalUp: false,
        );
      }
    }

    for (final wall in geometry.walls) {
      final finish = wall.finishes.isEmpty ? null : wall.finishes.first;
      final materialId = finish == null
          ? wall.materialId
          : (finish.tileEnabled ? finish.tileMaterialId : finish.materialId);
      final preset = MaterialCatalog.byId(materialId);
      Color? override;
      if (finish != null &&
          preset.pattern == 'paint' &&
          finish.wallColorArgb != 0) {
        override = Color(finish.wallColorArgb);
      }
      final material = _materialForId(
        glb,
        materialId,
        name: 'wall:$materialId',
        colorOverride: override,
      );
      glb.addBox(
        name: 'wall:${wall.wallId}',
        centerX: (wall.centerXMm - geometry.bounds.centerX) / 1000,
        centerY: (wall.bottomMm + wall.heightMm / 2) / 1000,
        centerZ: (wall.centerYMm - geometry.bounds.centerY) / 1000,
        width: wall.lengthMm / 1000,
        height: wall.heightMm / 1000,
        depth: wall.thicknessMm / 1000,
        yaw: -wall.angleRad,
        material: material,
      );
    }

    for (final opening in geometry.openings) {
      _addOpening(glb, opening, geometry.bounds);
    }

    final objectMaterial = glb.material(
      key: 'object-neutral',
      name: 'Оснащение',
      color: const Color(0xFFB9B2A8),
      roughness: 0.58,
    );
    for (final object in geometry.objects) {
      glb.addBox(
        name: 'object:${object.id}:${object.catalogId}',
        centerX: (object.xMm - geometry.bounds.centerX) / 1000,
        centerY: (object.elevationMm + object.heightMm / 2) / 1000,
        centerZ: (object.yMm - geometry.bounds.centerY) / 1000,
        width: math.max(0.05, object.widthMm / 1000),
        height: math.max(0.05, object.heightMm / 1000),
        depth: math.max(0.05, object.depthMm / 1000),
        yaw: -object.rotationRad,
        material: objectMaterial,
      );
    }

    return glb.finish();
  }

  int _materialForId(
    _GlbBuilder glb,
    String id, {
    required String name,
    Color? colorOverride,
  }) {
    final preset = MaterialCatalog.byId(id);
    return glb.material(
      key: '$id:${colorOverride?.toARGB32() ?? 0}',
      name: name,
      color: colorOverride ?? preset.color,
      roughness: preset.roughness ??
          (preset.pattern == 'tile'
              ? 0.38
              : preset.pattern == 'wood'
                  ? 0.52
                  : preset.pattern == 'concrete'
                      ? 0.78
                      : 0.72),
    );
  }

  void _addOpening(
    _GlbBuilder glb,
    ZamerOpeningPlacement opening,
    ZamerSceneBounds bounds,
  ) {
    final x = (opening.xMm - bounds.centerX) / 1000;
    final z = (opening.yMm - bounds.centerY) / 1000;
    final width = math.max(0.20, opening.widthMm / 1000);
    final height = math.max(0.20, opening.heightMm / 1000);
    final bottom = opening.sillHeightMm / 1000;
    final depth = math.max(0.055, (opening.wallThicknessMm + 18) / 1000);
    final yaw = -opening.rotationRad;
    const bar = 0.052;

    final frame = glb.material(
      key: opening.type == OpeningType.window ? 'window-frame' : 'door-frame',
      name: opening.type == OpeningType.window
          ? 'Оконная рама'
          : 'Дверная коробка',
      color: opening.type == OpeningType.window
          ? const Color(0xFFF0F1EE)
          : const Color(0xFFD8D2C8),
      roughness: 0.42,
    );

    void localBox(
      String name,
      double lx,
      double ly,
      double lz,
      double w,
      double h,
      double d,
      int material,
    ) {
      final c = math.cos(yaw);
      final s = math.sin(yaw);
      glb.addBox(
        name: name,
        centerX: x + lx * c + lz * s,
        centerY: ly,
        centerZ: z - lx * s + lz * c,
        width: w,
        height: h,
        depth: d,
        yaw: yaw,
        material: material,
      );
    }

    localBox(
      'opening-frame-left:${opening.id}',
      -width / 2 + bar / 2,
      bottom + height / 2,
      0,
      bar,
      height,
      depth,
      frame,
    );
    localBox(
      'opening-frame-right:${opening.id}',
      width / 2 - bar / 2,
      bottom + height / 2,
      0,
      bar,
      height,
      depth,
      frame,
    );
    localBox(
      'opening-frame-top:${opening.id}',
      0,
      bottom + height - bar / 2,
      0,
      width,
      bar,
      depth,
      frame,
    );

    if (opening.type == OpeningType.window) {
      localBox(
        'opening-frame-bottom:${opening.id}',
        0,
        bottom + bar / 2,
        0,
        width,
        bar,
        depth,
        frame,
      );
      localBox(
        'window-mullion:${opening.id}',
        0,
        bottom + height / 2,
        0,
        0.036,
        math.max(0.05, height - bar * 2),
        depth * 0.55,
        frame,
      );
      final glass = glb.material(
        key: 'window-glass',
        name: 'Стекло',
        color: const Color(0x667FAFC6),
        roughness: 0.08,
        alphaBlend: true,
      );
      localBox(
        'window-glass:${opening.id}',
        0,
        bottom + height / 2,
        0,
        math.max(0.08, width - bar * 2.3),
        math.max(0.08, height - bar * 2.3),
        0.008,
        glass,
      );
      return;
    }

    final leaf = glb.material(
      key: 'door-leaf-warm',
      name: 'Дверное полотно',
      color: const Color(0xFFE2DDD5),
      roughness: 0.36,
    );
    final inset = glb.material(
      key: 'door-inset-warm',
      name: 'Филёнка двери',
      color: const Color(0xFFD0C8BC),
      roughness: 0.43,
    );
    final metal = glb.material(
      key: 'door-metal',
      name: 'Металл двери',
      color: const Color(0xFF55585C),
      roughness: 0.22,
      metallic: 0.82,
    );

    final leafWidth = math.max(0.14, width - bar * 1.5);
    final leafHeight = math.max(0.18, height - bar);
    localBox(
      'door-leaf:${opening.id}',
      0,
      leafHeight / 2,
      depth * 0.13,
      leafWidth,
      leafHeight,
      0.044,
      leaf,
    );
    for (final y in <double>[leafHeight * 0.34, leafHeight * 0.68]) {
      localBox(
        'door-panel:${opening.id}:$y',
        0,
        y,
        depth * 0.13 + 0.027,
        leafWidth * 0.72,
        leafHeight * 0.23,
        0.010,
        inset,
      );
    }
    localBox(
      'door-handle:${opening.id}',
      leafWidth * 0.34,
      leafHeight * 0.50,
      depth * 0.13 + 0.060,
      0.12,
      0.025,
      0.025,
      metal,
    );
  }
}

class _GlbBuilder {
  final _bin = BytesBuilder(copy: false);
  final List<Map<String, dynamic>> _bufferViews = [];
  final List<Map<String, dynamic>> _accessors = [];
  final List<Map<String, dynamic>> _meshes = [];
  final List<Map<String, dynamic>> _nodes = [];
  final List<Map<String, dynamic>> _materials = [];
  final Map<String, int> _materialByKey = {};

  int material({
    required String key,
    required String name,
    required Color color,
    required double roughness,
    double metallic = 0,
    bool alphaBlend = false,
  }) {
    final known = _materialByKey[key];
    if (known != null) return known;
    final index = _materials.length;
    final alpha = color.a;
    _materials.add({
      'name': name,
      'pbrMetallicRoughness': {
        'baseColorFactor': [color.r, color.g, color.b, alpha],
        'metallicFactor': metallic,
        'roughnessFactor': roughness,
      },
      'doubleSided': true,
      if (alphaBlend || alpha < 0.999) 'alphaMode': 'BLEND',
    });
    _materialByKey[key] = index;
    return index;
  }

  void addFloor({
    required String name,
    required List<math.Point<double>> polygon,
    required ZamerSceneBounds bounds,
    required int material,
    required double y,
    bool normalUp = true,
  }) {
    if (polygon.length < 3) return;
    final tris = _triangulate(polygon);
    if (tris.isEmpty) return;
    final positions = <double>[];
    final normals = <double>[];
    for (final p in polygon) {
      positions.addAll([
        (p.x - bounds.centerX) / 1000,
        y,
        (p.y - bounds.centerY) / 1000,
      ]);
      normals.addAll([0, normalUp ? 1 : -1, 0]);
    }
    final indices = <int>[];
    for (var i = 0; i < tris.length; i += 3) {
      if (normalUp) {
        indices.addAll([tris[i], tris[i + 2], tris[i + 1]]);
      } else {
        indices.addAll([tris[i], tris[i + 1], tris[i + 2]]);
      }
    }
    _addMesh(name, positions, normals, indices, material);
  }

  void addBox({
    required String name,
    required double centerX,
    required double centerY,
    required double centerZ,
    required double width,
    required double height,
    required double depth,
    required double yaw,
    required int material,
  }) {
    final hx = width / 2;
    final hy = height / 2;
    final hz = depth / 2;
    final positions = <double>[];
    final normals = <double>[];
    final indices = <int>[];

    List<double> world(double x, double y, double z) {
      final c = math.cos(yaw);
      final s = math.sin(yaw);
      return [
        centerX + x * c + z * s,
        centerY + y,
        centerZ - x * s + z * c,
      ];
    }

    List<double> normal(double x, double y, double z) {
      final c = math.cos(yaw);
      final s = math.sin(yaw);
      return [x * c + z * s, y, -x * s + z * c];
    }

    void face(
      List<double> a,
      List<double> b,
      List<double> c,
      List<double> d,
      List<double> n,
    ) {
      final base = positions.length ~/ 3;
      for (final p in <List<double>>[a, b, c, d]) {
        positions.addAll(world(p[0], p[1], p[2]));
        normals.addAll(normal(n[0], n[1], n[2]));
      }
      indices.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
    }

    face(
      [-hx, -hy, hz], [hx, -hy, hz], [hx, hy, hz], [-hx, hy, hz],
      [0, 0, 1],
    );
    face(
      [hx, -hy, -hz], [-hx, -hy, -hz], [-hx, hy, -hz], [hx, hy, -hz],
      [0, 0, -1],
    );
    face(
      [-hx, -hy, -hz], [-hx, -hy, hz], [-hx, hy, hz], [-hx, hy, -hz],
      [-1, 0, 0],
    );
    face(
      [hx, -hy, hz], [hx, -hy, -hz], [hx, hy, -hz], [hx, hy, hz],
      [1, 0, 0],
    );
    face(
      [-hx, hy, hz], [hx, hy, hz], [hx, hy, -hz], [-hx, hy, -hz],
      [0, 1, 0],
    );
    face(
      [-hx, -hy, -hz], [hx, -hy, -hz], [hx, -hy, hz], [-hx, -hy, hz],
      [0, -1, 0],
    );

    _addMesh(name, positions, normals, indices, material);
  }

  void _addMesh(
    String name,
    List<double> positions,
    List<double> normals,
    List<int> indices,
    int material,
  ) {
    final positionView = _writeFloats(positions, target: 34962);
    final normalView = _writeFloats(normals, target: 34962);
    final indexView = _writeUint32(indices, target: 34963);

    final positionAccessor = _accessors.length;
    final xs = <double>[], ys = <double>[], zs = <double>[];
    for (var i = 0; i < positions.length; i += 3) {
      xs.add(positions[i]);
      ys.add(positions[i + 1]);
      zs.add(positions[i + 2]);
    }
    _accessors.add({
      'bufferView': positionView,
      'componentType': 5126,
      'count': positions.length ~/ 3,
      'type': 'VEC3',
      'min': [xs.reduce(math.min), ys.reduce(math.min), zs.reduce(math.min)],
      'max': [xs.reduce(math.max), ys.reduce(math.max), zs.reduce(math.max)],
    });

    final normalAccessor = _accessors.length;
    _accessors.add({
      'bufferView': normalView,
      'componentType': 5126,
      'count': normals.length ~/ 3,
      'type': 'VEC3',
    });

    final indexAccessor = _accessors.length;
    _accessors.add({
      'bufferView': indexView,
      'componentType': 5125,
      'count': indices.length,
      'type': 'SCALAR',
      'min': [indices.reduce(math.min)],
      'max': [indices.reduce(math.max)],
    });

    final mesh = _meshes.length;
    _meshes.add({
      'name': name,
      'primitives': [
        {
          'attributes': {
            'POSITION': positionAccessor,
            'NORMAL': normalAccessor,
          },
          'indices': indexAccessor,
          'material': material,
          'mode': 4,
        }
      ],
    });
    _nodes.add({'name': name, 'mesh': mesh});
  }

  int _writeFloats(List<double> values, {required int target}) {
    _align4();
    final offset = _bin.length;
    final data = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      data.setFloat32(i * 4, values[i], Endian.little);
    }
    final bytes = data.buffer.asUint8List();
    _bin.add(bytes);
    final index = _bufferViews.length;
    _bufferViews.add({
      'buffer': 0,
      'byteOffset': offset,
      'byteLength': bytes.length,
      'target': target,
    });
    return index;
  }

  int _writeUint32(List<int> values, {required int target}) {
    _align4();
    final offset = _bin.length;
    final data = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      data.setUint32(i * 4, values[i], Endian.little);
    }
    final bytes = data.buffer.asUint8List();
    _bin.add(bytes);
    final index = _bufferViews.length;
    _bufferViews.add({
      'buffer': 0,
      'byteOffset': offset,
      'byteLength': bytes.length,
      'target': target,
    });
    return index;
  }

  void _align4() {
    final padding = (4 - (_bin.length % 4)) % 4;
    if (padding != 0) _bin.add(Uint8List(padding));
  }

  Uint8List finish() {
    _align4();
    final bin = _bin.takeBytes();
    final jsonMap = <String, dynamic>{
      'asset': {'version': '2.0', 'generator': 'Zamer Filament GLB'},
      'scene': 0,
      'scenes': [
        {'nodes': List<int>.generate(_nodes.length, (i) => i)}
      ],
      'nodes': _nodes,
      'meshes': _meshes,
      'materials': _materials,
      'buffers': [
        {'byteLength': bin.length}
      ],
      'bufferViews': _bufferViews,
      'accessors': _accessors,
    };

    var jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(jsonMap)));
    final jsonPadding = (4 - (jsonBytes.length % 4)) % 4;
    if (jsonPadding != 0) {
      jsonBytes = Uint8List.fromList([
        ...jsonBytes,
        ...List<int>.filled(jsonPadding, 0x20),
      ]);
    }

    var binBytes = bin;
    final binPadding = (4 - (binBytes.length % 4)) % 4;
    if (binPadding != 0) {
      binBytes = Uint8List.fromList([
        ...binBytes,
        ...List<int>.filled(binPadding, 0),
      ]);
    }

    final total = 12 + 8 + jsonBytes.length + 8 + binBytes.length;
    final out = BytesBuilder(copy: false);
    final header = ByteData(12)
      ..setUint32(0, 0x46546C67, Endian.little)
      ..setUint32(4, 2, Endian.little)
      ..setUint32(8, total, Endian.little);
    out.add(header.buffer.asUint8List());

    final jsonHeader = ByteData(8)
      ..setUint32(0, jsonBytes.length, Endian.little)
      ..setUint32(4, 0x4E4F534A, Endian.little);
    out
      ..add(jsonHeader.buffer.asUint8List())
      ..add(jsonBytes);

    final binHeader = ByteData(8)
      ..setUint32(0, binBytes.length, Endian.little)
      ..setUint32(4, 0x004E4942, Endian.little);
    out
      ..add(binHeader.buffer.asUint8List())
      ..add(binBytes);
    return out.takeBytes();
  }
}

List<int> _triangulate(List<math.Point<double>> polygon) {
  if (polygon.length < 3) return const <int>[];
  final vertices = List<int>.generate(polygon.length, (i) => i);
  final result = <int>[];
  final ccw = _signedArea(polygon) > 0;
  var guard = polygon.length * polygon.length;

  while (vertices.length > 3 && guard-- > 0) {
    var clipped = false;
    for (var i = 0; i < vertices.length; i++) {
      final prev = vertices[(i - 1 + vertices.length) % vertices.length];
      final cur = vertices[i];
      final next = vertices[(i + 1) % vertices.length];
      final a = polygon[prev];
      final b = polygon[cur];
      final c = polygon[next];
      final cross = _cross(a, b, c);
      if (ccw ? cross <= 0.000001 : cross >= -0.000001) continue;

      var contains = false;
      for (final candidate in vertices) {
        if (candidate == prev || candidate == cur || candidate == next) continue;
        if (_pointInTriangle(polygon[candidate], a, b, c)) {
          contains = true;
          break;
        }
      }
      if (contains) continue;

      result.addAll(ccw ? <int>[prev, cur, next] : <int>[next, cur, prev]);
      vertices.removeAt(i);
      clipped = true;
      break;
    }
    if (!clipped) break;
  }

  if (vertices.length == 3) {
    result.addAll(
      ccw ? vertices : <int>[vertices[2], vertices[1], vertices[0]],
    );
  }
  return result;
}

double _signedArea(List<math.Point<double>> polygon) {
  var area = 0.0;
  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i];
    final b = polygon[(i + 1) % polygon.length];
    area += a.x * b.y - b.x * a.y;
  }
  return area / 2;
}

double _cross(
  math.Point<double> a,
  math.Point<double> b,
  math.Point<double> c,
) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);

bool _pointInTriangle(
  math.Point<double> p,
  math.Point<double> a,
  math.Point<double> b,
  math.Point<double> c,
) {
  final c1 = _cross(a, b, p);
  final c2 = _cross(b, c, p);
  final c3 = _cross(c, a, p);
  final hasNeg = c1 < -0.000001 || c2 < -0.000001 || c3 < -0.000001;
  final hasPos = c1 > 0.000001 || c2 > 0.000001 || c3 > 0.000001;
  return !(hasNeg && hasPos);
}
