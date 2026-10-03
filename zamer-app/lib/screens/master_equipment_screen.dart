import 'package:flutter/material.dart';

import '../design_system/zamer_master_components.dart';
import '../design_system/zamer_tokens.dart';
import '../services/object_catalog.dart';
import '../widgets/model_thumbnail.dart';

class MasterEquipmentScreen extends StatefulWidget {
  const MasterEquipmentScreen({
    super.key,
    required this.projectTitle,
    this.onBack,
    this.onAdd,
  });

  final String projectTitle;
  final VoidCallback? onBack;
  final ValueChanged<ObjectCatalogItem>? onAdd;

  @override
  State<MasterEquipmentScreen> createState() => _MasterEquipmentScreenState();
}

class _MasterEquipmentScreenState extends State<MasterEquipmentScreen> {
  final TextEditingController _search = TextEditingController();
  String _category = 'Мягкая мебель';
  String _filter = 'Все';
  final Set<String> _favorites = <String>{};

  static const _filters = ['Все', 'Мебель', 'Сантехника', 'Освещение', 'Электрика'];
  static const _categories = <(String, IconData)>[
    ('Мягкая мебель', Icons.weekend_outlined),
    ('Кровати', Icons.bed_outlined),
    ('Столы и стулья', Icons.table_restaurant_outlined),
    ('Хранение', Icons.inventory_2_outlined),
    ('Кухня', Icons.kitchen_outlined),
    ('Сантехника', Icons.plumbing_outlined),
    ('Бытовая техника', Icons.local_laundry_service_outlined),
    ('Освещение', Icons.lightbulb_outline_rounded),
    ('Двери и окна', Icons.door_front_door_outlined),
    ('Декор', Icons.local_florist_outlined),
    ('Разное', Icons.apps_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
  }

  @override
  void dispose() {
    _search
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool _matchesTopFilter(ObjectCatalogItem item) {
    if (_filter == 'Все') return true;
    if (_filter == 'Мебель') {
      return item.group != 'Сантехника' &&
          item.group != 'Освещение' &&
          item.group != 'Электрика';
    }
    return item.group.contains(_filter);
  }

  bool _matchesCategory(ObjectCatalogItem item) {
    if (_category == 'Разное') {
      return !_categories.take(_categories.length - 1).any(
        (entry) => item.group == entry.$1 || item.group.contains(entry.$1),
      );
    }
    if (_category == 'Двери и окна') {
      return item.group.contains('Двер') || item.group.contains('Окн');
    }
    if (_category == 'Хранение') {
      return item.group.contains('Хран') || item.group.contains('Шкаф');
    }
    return item.group == _category || item.group.contains(_category);
  }

  List<ObjectCatalogItem> get _items {
    final query = _search.text.trim().toLowerCase();
    final categoryItems = ObjectCatalog.items.where((item) =>
        _matchesTopFilter(item) &&
        _matchesCategory(item) &&
        (query.isEmpty ||
            item.name.toLowerCase().contains(query) ||
            item.group.toLowerCase().contains(query)));
    final result = categoryItems.toList();
    if (result.isNotEmpty || query.isNotEmpty) return result;

    // The master board always keeps the catalogue visually populated. When a
    // legacy group name differs, show the closest filtered items instead of an
    // empty black rectangle.
    return ObjectCatalog.items.where(_matchesTopFilter).take(12).toList();
  }

  void _add(ObjectCatalogItem item) {
    final callback = widget.onAdd;
    if (callback != null) {
      callback(item);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.name} добавлен в проект')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ZMasterTopBar(
              title: widget.projectTitle,
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
              onSettings: () {},
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Оснащение', style: ZamerTypography.h2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          hintText: 'Поиск (например: диван, унитаз, дверь...)',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Icon(Icons.tune_rounded, size: 21),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, index) {
                  final label = _filters[index];
                  final selected = label == _filter;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(label),
                    onSelected: (_) => setState(() => _filter = label),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 126,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(10, 0, 6, 12),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 3),
                      itemBuilder: (_, index) {
                        final entry = _categories[index];
                        return ZMasterCategoryTile(
                          icon: entry.$2,
                          label: entry.$1,
                          selected: _category == entry.$1,
                          onTap: () => setState(() => _category = entry.$1),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(2, 0, 10, 12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: .78,
                        crossAxisSpacing: 7,
                        mainAxisSpacing: 7,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, index) => _EquipmentCard(
                        item: items[index],
                        favorite: _favorites.contains(items[index].id),
                        onFavorite: () => setState(() {
                          if (!_favorites.add(items[index].id)) {
                            _favorites.remove(items[index].id);
                          }
                        }),
                        onAdd: () => _add(items[index]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.item,
    required this.favorite,
    required this.onFavorite,
    required this.onAdd,
  });

  final ObjectCatalogItem item;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Material(
        color: ZamerColors.surface,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: ZamerColors.outline),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ZamerModelThumbnail(
                      catalogId: item.id,
                      size: 180,
                      fallback: ColoredBox(
                        color: ZamerColors.surfaceHigh,
                        child: Icon(
                          _fallbackIcon(item),
                          size: 42,
                          color: ZamerColors.textFaint,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton(
                        onPressed: onFavorite,
                        icon: Icon(
                          favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: favorite
                              ? ZamerColors.accent
                              : ZamerColors.textPrimary,
                          size: 19,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: SizedBox.square(
                        dimension: 34,
                        child: FilledButton(
                          onPressed: onAdd,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                          ),
                          child: const Icon(Icons.add_rounded, size: 23),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 6, 7, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZamerTypography.bodySmall.copyWith(
                        color: ZamerColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.widthMm.round()} × ${item.depthMm.round()} × ${item.heightMm.round()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZamerTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  IconData _fallbackIcon(ObjectCatalogItem item) {
    final group = item.group.toLowerCase();
    if (group.contains('сантех')) return Icons.plumbing_outlined;
    if (group.contains('кух')) return Icons.kitchen_outlined;
    if (group.contains('кров')) return Icons.bed_outlined;
    if (group.contains('освещ')) return Icons.lightbulb_outline_rounded;
    if (group.contains('двер')) return Icons.door_front_door_outlined;
    return Icons.chair_alt_outlined;
  }
}
