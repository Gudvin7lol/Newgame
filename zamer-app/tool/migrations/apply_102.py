from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'{label}: anchor not found in {path}')
    p.write_text(text.replace(old, new, 1))


def replace_all(path: str, pairs: list[tuple[str, str]]) -> None:
    p = Path(path)
    text = p.read_text()
    for old, new in pairs:
        text = text.replace(old, new)
    p.write_text(text)


# 1) Intuitive camera swipe direction on 3D / Walk and Photo.
floor3d = 'zamer-app/lib/screens/floor_3d_screen.dart'
replace_once(
    floor3d,
    "import '../services/walk_input_service.dart';\n",
    "import '../services/camera_gesture_policy.dart';\nimport '../services/walk_input_service.dart';\n",
    'floor3d gesture import',
)
replace_once(
    floor3d,
    "        final angle = _rotation + lookDelta.dx * lookSensitivity;\n        _rotation = math.atan2(math.sin(angle), math.cos(angle));\n",
    "        _rotation = CameraGesturePolicy.applyHorizontalSwipe(\n          yaw: _rotation,\n          deltaX: lookDelta.dx,\n          sensitivity: lookSensitivity,\n        );\n",
    'floor3d horizontal swipe',
)

photo = 'zamer-app/lib/screens/photo_studio_screen.dart'
replace_once(
    photo,
    "import '../renderer3d/zamer_gpu_viewport.dart';\n",
    "import '../renderer3d/zamer_gpu_viewport.dart';\nimport '../services/camera_gesture_policy.dart';\n",
    'photo gesture import',
)
replace_once(
    photo,
    "        final angle = _rotation + lookDelta.dx * .008;\n        _rotation = math.atan2(math.sin(angle), math.cos(angle));\n",
    "        _rotation = CameraGesturePolicy.applyHorizontalSwipe(\n          yaw: _rotation,\n          deltaX: lookDelta.dx,\n          sensitivity: .008,\n        );\n",
    'photo horizontal swipe',
)

# 2) Bring Equipment onto the shared Master UI Kit.
equipment = 'zamer-app/lib/screens/planning_objects_screen.dart'
replace_once(
    equipment,
    "import '../models/models.dart';\n",
    "import '../design_system/zamer_components.dart';\nimport '../design_system/zamer_master_page_header.dart';\nimport '../design_system/zamer_tokens.dart';\nimport '../models/models.dart';\n",
    'equipment design imports',
)
old_equipment_header = """              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Оснащение',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Выбери объект и размести его касанием по плану',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8C989D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Открыть каталог',
                    onPressed: _source == _AddSource.catalog
                        ? _chooseModel
                        : null,
                    icon: const Icon(Icons.grid_view_rounded),
                  ),
                ],
              ),
"""
new_equipment_header = """              ZMasterPageHeader(
                icon: Icons.chair_alt_outlined,
                title: 'Оснащение',
                subtitle: 'Выбери объект и размести его касанием по плану',
                trailing: IconButton.filledTonal(
                  tooltip: 'Открыть каталог',
                  onPressed: _source == _AddSource.catalog ? _chooseModel : null,
                  icon: const Icon(Icons.grid_view_rounded),
                ),
              ),
"""
replace_once(equipment, old_equipment_header, new_equipment_header, 'equipment master header')
old_selected_card = """                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111A1F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A3941)),
                  ),
                  child: Row(
"""
new_selected_card = """                ZPanel(
                  padding: const EdgeInsets.all(ZamerSpace.sm),
                  color: ZamerColors.surfaceLow,
                  child: Row(
"""
replace_once(equipment, old_selected_card, new_selected_card, 'equipment selected model panel')
replace_all(
    equipment,
    [
        ('backgroundColor: const Color(0xFF0E1517),', 'backgroundColor: ZamerColors.background,'),
        ('const Color(0xFF3B3028)', 'ZamerColors.accent.withValues(alpha: .12)'),
        ('const Color(0xFFF1C79E)', 'ZamerColors.accent'),
        ('const Color(0xFF172125)', 'ZamerColors.surface'),
        ('const Color(0xFF29373B)', 'ZamerColors.outline'),
        ('const Color(0xFF233036)', 'ZamerColors.surfaceHigh'),
        ('const Color(0xFF9DE6C8)', 'ZamerColors.success'),
        ('const Color(0xFF111A1F)', 'ZamerColors.surfaceLow'),
        ('const Color(0xFF2A3941)', 'ZamerColors.outline'),
        ('const Color(0xFFB3BDC1)', 'ZamerColors.textMuted'),
        ('const Color(0xFF0B1216)', 'ZamerColors.background'),
        ('const Color(0xFFC7CFD2)', 'ZamerColors.textSecondary'),
        ('const Color(0xFF8C989D)', 'ZamerColors.textMuted'),
        ('BorderRadius.circular(18)', 'BorderRadius.circular(ZamerRadius.lg)'),
        ('BorderRadius.circular(16)', 'BorderRadius.circular(ZamerRadius.lg)'),
        ('BorderRadius.circular(12)', 'BorderRadius.circular(ZamerRadius.md)'),
    ],
)

