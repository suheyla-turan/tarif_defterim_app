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
      
      // AI'den gelen öğeleri gr/kg ve ml/litre bazında birleştir & normalize et
      return _mergeAndNormalizeItems(items);
    } catch (e) {
      // AI başarısız olursa fallback kullan
      return _mergeAllItemsFallback(entries);
    }
  }

  List<ShoppingItem> _mergeAllItemsFallback(List<ShoppingEntry> entries) {
    // Tüm entry'lerdeki öğeleri tek listede topla
    final allItems = <ShoppingItem>[];
    for (final entry in entries) {
      allItems.addAll(entry.items);
    }
    // Ardından aynı malzemeleri gr/kg ve ml/litre cinsinden birleştir & normalize et
    return _mergeAndNormalizeItems(allItems);
  }

  /// Aynı isimdeki malzemeleri birleştirir ve birimleri normalize eder.
  /// Ağırlık: gr, g, kg -> önce gr'a, sonra 1000 gr ve üstünü kg'a çevirir.
  /// Hacim: ml, l, lt, litre -> önce ml'ye, sonra 1000 ml ve üstünü litreye çevirir.
  List<ShoppingItem> _mergeAndNormalizeItems(List<ShoppingItem> items) {
    // 1) Önce tüm bilinen birimleri temel birime (gram / mililitre) çevirerek topla
    final Map<String, ShoppingItem> merged = {};

    for (final item in items) {
      final nameKey = item.name.toLowerCase().trim();
      final rawUnit = item.unit?.toLowerCase().trim();
      final rawQuantity = item.quantity;

      String? baseUnit;
      double? baseQuantity = rawQuantity;

      if (rawQuantity != null && rawUnit != null) {
        // Ağırlık birimleri
        if (rawUnit == 'gr' ||
            rawUnit == 'g' ||
            rawUnit == 'gram' ||
            rawUnit == 'grams') {
          baseUnit = 'g';
          baseQuantity = rawQuantity;
        } else if (rawUnit == 'kg' || rawUnit == 'kilogram') {
          baseUnit = 'g';
          baseQuantity = rawQuantity * 1000.0;
        }
        // Hacim birimleri - temel ml
        else if (rawUnit == 'ml' || rawUnit == 'mililitre') {
          baseUnit = 'ml';
          baseQuantity = rawQuantity;
        } else if (rawUnit == 'l' ||
            rawUnit == 'lt' ||
            rawUnit == 'litre' ||
            rawUnit == 'liter') {
          baseUnit = 'ml';
          baseQuantity = rawQuantity * 1000.0;
        }
        // Türkçe mutfak birimleri -> yaklaşık ml
        else if (rawUnit.contains('çay bardağı') ||
            rawUnit.contains('cay bardagi')) {
          // 1 çay bardağı ~ 100 ml
          baseUnit = 'ml';
          baseQuantity = rawQuantity * 100.0;
        } else if (rawUnit.contains('su bardağı') ||
            rawUnit.contains('su bardagi')) {
          // 1 su bardağı ~ 200 ml
          baseUnit = 'ml';
          baseQuantity = rawQuantity * 200.0;
        } else if (rawUnit.contains('yemek kaşığı') ||
            rawUnit.contains('yemek kasigi')) {
          // 1 yemek kaşığı ~ 15 ml
          baseUnit = 'ml';
          baseQuantity = rawQuantity * 15.0;
        } else if (rawUnit.contains('tatlı kaşığı') ||
            rawUnit.contains('tatli kasigi')) {
          // 1 tatlı kaşığı ~ 10 ml
          baseUnit = 'ml';
          baseQuantity = rawQuantity * 10.0;
        } else if (rawUnit.contains('çay kaşığı') ||
            rawUnit.contains('cay kasigi')) {
          // 1 çay kaşığı ~ 5 ml
          baseUnit = 'ml';
          baseQuantity = rawQuantity * 5.0;
        } else {
          // Diğer/özel birimler (adet vb.) aynen bırak
          baseUnit = rawUnit;
          baseQuantity = rawQuantity;
        }
      } else {
        baseUnit = rawUnit;
        baseQuantity = rawQuantity;
      }

      final key = '$nameKey::${baseUnit ?? ''}';
      final existing = merged[key];
      if (existing == null) {
        merged[key] = ShoppingItem(
          name: nameKey,
          unit: baseUnit,
          quantity: baseQuantity,
        );
      } else {
        final q1 = existing.quantity ?? 0;
        final q2 = baseQuantity ?? 0;
        merged[key] = existing.copyWith(
          quantity: (q1 + q2) == 0 ? null : q1 + q2,
          unit: baseUnit,
        );
      }
    }

    // 2) Temel birimdeki değerleri kullanıcı dostu hale getir (kg / litre)
    final List<ShoppingItem> result = [];
    for (final item in merged.values) {
      String? unit = item.unit;
      double? qty = item.quantity;

      if (qty != null && unit != null) {
        // gram -> kg
        if (unit == 'g' && qty >= 1000) {
          qty = qty / 1000.0;
          unit = 'kg';
        }
        // ml -> litre
        else if (unit == 'ml' && qty >= 1000) {
          qty = qty / 1000.0;
          unit = 'l';
        }
      }

      result.add(item.copyWith(unit: unit, quantity: qty));
    }

    return result;
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


