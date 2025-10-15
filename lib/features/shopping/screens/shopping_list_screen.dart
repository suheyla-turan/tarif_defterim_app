import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/shopping_provider.dart';

class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(myShoppingListProvider);
    final ctrl = ref.read(shoppingControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Alışveriş Listem')),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (entries) {
          if (entries.isEmpty) return const Center(child: Text('Liste boş.'));
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (ctx, i) {
              final e = entries[i];
              return ExpansionTile(
                title: Text(e.recipeTitle),
                subtitle: Text('${e.items.length} kalem'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ctrl.removeRecipeFromList(e.recipeId),
                ),
                children: [
                  ...e.items.map((it) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.shopping_cart_outlined),
                        title: Text(it.name),
                        subtitle: (it.quantity != null || (it.unit ?? '').isNotEmpty)
                            ? Text('${it.quantity ?? ''} ${it.unit ?? ''}'.trim())
                            : null,
                      )),
                ],
              );
            },
          );
        },
      ),
    );
  }
}


