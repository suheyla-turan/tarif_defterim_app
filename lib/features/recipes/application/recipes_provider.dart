import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/application/auth_controller.dart' as feature_auth;
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

final addRecipeControllerProvider =
    StateNotifierProvider<AddRecipeController, AddRecipeState>((ref) {
  final repo = ref.watch(recipesRepositoryProvider);
  final authState = ref.watch(feature_auth.authControllerProvider);
  return AddRecipeController(repo: repo, ownerId: authState.user?.uid);
});

class AddRecipeController extends StateNotifier<AddRecipeState> {
  final RecipesRepository _repo;
  final String? _ownerId;
  AddRecipeController({required RecipesRepository repo, required String? ownerId})
      : _repo = repo,
        _ownerId = ownerId,
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
  }) async {
    if (_ownerId == null) {
      state = state.copyWith(error: 'Oturum bulunamadı.');
      return;
    }

    state = state.copyWith(submitting: true, error: null, createdId: null);
    try {
      final keywords = Recipe.buildKeywords(
        title: title,
        description: description,
        country: country,
        mainType: mainType,
        subType: subType,
        ingredients: ingredients,
      );

      final normalizedCountry = (country ?? '').trim();
      final recipe = Recipe(
        id: const Uuid().v4(), // Firestore id yine doc id olacak, local referans için
        ownerId: _ownerId!,
        title: title.trim(),
        description: description?.trim(),
        mainType: mainType,
        subType: subType,
        country: normalizedCountry.isEmpty ? null : normalizedCountry,
        ingredients: ingredients.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        steps: steps.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        imageUrls: imageUrls,
        likesCount: 0,
        createdAt: DateTime.now(),
        keywords: keywords,
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

/// Aktif kullanıcının tarifleri (liste)
final myRecipesProvider = StreamProvider<List<Recipe>>((ref) {
  final auth = ref.watch(feature_auth.authControllerProvider).user;
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
  final auth = ref.watch(feature_auth.authControllerProvider).user;
  if (auth == null) return const Stream<List<Recipe>>.empty();
  final repo = ref.watch(recipesRepositoryProvider);
  return repo.watchUserFavorites(auth.uid);
});


