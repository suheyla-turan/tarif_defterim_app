import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/shopping_provider.dart';
import '../../../core/providers/localization_provider.dart';
import '../models/shopping_entry.dart';
import '../models/shopping_item.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  bool _showMergedList = false;
  List<ShoppingItem>? _aiMergedItems;
  bool _isMergingWithAI = false;
  List<String>? _lastEntryIds; // Entries değişikliğini takip etmek için

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(myShoppingListProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myShoppingList),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_showMergedList ? Icons.list : Icons.view_list),
            tooltip: _showMergedList ? 'Tariflere göre göster' : 'Birleştirilmiş liste',
            onPressed: () {
              setState(() {
                _showMergedList = !_showMergedList;
              });
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          
          // Alışveriş arabası simgeleri
          final cartIcons = [
            Icons.shopping_cart,
            Icons.shopping_bag,
            Icons.shopping_basket,
            Icons.shopping_cart_outlined,
            Icons.local_grocery_store,
            Icons.store,
            Icons.storefront,
            Icons.add_shopping_cart,
          ];
          
          // Grid parametreleri
          final cols = 5;
          final rows = 7;
          final cellWidth = screenWidth / cols;
          final cellHeight = screenHeight / rows;
          final iconSize = (cellWidth * 0.4).clamp(35.0, 65.0);
          final spacing = cellWidth * 0.15;
          final maxOffset = cellWidth * 0.3;
          
          // Rotasyon açıları
          final rotations = [
            -0.2, 0.35, -0.3, 0.25, -0.4,
            0.3, -0.25, 0.4, -0.35, 0.2,
            -0.4, 0.3, -0.35, 0.25, -0.3,
            0.4, -0.2, 0.35, -0.3, 0.25,
            -0.35, 0.4, -0.25, 0.3, -0.2,
            0.35, -0.4, 0.25, -0.3, 0.4,
            -0.25, 0.35, -0.3, 0.2, -0.4,
          ];
          
          // Opacity değerleri
          final opacities = [
            0.11, 0.09, 0.12, 0.10, 0.13,
            0.11, 0.12, 0.10, 0.13, 0.09,
            0.12, 0.10, 0.13, 0.11, 0.12,
            0.10, 0.13, 0.11, 0.12, 0.10,
            0.13, 0.11, 0.12, 0.10, 0.13,
            0.11, 0.12, 0.10, 0.13, 0.11,
            0.12, 0.10, 0.13, 0.11, 0.12,
          ];
          
          // Renkler
          final colors = [
            Colors.green,
            Colors.teal,
            Colors.cyan,
            Colors.lightGreen,
            Colors.grey,
            Colors.blueGrey,
          ];
          
          return Stack(
            children: [
              // Arka plan dekoratif simgeler
              ...List.generate(
                cols * rows,
                (index) {
                  final row = index ~/ cols;
                  final col = index % cols;
                  
                  final baseX = cellWidth * (col + 0.5) - iconSize / 2;
                  final baseY = cellHeight * (row + 0.5) - iconSize / 2;
                  
                  final offsetX = ((index % 7) - 3) * (maxOffset / 3);
                  final offsetY = ((index % 5) - 2) * (maxOffset / 3);
                  
                  final x = (baseX + offsetX).clamp(spacing, screenWidth - iconSize - spacing);
                  final y = (baseY + offsetY).clamp(spacing, screenHeight - iconSize - spacing);
                  
                  final iconData = cartIcons[index % cartIcons.length];
                  final rotation = rotations[index % rotations.length];
                  final opacity = opacities[index % opacities.length];
                  final color = colors[index % colors.length];
                  
                  return Positioned(
                    left: x,
                    top: y,
                    child: Transform.rotate(
                      angle: rotation,
                      child: Icon(
                        iconData,
                        size: iconSize,
                        color: color.withOpacity(opacity),
                      ),
                    ),
                  );
                },
              ),
              // İçerik
              list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(l10n.emptyList),
                ],
              ),
            );
          }

          if (_showMergedList) {
            // Entries değişti mi kontrol et
            final currentEntryIds = entries.map((e) => e.id).toList()..sort();
            final entryIdsChanged = _lastEntryIds == null || 
                !_listEquals(_lastEntryIds!, currentEntryIds);
            
            if (entryIdsChanged) {
              _lastEntryIds = currentEntryIds;
              _aiMergedItems = null; // Yeni birleştirme için sıfırla
            }
            
            // AI ile birleştirilmiş liste
            if (_isMergingWithAI) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final mergedItems = _aiMergedItems;
            if (mergedItems == null) {
              // İlk kez birleştirilmiş listeyi gösteriyoruz, AI ile birleştir
              _mergeWithAI(entries);
              return const Center(child: CircularProgressIndicator());
            }
            
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: mergedItems.length,
              itemBuilder: (ctx, i) {
                final item = mergedItems[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.shopping_cart_outlined),
                    title: Text(item.name),
                    subtitle: (item.quantity != null || (item.unit ?? '').isNotEmpty)
                        ? Text('${item.quantity ?? ''} ${item.unit ?? ''}'.trim())
                        : null,
                  ),
                );
              },
            );
          }

          // Tariflere göre liste
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.addedRecipes,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        title: Text(e.recipeTitle),
                        subtitle: Text('${e.items.length} ${l10n.items}'),
                        children: [
                          ...e.items.map((it) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.check_circle_outline),
                                title: Text(it.name),
                                subtitle: (it.quantity != null || (it.unit ?? '').isNotEmpty)
                                    ? Text('${it.quantity ?? ''} ${it.unit ?? ''}'.trim())
                                    : null,
                              )),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showMergedList = true;
                        _aiMergedItems = null; // Yeni birleştirme için sıfırla
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.view_list),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.listItems,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  l10n.mergedList,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _mergeWithAI(List<ShoppingEntry> entries) async {
    if (_isMergingWithAI) return;
    
    setState(() {
      _isMergingWithAI = true;
    });

    try {
      final ctrl = ref.read(shoppingControllerProvider.notifier);
      final mergedItems = await ctrl.mergeShoppingListWithAI(entries);
      
      if (mounted) {
        setState(() {
          _aiMergedItems = mergedItems;
          _isMergingWithAI = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMergingWithAI = false;
        });
        // Hata durumunda fallback kullanılacak, ama şimdilik boş liste göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Birleştirme hatası: $e')),
          );
        }
      }
    }
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}