# 3) Bring Elevations onto the same header/panel/token system.
elevations = 'zamer-app/lib/screens/elevations_screen.dart'
replace_once(
    elevations,
    "import '../models/models.dart';\n",
    "import '../design_system/zamer_components.dart';\nimport '../design_system/zamer_master_page_header.dart';\nimport '../design_system/zamer_tokens.dart';\nimport '../models/models.dart';\n",
    'elevations design imports',
)
old_elevation_header = """              const Text(
                'Развёртки',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                '${meta.name} • ${runs.length} стен',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8C989D)),
              ),
"""
new_elevation_header = """              ZMasterPageHeader(
                icon: Icons.view_agenda_outlined,
                title: 'Развёртки',
                subtitle: '${meta.name} • ${runs.length} стен',
              ),
"""
replace_once(elevations, old_elevation_header, new_elevation_header, 'elevations master header')
old_elevation_card = """                  child: Card(
                    elevation: 0,
                    color: const Color(0xFF111A1F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Color(0xFF2A3941)),
                    ),
                    child: Column(
"""
new_elevation_card = """                  child: ZPanel(
                    padding: EdgeInsets.zero,
                    color: ZamerColors.surfaceLow,
                    child: Column(
"""
replace_once(elevations, old_elevation_card, new_elevation_card, 'elevations master panel')
replace_all(
    elevations,
    [
        ('const Color(0xFF3B3028)', 'ZamerColors.accent.withValues(alpha: .12)'),
        ('const Color(0xFFF1C79E)', 'ZamerColors.accent'),
        ('const Color(0xFF111A1F)', 'ZamerColors.surfaceLow'),
        ('const Color(0xFF2A3941)', 'ZamerColors.outline'),
        ('const Color(0xFF0B1115)', 'ZamerColors.background'),
        ('const Color(0xFF172125)', 'ZamerColors.surface'),
        ('const Color(0xFF8C989D)', 'ZamerColors.textMuted'),
        ('BorderRadius.circular(12)', 'BorderRadius.circular(ZamerRadius.md)'),
        ('BorderRadius.circular(11)', 'BorderRadius.circular(ZamerRadius.md)'),
        ('BorderRadius.circular(10)', 'BorderRadius.circular(ZamerRadius.sm)'),
    ],
)

# 4) Extend generated material ids.
ids = 'zamer-app/lib/services/generated_material_ids.dart'
replace_once(
    ids,
    "  static const wallLinen = 'zamer-wall-linen';\n",
    "  static const wallLinen = 'zamer-wall-linen';\n  static const oakNaturalPbr = 'zamer-oak-natural-pbr';\n  static const walnutPbr = 'zamer-walnut-pbr';\n  static const marbleBiancoPbr = 'zamer-marble-bianco-pbr';\n  static const concreteWarmPbr = 'zamer-concrete-warm-pbr';\n  static const plasterMineralPbr = 'zamer-plaster-mineral-pbr';\n  static const graphiteTilePbr = 'zamer-graphite-tile-pbr';\n",
    'generated material ids',
)
replace_once(
    ids,
    "    wallLinen,\n  };",
    "    wallLinen,\n    oakNaturalPbr,\n    walnutPbr,\n    marbleBiancoPbr,\n    concreteWarmPbr,\n    plasterMineralPbr,\n    graphiteTilePbr,\n  };",
    'generated material id set',
)

