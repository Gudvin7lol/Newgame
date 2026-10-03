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
    this.renderModelPreviews = true,
    this.embedded = false,
  });

  final String projectTitle;
  final VoidCallback? onBack;
  final ValueChanged<ObjectCatalogItem>? onAdd;
  final bool renderModelPreviews;
  final bool embedded;

  @override
  State<MasterEquipmentScreen> createState() => _MasterEquipmentScreenState();
}

class _MasterEquipmentScreenState extends State<MasterEquipmentScreen> {
  final TextEditingController _search = TextEditingController();
  String _category = 'Мягкая мебель';
  String _filter = 'Все';
  final Set<String> _favorites = <String>{};
  bool _favoritesOnly = false;

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
      return !item.group.contains('Сантех') &&
          !item.group.contains('Освещ') &&
          !item.group.contains('Электр');
    }
    return item.group.toLowerCase().contains(_filter.toLowerCase());
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
    final items = ObjectCatalog.items.where((item) {
      if (!_matchesTopFilter(item) || !_matchesCategory(item)) return false;
      if (_favoritesOnly && !_favorites.contains(item.id)) return false;
      return query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.group.toLowerCase().contains(query);
    }).toList();
    if (items.isNotEmpty || query.isNotEmpty || _favoritesOnly) return items;

    return ObjectCatalog.items.where((item) {
      if (!_matchesTopFilter(item)) return false;
      return query.isEmpty || item.name.toLowerCase().contains(query);
    }).take(12).toList();
  }

  void _add(ObjectCatalogItem item) {
    final callback = widget.onAdd;
    if (callback != null) {
      callback(item);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.name}: открой каталог из рабочего проекта для добавления')),
    );
  }

  Future<void> _showFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZamerColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Фильтры каталога', style: ZamerTypography.h3),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final label in _filters)
                      ChoiceChip(
                        selected: _filter == label,
                        label: Text(label),
                        onSelected: (_) {
                          setState(() => _filter = label);
                          setSheetState(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Только избранное'),
                  value: _favoritesOnly,
                  onChanged: (value) {
                    setState(() => _favoritesOnly = value);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _filter = 'Все';
                      _favoritesOnly = false;
                      _search.clear();
                    });
                    Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Сбросить фильтры'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(List<ObjectCatalogItem> items) => Column(
        children: [
          if (!widget.embedded)
            ZMasterTopBar(
              title: widget.projectTitle,
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
              onSettings: _showFilters,
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, widget.embedded ? 10 : 0, 16, 8),
            child: Row(
              children: [
                Expanded(child: Text('Оснащение', style: ZamerTypography.h2)),
                Text('${items.length} моделей', style: ZamerTypography.caption),
              ],
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
                      decoration: InputDecoration(
                        hintText: 'Поиск (диван, унитаз, дверь...)',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Очистить',
                                onPressed: _search.clear,
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: _showFilters,
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    child: Badge(
                      isLabelVisible: _favoritesOnly || _filter != 'Все',
                      child: const Icon(Icons.tune_rounded, size: 21),
                    ),
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
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, index) {
                final label = _filters[index];
                return ChoiceChip(
                  selected: label == _filter,
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
                    separatorBuilder: (_, _) => const SizedBox(height: 3),
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
                  child: items.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'По этим фильтрам ничего не найдено',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : GridView.builder(
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
                            renderModelPreview: widget.renderModelPreviews,
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
      );

  @override
  Widget build(BuildContext context) {
    final content = _content(_items);
    if (widget.embedded) {
      return ColoredBox(color: ZamerColors.background, child: content);
    }
    return Scaffold(
      backgroundColor: ZamerColors.background,
      body: SafeArea(child: content),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.item,
    required this.favorite,
    required this.renderModelPreview,
    required this.onFavorite,
    required this.onAdd,
  });

  final ObjectCatalogItem item;
  final bool favorite;
  final bool renderModelPreview;
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
                    if (renderModelPreview)
                      ZamerModelThumbnail(
                        catalogId: item.id,
                        size: 180,
                        fallback: _FallbackPreview(item: item),
                      )
                    else
                      _FallbackPreview(item: item),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton(
                        tooltip: favorite ? 'Убрать из избранного' : 'В избранное',
                        onPressed: onFavorite,
                        icon: Icon(
                          favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: favorite ? ZamerColors.accent : ZamerColors.textPrimary,
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
}

class _FallbackPreview extends StatelessWidget {
  const _FallbackPreview({required this.item});
  final ObjectCatalogItem item;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: ZamerColors.surfaceHigh,
        child: Icon(_fallbackIcon(item), size: 42, color: ZamerColors.textFaint),
      );
}

IconData _fallbackIcon(ObjectCatalogItem item) {
  final group = item.group.toLowerCase();
  if (group.contains('сантех')) return Icons.plumbing_outlined;
  if (group.contains('кух')) return Icons.kitchen_outlined;
  if (group.contains('кров')) return Icons.bed_outlined;
  if (group.contains('освещ')) return Icons.lightbulb_outline_rounded;
  if (group.contains('двер')) return Icons.door_front_door_outlined;
  return Icons.chair_alt_outlined;
}
