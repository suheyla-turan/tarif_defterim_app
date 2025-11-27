import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart' as feature_auth;
import 'package:firebase_auth/firebase_auth.dart';
import '../data/recipes_repository.dart';
import '../models/recipe.dart';

final recipesRepositoryProvider = Provider<RecipesRepository>((ref) => RecipesRepository());

class AddRecipeState {
  final bool submitting;
  final String? error;
  final String? createdId;

  const AddRecipeState({this.submitting = false, this.error, this.createdId});

  AddRecipeState copyWith({bool? submitting, String? error, String? createdId}) {
    return AddRecipeState(
      submitting: submitting ?? this.submitting,
      error: error,
      createdId: createdId,
    );
  }
}

class EditRecipeState {
  final bool submitting;
  final String? error;
  final bool success;

  const EditRecipeState({
    this.submitting = false,
    this.error,
    this.success = false,
  });

  EditRecipeState copyWith({
    bool? submitting,
    String? error,
    bool? success,
  }) {
    return EditRecipeState(
      submitting: submitting ?? this.submitting,
      error: error,
      success: success ?? this.success,
    );
  }
}

final addRecipeControllerProvider =
    StateNotifierProvider<AddRecipeController, AddRecipeState>((ref) {
  final repo = ref.watch(recipesRepositoryProvider);
  return AddRecipeController(ref: ref, repo: repo);
});

final editRecipeControllerProvider =
    StateNotifierProvider<EditRecipeController, EditRecipeState>((ref) {
  final repo = ref.watch(recipesRepositoryProvider);
  return EditRecipeController(repo: repo);
});

class AddRecipeController extends StateNotifier<AddRecipeState> {
  final RecipesRepository _repo;
  final Ref _ref;
  AddRecipeController({required Ref ref, required RecipesRepository repo})
      : _repo = repo,
        _ref = ref,
        super(const AddRecipeState());

  Future<void> submit({
    required String title,
    String? description,
    required String mainType,
    String? subType,
    String? country,
    List<String> ingredients = const [],
    List<String> steps = const [],
    List<String> imageUrls = const [],
    int? portions,
    List<IngredientGroup> ingredientGroups = const [],
  }) async {
    final User? fbUser = _ref.read(feature_auth.firebaseAuthStateProvider).value;
    final ownerId = fbUser?.uid;
    if (ownerId == null) {
      state = state.copyWith(error: 'Oturum bulunamadı.');
      return;
    }

    state = state.copyWith(submitting: true, error: null, createdId: null);
    try {
      final normalizedGroups = ingredientGroups
          .map(
            (group) => IngredientGroup(
              name: group.name.trim(),
              items: group.items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
            ),
          )
          .where((group) => group.items.isNotEmpty)
          .toList(growable: false);

      final normalizedIngredients = normalizedGroups.isNotEmpty
          ? normalizedGroups.expand((g) => g.items).toList()
          : ingredients.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      final keywords = Recipe.buildKeywords(
        title: title,
        description: description,
        country: country,
        mainType: mainType,
        subType: subType,
        ingredients: normalizedIngredients,
        ingredientGroups: normalizedGroups,
      );

      final normalizedCountry = (country ?? '').trim();
      final recipe = Recipe(
        id: const Uuid().v4(), // Firestore id yine doc id olacak, local referans için
        ownerId: ownerId,
        title: title.trim(),
        description: description?.trim(),
        mainType: mainType,
        subType: subType,
        country: normalizedCountry.isEmpty ? null : normalizedCountry,
        ingredients: normalizedIngredients,
        ingredientGroups: normalizedGroups,
        steps: steps.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        imageUrls: imageUrls,
        likesCount: 0,
        createdAt: DateTime.now(),
        keywords: keywords,
        portions: portions,
      );

      // Firestore doc id server tarafından atanacak; id alanını yok sayacağız
      final newId = await _repo.addRecipe(recipe: recipe);
      state = state.copyWith(submitting: false, createdId: newId);
    } on FirebaseException catch (e) {
      state = state.copyWith(submitting: false, error: e.message ?? 'Kayıt hatası');
    } catch (_) {
      state = state.copyWith(submitting: false, error: 'Bir hata oluştu');
    }
  }
}

