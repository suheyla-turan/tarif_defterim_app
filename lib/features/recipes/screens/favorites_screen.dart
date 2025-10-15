import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/recipes_provider.dart';
import '../models/recipe.dart';
import 'recipe_detail_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Beğendiklerim')),
      body: favs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('Henüz beğendiğin bir tarif yok.'));
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
    );
  }
}


