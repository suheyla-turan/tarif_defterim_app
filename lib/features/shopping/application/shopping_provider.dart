import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/providers/auth_provider.dart';
import '../data/shopping_repository.dart';
import '../models/shopping_entry.dart';
import '../models/shopping_item.dart';
import '../../recipes/models/recipe.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) => ShoppingRepository());

final myShoppingListProvider = StreamProvider<List<ShoppingEntry>>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) return const Stream<List<ShoppingEntry>>.empty();
  final repo = ref.watch(shoppingRepositoryProvider);
  return repo.watchMyList(user.uid);
});

class ShoppingController extends StateNotifier<AsyncValue<void>> {
  final ShoppingRepository _repo;
  final String? _ownerId;
  ShoppingController(this._repo, this._ownerId) : super(const AsyncData(null));

  Future<void> addRecipeToList(Recipe recipe) async {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      state = AsyncError('Lütfen giriş yapın', StackTrace.current);
      return;
    }
    state = const AsyncLoading();
    try {
      // AI ile malzemeleri normalize et
      final entry = await ShoppingEntry.fromRecipe(
        ownerId: ownerId,
        recipe: recipe,
        aiNormalize: _normalizeWithAI,
      );
      if (entry.items.isEmpty) {
        state = AsyncError('Tarifte malzeme bulunamadı', StackTrace.current);
        return;
      }
      await _repo.addOrMergeEntry(entry);
      state = const AsyncData(null);
    } catch (e, st) {
      // Hata mesajını daha anlaşılır hale getir
      final errorMessage = e.toString().contains('permission-denied')
          ? 'Alışveriş listesine ekleme izniniz yok'
          : e.toString().contains('network')
              ? 'İnternet bağlantısı hatası'
              : 'Alışveriş listesine eklenirken hata oluştu: ${e.toString()}';
      state = AsyncError(errorMessage, st);
    }
  }

  Future<List<ShoppingItem>> _normalizeWithAI(List<String> ingredients) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('parseShoppingIngredients');
      final result = await callable.call({'ingredients': ingredients});
      
      final data = result.data as Map<String, dynamic>;
      final items = (data['items'] as List).map((item) {
        final map = item as Map<String, dynamic>;
        return ShoppingItem(
          name: (map['name'] as String? ?? '').toLowerCase().trim(),
          unit: map['unit'] as String?,
          quantity: (map['quantity'] as num?)?.toDouble(),
        );
      }).toList();
      
      return items;
    } catch (e) {
      // AI başarısız olursa exception fırlat, fallback kullanılsın
      throw e;
    }
  }

  Future<List<ShoppingItem>> mergeShoppingListWithAI(List<ShoppingEntry> entries) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('mergeShoppingList');
      
      // ShoppingEntry'leri AI'ya gönderilecek formata çevir
      final recipesData = entries.map((entry) {
        return {
          'recipeId': entry.recipeId,
          'recipeTitle': entry.recipeTitle,
          'items': entry.items.map((item) {
            return {
              'name': item.name,
              'quantity': item.quantity,
              'unit': item.unit,
            };
          }).toList(),
        };
      }).toList();
      
      final result = await callable.call({'recipes': recipesData});
      
      final data = result.data as Map<String, dynamic>;
      final items = (data['items'] as List).map((item) {
        final map = item as Map<String, dynamic>;
        return ShoppingItem(
          name: (map['name'] as String? ?? '').toLowerCase().trim(),
          unit: map['unit'] as String?,
          quantity: (map['quantity'] as num?)?.toDouble(),
        );
      }).toList();
      
      return items;
    } catch (e) {
      // AI başarısız olursa fallback kullan
      return _mergeAllItemsFallback(entries);
    }
  }

  List<ShoppingItem> _mergeAllItemsFallback(List<ShoppingEntry> entries) {
    final Map<String, ShoppingItem> merged = {};
    for (final entry in entries) {
      for (final item in entry.items) {
        final key = item.name.toLowerCase();
        if (merged.containsKey(key)) {
          final existing = merged[key]!;
          final q1 = existing.quantity ?? 0;
          final q2 = item.quantity ?? 0;
          merged[key] = existing.copyWith(
            quantity: (q1 + q2) == 0 ? null : q1 + q2,
            unit: item.unit ?? existing.unit,
          );
        } else {
          merged[key] = item;
        }
      }
    }
    return merged.values.toList();
  }

  Future<void> removeRecipeFromList(String recipeId) async {
    if (_ownerId == null) return;
    state = const AsyncLoading();
    try {
      await _repo.removeEntry(ownerId: _ownerId, recipeId: recipeId);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final shoppingControllerProvider =
    StateNotifierProvider<ShoppingController, AsyncValue<void>>((ref) {
  final repo = ref.watch(shoppingRepositoryProvider);
  final uid = ref.watch(authControllerProvider).user?.uid;
  return ShoppingController(repo, uid);
});