class EditRecipeController extends StateNotifier<EditRecipeState> {
  final RecipesRepository _repo;

  EditRecipeController({required RecipesRepository repo})
      : _repo = repo,
        super(const EditRecipeState());

  Future<void> submit({required Recipe recipe}) async {
    state = state.copyWith(submitting: true, error: null, success: false);
    try {
      final trimmedTitle = recipe.title.trim();
      final trimmedDescription = recipe.description?.trim();
      final trimmedCountry = recipe.country?.trim() ?? '';
      final normalizedCountry = trimmedCountry.isEmpty ? null : trimmedCountry;
      final normalizedGroups = recipe.ingredientGroups
          .map(
            (group) => IngredientGroup(
              name: group.name.trim(),
              items: group.items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
            ),
          )
          .where((group) => group.items.isNotEmpty)
          .toList(growable: false);

      final normalizedIngredients = normalizedGroups.isNotEmpty
          ? normalizedGroups.expand((g) => g.items).toList()
          : recipe.resolvedIngredients
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
      final normalizedSteps =
          recipe.steps.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final keywords = Recipe.buildKeywords(
        title: trimmedTitle,
        description: trimmedDescription,
        country: normalizedCountry,
        mainType: recipe.mainType,
        subType: recipe.subType,
        ingredients: normalizedIngredients,
        ingredientGroups: normalizedGroups,
      );
      final updatedRecipe = recipe.copyWith(
        title: trimmedTitle,
        description: trimmedDescription,
        country: normalizedCountry,
        ingredients: normalizedIngredients,
        ingredientGroups: normalizedGroups,
        steps: normalizedSteps,
        keywords: keywords,
      );
      await _repo.updateRecipe(recipe: updatedRecipe);
      state = state.copyWith(submitting: false, success: true);
    } on FirebaseException catch (e) {
      state = state.copyWith(
        submitting: false,
        error: e.message ?? 'Güncelleme hatası',
      );
    } catch (_) {
      state =
          state.copyWith(submitting: false, error: 'Bir hata oluştu, tekrar deneyin');
    }
  }
}

/// Aktif kullanıcının tarifleri (liste)
final myRecipesProvider = StreamProvider<List<Recipe>>((ref) {
  final auth = ref.watch(feature_auth.firebaseAuthStateProvider).value;
  final repo = ref.watch(recipesRepositoryProvider);
  if (auth == null) return const Stream<List<Recipe>>.empty();
  return repo.watchUserRecipes(auth.uid);
});

/// Basit arama provider'ı
final recipesSearchProvider = StreamProvider.family<List<Recipe>, String>((ref, query) {
  final repo = ref.watch(recipesRepositoryProvider);
  return repo.search(query);
});

class SearchFilter {
  final String? query;
  final String? mainType;
  final String? subType;
  final String? country;

  const SearchFilter({this.query, this.mainType, this.subType, this.country});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchFilter &&
        other.query == query &&
        other.mainType == mainType &&
        other.subType == subType &&
        other.country == country;
  }

  @override
  int get hashCode => Object.hash(query, mainType, subType, country);

  @override
  String toString() =>
      'SearchFilter(query: $query, mainType: $mainType, subType: $subType, country: $country)';
}

final recipesSearchFilteredProvider =
    StreamProvider.family<List<Recipe>, SearchFilter>((ref, filter) {
  final repo = ref.watch(recipesRepositoryProvider);
  return repo.searchFiltered(
    query: filter.query,
    mainType: filter.mainType,
    subType: filter.subType,
    country: filter.country,
  );
});

final favoritesProvider = StreamProvider<List<Recipe>>((ref) {
  final auth = ref.watch(feature_auth.firebaseAuthStateProvider).value;
  if (auth == null) return const Stream<List<Recipe>>.empty();
  final repo = ref.watch(recipesRepositoryProvider);
  return repo.watchUserFavorites(auth.uid);
});