materials = 'zamer-app/lib/services/material_catalog.dart'
material_anchor = """    VisualMaterialPreset(
      id: GeneratedMaterialIds.wallLinen,
      name: 'Льняные обои · натуральный бежевый',
      category: 'Стены',
      color: Color(0xFFBBA98D),
      textureAsset: 'assets/textures/generated_v1/wall_linen.jpg',
      roughness: .92,
    ),
  ];
"""
material_insert = """    VisualMaterialPreset(
      id: GeneratedMaterialIds.wallLinen,
      name: 'Льняные обои · натуральный бежевый',
      category: 'Стены',
      color: Color(0xFFBBA98D),
      textureAsset: 'assets/textures/generated_v1/wall_linen.jpg',
      roughness: .92,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.oakNaturalPbr,
      name: 'Дуб натуральный · PBR',
      category: 'Пол',
      color: Color(0xFFD0AD7D),
      pattern: 'wood',
      textureAsset: 'assets/textures/floor_oak_natural.png',
      roughness: .52,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.walnutPbr,
      name: 'Орех натуральный · PBR',
      category: 'Пол',
      color: Color(0xFF815A3D),
      pattern: 'wood',
      textureAsset: 'assets/textures/floor_walnut.png',
      roughness: .50,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.marbleBiancoPbr,
      name: 'Мрамор Bianco · PBR',
      category: 'Плитка',
      color: Color(0xFFE9E6E0),
      pattern: 'tile',
      textureAsset: 'assets/textures/tile_marble.png',
      roughness: .28,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.concreteWarmPbr,
      name: 'Бетон тёплый · PBR',
      category: 'Стены',
      color: Color(0xFFB9B2A8),
      pattern: 'concrete',
      textureAsset: 'assets/textures/concrete_soft.png',
      roughness: .86,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.plasterMineralPbr,
      name: 'Минеральная штукатурка · PBR',
      category: 'Стены',
      color: Color(0xFFD2C7B6),
      pattern: 'concrete',
      textureAsset: 'assets/textures/plaster_warm.png',
      roughness: .88,
    ),
    VisualMaterialPreset(
      id: GeneratedMaterialIds.graphiteTilePbr,
      name: 'Керамогранит графит · PBR',
      category: 'Плитка',
      color: Color(0xFF696D70),
      pattern: 'tile',
      textureAsset: 'assets/textures/tile_graphite.png',
      roughness: .43,
    ),
  ];
"""
replace_once(materials, material_anchor, material_insert, 'material pack presets')

pbr = 'zamer-app/lib/services/generated_pbr_finish_catalog.dart'
pbr_anchor = """    GeneratedMaterialIds.wallLinen: GeneratedPbrFinish(
      baseColorAsset: '$_root/wall_linen.jpg',
      normalAsset: '$_root/wall_linen_normal.png',
      heightAsset: '$_root/wall_linen_height.png',
      metallicRoughnessAsset: '$_root/wall_linen_metallic_roughness.png',
      realWorldTileMm: 700,
      normalScale: 3.2,
    ),
  };
"""
pbr_insert = """    GeneratedMaterialIds.wallLinen: GeneratedPbrFinish(
      baseColorAsset: '$_root/wall_linen.jpg',
      normalAsset: '$_root/wall_linen_normal.png',
      heightAsset: '$_root/wall_linen_height.png',
      metallicRoughnessAsset: '$_root/wall_linen_metallic_roughness.png',
      realWorldTileMm: 700,
      normalScale: 3.2,
    ),
    GeneratedMaterialIds.oakNaturalPbr: GeneratedPbrFinish(
      baseColorAsset: 'assets/textures/floor_oak_natural.png',
      normalAsset: '$_root/white_oak_normal.png',
      heightAsset: '$_root/white_oak_height.png',
      metallicRoughnessAsset: '$_root/white_oak_metallic_roughness.png',
      realWorldTileMm: 1200,
      normalScale: 2.1,
    ),
    GeneratedMaterialIds.walnutPbr: GeneratedPbrFinish(
      baseColorAsset: 'assets/textures/floor_walnut.png',
      normalAsset: '$_root/dark_oak_normal.png',
      heightAsset: '$_root/dark_oak_height.png',
      metallicRoughnessAsset: '$_root/dark_oak_metallic_roughness.png',
      realWorldTileMm: 1200,
      normalScale: 2.0,
    ),
    GeneratedMaterialIds.marbleBiancoPbr: GeneratedPbrFinish(
      baseColorAsset: 'assets/textures/tile_marble.png',
      normalAsset: '$_root/terrazzo_normal.png',
      heightAsset: '$_root/terrazzo_height.png',
      metallicRoughnessAsset: '$_root/terrazzo_metallic_roughness.png',
      realWorldTileMm: 600,
      normalScale: .55,
    ),
    GeneratedMaterialIds.concreteWarmPbr: GeneratedPbrFinish(
      baseColorAsset: 'assets/textures/concrete_soft.png',
      normalAsset: '$_root/wall_microcement_normal.png',
      heightAsset: '$_root/wall_microcement_height.png',
      metallicRoughnessAsset: '$_root/wall_microcement_metallic_roughness.png',
      realWorldTileMm: 1000,
      normalScale: 1.8,
    ),
    GeneratedMaterialIds.plasterMineralPbr: GeneratedPbrFinish(
      baseColorAsset: 'assets/textures/plaster_warm.png',
      normalAsset: '$_root/wall_lime_normal.png',
      heightAsset: '$_root/wall_lime_height.png',
      metallicRoughnessAsset: '$_root/wall_lime_metallic_roughness.png',
      realWorldTileMm: 900,
      normalScale: 2.4,
    ),
    GeneratedMaterialIds.graphiteTilePbr: GeneratedPbrFinish(
      baseColorAsset: 'assets/textures/tile_graphite.png',
      normalAsset: '$_root/slate_normal.png',
      heightAsset: '$_root/slate_height.png',
      metallicRoughnessAsset: '$_root/slate_metallic_roughness.png',
      realWorldTileMm: 600,
      normalScale: 2.4,
    ),
  };
"""
replace_once(pbr, pbr_anchor, pbr_insert, 'generated pbr pack')

