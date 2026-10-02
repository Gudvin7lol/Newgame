import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zamer_app/renderer3d/model_asset_catalog.dart';

void main() {
  test('up/down sconce is a complete production LOD asset', () {
    final asset = ZamerModelAssetCatalog.byId('wall-sconce-updown');
    expect(asset, isNotNull);
    expect(asset!.hasCompleteLodChain, isTrue);
    expect(
      ZamerModelAssetCatalog.productionLodIds,
      contains('wall-sconce-updown'),
    );
    expect(asset.nativeWidthMm, 180);
    expect(asset.nativeDepthMm, 150);
    expect(asset.nativeHeightMm, 300);
    expect(File(asset.assetPath).existsSync(), isTrue);
    expect(File(asset.lod1AssetPath!).existsSync(), isTrue);
    expect(File(asset.lod2AssetPath!).existsSync(), isTrue);
  });

  test('3D page consumes shared master UI header', () {
    final source = File('lib/screens/floor_3d_screen.dart').readAsStringSync();
    expect(source, contains('ZMasterPageHeader('));
    expect(source, isNot(contains('class _ThreeDMasterHeader')));
    expect(source, contains("title: '3D'"));
  });
}
