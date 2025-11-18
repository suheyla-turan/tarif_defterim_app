import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/recipes_provider.dart';
import '../../../core/providers/localization_provider.dart';
import '../constants/recipe_types.dart';
import '../models/recipe.dart';
import 'recipe_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _qCtrl = TextEditingController();
  String? _mainType;
  String? _subType;
  String? _country;
  List<String> _searchHistory = [];
  static const String _historyKey = 'search_history';

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList(_historyKey) ?? [];
    });
  }

  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, _searchHistory);
  }

  Future<void> _addToHistory(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _searchHistory.remove(query.trim());
      _searchHistory.insert(0, query.trim());
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.sublist(0, 10);
      }
    });
    await _saveSearchHistory();
  }

  Future<void> _removeFromHistory(String query) async {
    setState(() {
      _searchHistory.remove(query);
    });
    await _saveSearchHistory();
  }

  Future<void> _clearHistory() async {
    setState(() {
      _searchHistory.clear();
    });
    await _saveSearchHistory();
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim();
    final hasQuery = query != null && query.isNotEmpty;
    final hasFilters = _mainType != null || _subType != null || (_country != null && _country!.isNotEmpty);
    
    final filter = SearchFilter(
      query: query,
      mainType: _mainType,
      subType: _subType,
      country: _country,
    );
    
    // Sadece query veya filter varsa provider'ı izle
    final shouldSearch = hasQuery || hasFilters;
    final results = shouldSearch ? ref.watch(recipesSearchFilteredProvider(filter)) : null;

    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.search),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.searchPlaceholder,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _qCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _qCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _addToHistory(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () => _openFilters(context),
                )
              ],
            ),
          ),
          // Geçmiş aramalar veya boş mesajı
          if (!shouldSearch) ...[
            if (_searchHistory.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.searchHistory,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    TextButton(
                      onPressed: _clearHistory,
                      child: Text(l10n.clear),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _searchHistory.length,
                  itemBuilder: (ctx, i) {
                    final query = _searchHistory[i];
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(query),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _removeFromHistory(query),
                      ),
                      onTap: () {
                        _qCtrl.text = query;
                        setState(() {});
                        _addToHistory(query);
                      },
                    );
                  },
                ),
              ),
            ] else
              Expanded(
                child: Center(
                  child: Text(
                    l10n.searchHistoryEmpty,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                  ),
                ),
              ),
          ] else
            Expanded(
              child: results!.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
                data: (list) {
                  if (list.isEmpty) return Center(child: Text(l10n.noResults));
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final Recipe r = list[i];
                      return ListTile(
                        title: Text(r.title),
                        subtitle: Text(_formatRecipeSubtitle(r, l10n)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite, size: 18, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text('${r.likesCount}')
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: r)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _formatRecipeSubtitle(Recipe recipe, AppLocalizations l10n) {
    final parts = <String>[];
    parts.add(_getMainTypeDisplayName(recipe.mainType, l10n));
    if (recipe.subType != null) {
      parts.add(_getSubTypeDisplayName(recipe.subType!, l10n));
    }
    if (recipe.country != null && recipe.country!.isNotEmpty) {
      parts.add(recipe.country!);
    }
    return parts.join(' • ');
  }

  String _getMainTypeDisplayName(String mainType, AppLocalizations l10n) {
    switch (mainType) {
      case 'yemek':
        return l10n.meals;
      case 'tatli':
        return l10n.desserts;
      case 'icecek':
        return l10n.drinks;
      default:
        return mainType;
    }
  }

  String _getSubTypeDisplayName(String subType, AppLocalizations l10n) {
    switch (subType) {
      case 'corba':
        return l10n.soup;
      case 'ana_yemek':
        return l10n.mainDish;
      case 'meze':
        return l10n.appetizer;
      case 'salata':
        return l10n.salad;
      case 'hamur_isi':
        return l10n.pastry;
      case 'sutlu':
        return l10n.milky;
      case 'serbetli':
        return l10n.syrupy;
      case 'kek_pasta':
        return l10n.cake;
      case 'kurabiye':
        return l10n.cookie;
      case 'sicak':
        return l10n.hot;
      case 'soguk':
        return l10n.cold;
      case 'smoothie':
        return l10n.smoothie;
      default:
        return subType;
    }
  }

  Future<void> _openFilters(BuildContext context) async {
    final selected = await showModalBottomSheet<_SearchFilterResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        String? mainType = _mainType;
        String? subType = _subType;
        String? country = _country;
        return StatefulBuilder(builder: (context, setModal) {
          final subTypes = mainType == null ? const <String>[] : RecipeTypes.subTypesOf(mainType!);
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              top: 8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  value: mainType,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Hepsi')),
                    ...RecipeTypes.mainTypes.map((e) => DropdownMenuItem<String?>(value: e, child: Text(e)))
                  ],
                  onChanged: (v) => setModal(() {
                    mainType = v;
                    subType = null;
                  }),
                  decoration: const InputDecoration(labelText: 'Tür'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: subType,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Hepsi')),
                    ...subTypes.map((e) => DropdownMenuItem<String?>(value: e, child: Text(e)))
                  ],
                  onChanged: (v) => setModal(() => subType = v),
                  decoration: const InputDecoration(labelText: 'Alt tür'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: country,
                  decoration: const InputDecoration(labelText: 'Ülke'),
                  onChanged: (v) => country = v.trim().isEmpty ? null : v.trim(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, const _SearchFilterResult()),
                        child: const Text('Temizle'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, _SearchFilterResult(
                          mainType: mainType,
                          subType: subType,
                          country: country,
                        )),
                        child: const Text('Uygula'),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        });
      },
    );

    if (selected != null) {
      setState(() {
        _mainType = selected.mainType;
        _subType = selected.subType;
        _country = selected.country;
      });
    }
  }
}

class _SearchFilterResult {
  final String? mainType;
  final String? subType;
  final String? country;
  const _SearchFilterResult({this.mainType, this.subType, this.country});
}