# 5) Promote washer, toilet, chandelier and rug to production LOD assets.
objects = 'zamer-app/lib/services/object_catalog.dart'
replace_once(
    objects,
    """    ObjectCatalogItem(
      id: 'chandelier-ring',
      name: 'Люстра-кольцо',
      group: 'Освещение',
      type: PlanObjectType.lighting,
      widthMm: 900,
      depthMm: 900,
      heightMm: 180,
      mount: CatalogMount.ceiling,
    ),
""",
    """    ObjectCatalogItem(
      id: 'chandelier-ring',
      name: 'Люстра-кольцо',
      group: 'Освещение',
      type: PlanObjectType.lighting,
      widthMm: 900,
      depthMm: 900,
      heightMm: 350,
      mount: CatalogMount.ceiling,
    ),
""",
    'chandelier dimensions',
)
replace_once(
    objects,
    """    ObjectCatalogItem(
      id: 'plant-medium',
      name: 'Растение среднее',
      group: 'Декор',
      type: PlanObjectType.furniture,
      widthMm: 500,
      depthMm: 500,
      heightMm: 1000,
    ),
  ];
""",
    """    ObjectCatalogItem(
      id: 'plant-medium',
      name: 'Растение среднее',
      group: 'Декор',
      type: PlanObjectType.furniture,
      widthMm: 500,
      depthMm: 500,
      heightMm: 1000,
    ),
    ObjectCatalogItem(
      id: 'rug-2000x1400',
      name: 'Ковёр 2000×1400',
      group: 'Декор',
      type: PlanObjectType.furniture,
      widthMm: 2000,
      depthMm: 1400,
      heightMm: 35,
    ),
  ];
""",
    'rug catalog entry',
)

model_catalog = 'zamer-app/lib/renderer3d/model_asset_catalog.dart'
replace_once(
    model_catalog,
    "    'wardrobe-sliding-2000',\n  };",
    "    'wardrobe-sliding-2000',\n    'washer',\n    'toilet',\n    'chandelier-ring',\n    'rug-2000x1400',\n  };",
    'production LOD ids',
)
replace_once(
    model_catalog,
    "        'wardrobe-sliding-2000': (2000, 650, 2400),\n      };",
    "        'wardrobe-sliding-2000': (2000, 650, 2400),\n        'washer': (600, 620, 850),\n        'toilet': (390, 700, 760),\n        'chandelier-ring': (900, 900, 350),\n        'rug-2000x1400': (2000, 1400, 35),\n      };",
    'production native dimensions',
)

