import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/recipes_provider.dart';
import '../../../core/providers/localization_provider.dart';
import '../models/recipe.dart';
import 'recipe_detail_screen.dart';
import 'add_recipe_screen.dart';

class MyRecipesScreen extends ConsumerWidget {
  const MyRecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(myRecipesProvider);
    final repo = ref.read(recipesRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myRecipesTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          
          // Tarif defteri simgeleri
          final bookIcons = [
            Icons.menu_book,
            Icons.book,
            Icons.menu_book_outlined,
            Icons.library_books,
            Icons.book_outlined,
            Icons.auto_stories,
            Icons.collections_bookmark,
            Icons.chrome_reader_mode,
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
            0.25, -0.3, 0.4, -0.2, 0.35,
            -0.4, 0.3, -0.25, 0.45, -0.35,
            0.2, -0.4, 0.3, -0.25, 0.4,
            -0.3, 0.25, -0.4, 0.35, -0.2,
            0.4, -0.3, 0.25, -0.35, 0.3,
            -0.25, 0.4, -0.3, 0.35, -0.2,
            0.3, -0.4, 0.25, -0.35, 0.4,
          ];
          
          // Opacity değerleri
          final opacities = [
            0.10, 0.12, 0.11, 0.13, 0.09,
            0.12, 0.10, 0.13, 0.11, 0.12,
            0.10, 0.13, 0.11, 0.12, 0.10,
            0.13, 0.11, 0.12, 0.10, 0.13,
            0.11, 0.12, 0.10, 0.13, 0.11,
            0.12, 0.10, 0.13, 0.11, 0.12,
            0.10, 0.13, 0.11, 0.12, 0.10,
          ];
          
          // Renkler
          final colors = [
            Colors.brown,
            Colors.orange,
            Colors.deepOrange,
            Colors.amber,
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
                  
                  final iconData = bookIcons[index % bookIcons.length];
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
              recipes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(l10n.noRecipes),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddRecipeScreen()),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addFirstRecipeButton),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final Recipe r = list[i];
              return Card(
                child: ListTile(
                  title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${r.mainType}${r.subType != null ? ' • ${r.subType}' : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite, size: 18, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Text('${r.likesCount}'),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l10n.deleteRecipe),
                              content: Text('${r.title} ${l10n.deleteRecipeConfirm}'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(l10n.cancel),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: Text(l10n.delete),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await repo.deleteRecipe(r.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.recipeDeleted)),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${l10n.error}: $e')),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: r)),
                  ),
                ),
              );
            },
          );
        },
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddRecipeScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.addRecipe),
      ),
    );
  }
}


