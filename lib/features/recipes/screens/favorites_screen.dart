import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/recipes_provider.dart';
import '../../../core/providers/localization_provider.dart';
import '../models/recipe.dart';
import 'recipe_detail_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myFavorites),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          
          // Kalp simgeleri
          final heartIcons = [
            Icons.favorite,
            Icons.favorite_border,
            Icons.favorite_outline,
            Icons.favorite_outlined,
            Icons.heart_broken,
            Icons.favorite_rounded,
            Icons.favorite_border_rounded,
            Icons.volunteer_activism,
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
            0.3, -0.25, 0.4, -0.2, 0.35,
            -0.4, 0.25, -0.3, 0.45, -0.35,
            0.2, -0.4, 0.3, -0.25, 0.4,
            -0.3, 0.25, -0.4, 0.35, -0.2,
            0.4, -0.3, 0.25, -0.35, 0.3,
            -0.25, 0.4, -0.3, 0.35, -0.2,
            0.3, -0.4, 0.25, -0.35, 0.4,
          ];
          
          // Opacity değerleri
          final opacities = [
            0.12, 0.10, 0.13, 0.11, 0.12,
            0.10, 0.13, 0.11, 0.12, 0.10,
            0.13, 0.11, 0.12, 0.10, 0.13,
            0.11, 0.12, 0.10, 0.13, 0.11,
            0.12, 0.10, 0.13, 0.11, 0.12,
            0.10, 0.13, 0.11, 0.12, 0.10,
            0.13, 0.11, 0.12, 0.10, 0.13,
          ];
          
          // Renkler
          final colors = [
            Colors.red,
            Colors.pink,
            Colors.redAccent,
            Colors.deepOrange,
            Colors.orange,
            Colors.grey,
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
                  
                  final iconData = heartIcons[index % heartIcons.length];
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
              favs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(l10n.noFavorites),
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
    );
  }
}