builder = 'zamer-app/tool/featured_models/build_models.py'
replace_once(
    builder,
    "P=str(OUT);MODEL_NAME={'sofa':'Zamer_Sofa_v3','armchair':'Zamer_Armchair_Sand','table':'Zamer_Table_Walnut','bed':'Zamer_Bed_Sand'}[KIND]\nMATERIAL_NAME='Sand fine woven linen';NORMAL_SCALE=.35\n",
    "P=str(OUT);MODEL_NAME={'sofa':'Zamer_Sofa_v3','armchair':'Zamer_Armchair_Sand','table':'Zamer_Table_Walnut','bed':'Zamer_Bed_Sand','washer':'Zamer_Washer','toilet':'Zamer_Toilet','chandelier':'Zamer_Chandelier_Ring','rug':'Zamer_Rug_2000x1400'}[KIND]\nMATERIAL_NAME='Sand fine woven linen';NORMAL_SCALE=.35;MATERIAL_OVERRIDES=None\n",
    'featured model name map',
)
old_builder_tail = """ dims=np.array([1.80,2.20,1.13]);LABEL='Кровать Sand';CATEGORY='Кровати'
else:raise ValueError(KIND)
"""
new_builder_tail = """ dims=np.array([1.80,2.20,1.13]);LABEL='Кровать Sand';CATEGORY='Кровати'
elif KIND=='washer':
 softbox('washer_body',(.60,.60,.85),(0,0,.425),.025,N=10,mat=0)
 softbox('control_panel',(.54,.035,.14),(0,-.304,.735),.008,N=7,mat=0)
 cylinder('door_rim',.225,.225,.036,(0,-.312,.43),rotation=(math.pi/2,0,0),mat=2,N=64)
 cylinder('door_glass',.180,.180,.041,(0,-.334,.43),rotation=(math.pi/2,0,0),mat=1,N=64)
 cylinder('selector',.038,.038,.025,(.14,-.326,.75),rotation=(math.pi/2,0,0),mat=2,N=40)
 dims=np.array([.60,.62,.85]);LABEL='Стиральная машина Pro';CATEGORY='Бытовая техника'
 MATERIAL_OVERRIDES=[
  {'name':'White enamel','pbrMetallicRoughness':{'baseColorFactor':[.84,.87,.88,1],'metallicFactor':.04,'roughnessFactor':.27}},
  {'name':'Dark washer glass','pbrMetallicRoughness':{'baseColorFactor':[.025,.035,.045,1],'metallicFactor':.18,'roughnessFactor':.10}},
  {'name':'Brushed steel','pbrMetallicRoughness':{'baseColorFactor':[.55,.58,.60,1],'metallicFactor':.82,'roughnessFactor':.20}},
 ]
elif KIND=='toilet':
 softbox('toilet_base',(.34,.54,.42),(0,-.04,.21),.09,.015,N=20,mat=0)
 softbox('toilet_bowl',(.39,.68,.30),(0,-.08,.47),.11,.025,N=24,mat=0)
 cylinder('seat',.19,.19,.035,(0,-.12,.625),mat=1,N=64)
 parts[-1]['v'][:,1]=(parts[-1]['v'][:,1]+.12)*1.48-.12
 softbox('cistern',(.37,.19,.43),(0,.235,.555),.035,N=16,mat=0)
 cylinder('flush_button',.032,.032,.012,(0,.235,.78),mat=2,N=36)
 dims=np.array([.39,.70,.76]);LABEL='Унитаз керамический';CATEGORY='Сантехника'
 MATERIAL_OVERRIDES=[
  {'name':'Gloss ceramic','pbrMetallicRoughness':{'baseColorFactor':[.96,.965,.96,1],'metallicFactor':0,'roughnessFactor':.12}},
  {'name':'Seat soft white','pbrMetallicRoughness':{'baseColorFactor':[.90,.91,.90,1],'metallicFactor':0,'roughnessFactor':.24}},
  {'name':'Chrome button','pbrMetallicRoughness':{'baseColorFactor':[.65,.68,.70,1],'metallicFactor':.92,'roughnessFactor':.12}},
 ]
elif KIND=='chandelier':
 circle=[np.array([.43*math.cos(t),.43*math.sin(t),.10]) for t in np.linspace(0,2*math.pi,96,endpoint=False)]
 tube('outer_ring',circle,r=.020,mat=0)
 circle_glow=[np.array([.405*math.cos(t),.405*math.sin(t),.10]) for t in np.linspace(0,2*math.pi,96,endpoint=False)]
 tube('light_ring',circle_glow,r=.010,mat=1)
 cylinder('ceiling_canopy',.09,.09,.045,(0,0,.327),mat=0,N=48)
 for a in [0,2*math.pi/3,4*math.pi/3]:
  cylinder('suspension',.003,.003,.22,(.32*math.cos(a),.32*math.sin(a),.215),mat=2,N=18)
 dims=np.array([.90,.90,.35]);LABEL='Люстра-кольцо Production';CATEGORY='Освещение'
 MATERIAL_OVERRIDES=[
  {'name':'Black anodized metal','pbrMetallicRoughness':{'baseColorFactor':[.035,.04,.045,1],'metallicFactor':.82,'roughnessFactor':.24}},
  {'name':'Warm diffuser','pbrMetallicRoughness':{'baseColorFactor':[1,.78,.48,1],'metallicFactor':0,'roughnessFactor':.20},'emissiveFactor':[1,.48,.18],'emissiveStrength':2.4},
  {'name':'Suspension wire','pbrMetallicRoughness':{'baseColorFactor':[.24,.25,.26,1],'metallicFactor':.74,'roughnessFactor':.28}},
 ]
elif KIND=='rug':
 softbox('rug_body',(2.0,1.4,.035),(0,0,.0175),.028,.003,N=20,mat=0)
 dims=np.array([2.0,1.4,.035]);LABEL='Ковёр 2000×1400';CATEGORY='Декор';MATERIAL_NAME='Dense woven rug';NORMAL_SCALE=.55
else:raise ValueError(KIND)
"""
replace_once(builder, old_builder_tail, new_builder_tail, 'new production model builders')

