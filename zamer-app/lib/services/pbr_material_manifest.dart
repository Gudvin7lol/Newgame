import 'dart:convert';

import 'package:flutter/services.dart';

class PbrMaterialTextureTier {
  const PbrMaterialTextureTier({
    required this.baseColor,
    required this.normal,
    required this.orm,
  });

  final String baseColor;
  final String normal;
  final String orm;

  factory PbrMaterialTextureTier.fromJson(Map<String, dynamic> json) {
    String read(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('Missing PBR texture path: $key');
      }
      return value;
    }

    return PbrMaterialTextureTier(
      baseColor: read('baseColor'),
      normal: read('normal'),
      orm: read('orm'),
    );
  }
}

class PbrMaterialManifest {
  const PbrMaterialManifest({
    required this.id,
    required this.name,
    required this.kind,
    required this.tintable,
    required this.roughness,
    required this.normalScale,
    required this.occlusionStrength,
    required this.physicalWidthMm,
    required this.physicalHeightMm,
    required this.tiers,
  });

  final String id;
  final String name;
  final String kind;
  final bool tintable;
  final double roughness;
  final double normalScale;
  final double occlusionStrength;
  final double physicalWidthMm;
  final double physicalHeightMm;
  final Map<String, PbrMaterialTextureTier> tiers;

  PbrMaterialTextureTier texturesFor({
    required bool mobile,
    required bool photo,
  }) {
    final preferred = photo ? 'photo' : (mobile ? 'performance' : 'quality');
    return tiers[preferred] ??
        tiers['quality'] ??
        tiers['performance'] ??
        (throw StateError('Material $id has no runtime texture tier'));
  }

  factory PbrMaterialManifest.fromJson(
    String id,
    Map<String, dynamic> json,
  ) {
    final surface = ((json['surface'] as Map?) ?? const <String, dynamic>{})
        .cast<String, dynamic>();
    final physical =
        ((json['physicalScale'] as Map?) ?? const <String, dynamic>{})
            .cast<String, dynamic>();
    final rawTiers = ((json['tiers'] as Map?) ?? const <String, dynamic>{})
        .cast<String, dynamic>();
    final tiers = <String, PbrMaterialTextureTier>{};
    for (final entry in rawTiers.entries) {
      if (entry.value is Map) {
        tiers[entry.key] = PbrMaterialTextureTier.fromJson(
          (entry.value as Map).cast<String, dynamic>(),
        );
      }
    }

    double number(Map<String, dynamic> source, String key, double fallback) =>
        (source[key] as num?)?.toDouble() ?? fallback;

    return PbrMaterialManifest(
      id: id,
      name: json['name'] as String? ?? id,
      kind: json['kind'] as String? ?? 'surface',
      tintable: json['tintable'] as bool? ?? false,
      roughness: number(surface, 'roughness', 0.7),
      normalScale: number(surface, 'normalScale', 1.0),
      occlusionStrength: number(surface, 'occlusionStrength', 1.0),
      physicalWidthMm: number(physical, 'widthMm', 1000),
      physicalHeightMm: number(physical, 'heightMm', 1000),
      tiers: Map<String, PbrMaterialTextureTier>.unmodifiable(tiers),
    );
  }
}

class PbrMaterialManifestLibrary {
  bool _loaded = false;
  final Map<String, PbrMaterialManifest> _materials =
      <String, PbrMaterialManifest>{};

  PbrMaterialManifest? cached(String id) => _materials[id];

  Future<PbrMaterialManifest?> load(
    String id, {
    AssetBundle? bundle,
  }) async {
    if (!_loaded) {
      await _loadCatalog(bundle ?? rootBundle);
    }
    return _materials[id];
  }

  Future<void> _loadCatalog(AssetBundle bundle) async {
    _loaded = true;
    try {
      final raw =
          await bundle.loadString('assets/textures/pbr12/material.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final materials = decoded['materials'];
      if (materials is! Map) return;
      for (final entry in materials.entries) {
        if (entry.value is! Map) continue;
        final id = entry.key.toString();
        _materials[id] = PbrMaterialManifest.fromJson(
          id,
          (entry.value as Map).cast<String, dynamic>(),
        );
      }
    } catch (_) {
      // The static MaterialCatalog remains a complete fallback.
    }
  }
}
