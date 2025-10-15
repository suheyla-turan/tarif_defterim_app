import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/recipes_provider.dart';
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

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = SearchFilter(
      query: _qCtrl.text.trim().isEmpty ? null : _qCtrl.text,
      mainType: _mainType,
      subType: _subType,
      country: _country,
    );
    final results = ref.watch(recipesSearchFilteredProvider(filter));

    // alt tür listesi, bu sayfada doğrudan kullanılmıyor; alt sayfada hesaplanacak

    return Scaffold(
      appBar: AppBar(title: const Text('Arama')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Başlık, içerik, malzeme...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
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
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
              data: (list) {
                if (list.isEmpty) return const Center(child: Text('Sonuç yok'));
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final Recipe r = list[i];
                    return ListTile(
                      title: Text(r.title),
                      subtitle: Text('${r.mainType}${r.subType != null ? ' • ${r.subType}' : ''}${r.country != null ? ' • ${r.country}' : ''}'),
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


