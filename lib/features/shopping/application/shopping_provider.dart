import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart' as feature_auth;
import '../data/shopping_repository.dart';
import '../models/shopping_entry.dart';
import '../../recipes/models/recipe.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) => ShoppingRepository());

final myShoppingListProvider = StreamProvider<List<ShoppingEntry>>((ref) {
  final user = ref.watch(feature_auth.authControllerProvider).user;
  if (user == null) return const Stream<List<ShoppingEntry>>.empty();
  final repo = ref.watch(shoppingRepositoryProvider);
  return repo.watchMyList(user.uid);
});

class ShoppingController extends StateNotifier<AsyncValue<void>> {
  final ShoppingRepository _repo;
  final String? _ownerId;
  ShoppingController(this._repo, this._ownerId) : super(const AsyncData(null));

  Future<void> addRecipeToList(Recipe recipe) async {
    if (_ownerId == null) {
      state = AsyncError('Oturum yok', StackTrace.current);
      return;
    }
    state = const AsyncLoading();
    try {
      final entry = ShoppingEntry.fromRecipe(ownerId: _ownerId, recipe: recipe);
      await _repo.addOrMergeEntry(entry);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
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
  final uid = ref.watch(feature_auth.authControllerProvider).user?.uid;
  return ShoppingController(repo, uid);
});