exporter = 'zamer-app/tool/featured_models/export_glb.py'
replace_once(
    exporter,
    "g['materials'][0]['name']=MATERIAL_NAME\ng['materials'][0]['normalTexture']['scale']=NORMAL_SCALE\n",
    "if MATERIAL_OVERRIDES is not None:g['materials']=MATERIAL_OVERRIDES\nelse:\n g['materials'][0]['name']=MATERIAL_NAME\n g['materials'][0]['normalTexture']['scale']=NORMAL_SCALE\n",
    'material overrides for production models',
)

ci = '.github/workflows/zamer-codex-ci.yml'
replace_once(
    ci,
    """          build_chain bed Zamer_Bed_Sand_Mobile.glb bed-180

          ls -lh \\
""",
    """          build_chain bed Zamer_Bed_Sand_Mobile.glb bed-180
          build_chain washer Zamer_Washer_Mobile.glb washer
          build_chain toilet Zamer_Toilet_Mobile.glb toilet
          build_chain chandelier Zamer_Chandelier_Ring_Mobile.glb chandelier-ring
          build_chain rug Zamer_Rug_2000x1400_Mobile.glb rug-2000x1400

          ls -lh \\
""",
    'CI production model chains',
)
replace_once(
    ci,
    """            zamer-app/assets/models/zamer_catalog/coffee-table*.glb \\
            zamer-app/assets/models/zamer_catalog/bed-180*.glb
""",
    """            zamer-app/assets/models/zamer_catalog/coffee-table*.glb \\
            zamer-app/assets/models/zamer_catalog/bed-180*.glb \\
            zamer-app/assets/models/zamer_catalog/washer*.glb \\
            zamer-app/assets/models/zamer_catalog/toilet*.glb \\
            zamer-app/assets/models/zamer_catalog/chandelier-ring*.glb \\
            zamer-app/assets/models/zamer_catalog/rug-2000x1400*.glb
""",
    'CI production model listing',
)
replace_once(
    ci,
    """          zamer-app/lib/screens/floor_3d_screen.dart
          zamer-app/lib/widgets/projects_home_widgets.dart
""",
    """          zamer-app/lib/screens/floor_3d_screen.dart
          zamer-app/lib/screens/photo_studio_screen.dart
          zamer-app/lib/screens/planning_objects_screen.dart
          zamer-app/lib/screens/elevations_screen.dart
          zamer-app/lib/services/camera_gesture_policy.dart
          zamer-app/lib/widgets/projects_home_widgets.dart
""",
    'CI formatting coverage',
)

print('ZAMER +102 migration applied')
