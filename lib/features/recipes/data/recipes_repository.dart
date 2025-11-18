import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe.dart';

class RecipesRepository {
  final FirebaseFirestore _db;
  RecipesRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('recipes');
  CollectionReference<Map<String, dynamic>> get _likesCol => _db.collection('recipe_likes');

  Future<String> addRecipe({required Recipe recipe}) async {
    final doc = await _col.add(recipe.toMap());
    return doc.id;
  }

  Future<void> updateRecipe({required Recipe recipe}) async {
    await _col.doc(recipe.id).update(recipe.toMap());
  }

  Future<void> deleteRecipe(String id) async {
    await _col.doc(id).delete();
  }

  Stream<List<Recipe>> watchUserRecipes(String ownerId) {
    return _col
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((qs) {
      final items = qs.docs.map((d) => Recipe.fromDoc(d)).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Future<Recipe> getById(String id) async {
    final snap = await _col.doc(id).get();
    return Recipe.fromDoc(snap);
  }

  /// Tarifi ID ile stream olarak izle (beğeni sayısı güncellemeleri için)
  Stream<Recipe> watchRecipeById(String id) {
    return _col.doc(id).snapshots().map((snap) {
      if (!snap.exists) {
        throw Exception('Recipe not found');
      }
      return Recipe.fromDoc(snap);
    });
  }

  /// Basit arama: keywords arrayContains query
  Stream<List<Recipe>> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const Stream<List<Recipe>>.empty();
    return _col.where('keywords', arrayContains: q).snapshots().map(
          (qs) => qs.docs.map((d) => Recipe.fromDoc(d)).toList(),
        );
  }

  /// Filtreli arama: query (keywords), mainType, subType, country
  Stream<List<Recipe>> searchFiltered({
    String? query,
    String? mainType,
    String? subType,
    String? country,
  }) {
    // Eğer query boş ve hiçbir filtre yoksa, boş stream döndür
    final hasQuery = query != null && query.trim().isNotEmpty;
    final hasMainType = mainType != null && mainType.isNotEmpty;
    final hasSubType = subType != null && subType.isNotEmpty;
    final hasCountry = country != null && country.isNotEmpty;
    
    if (!hasQuery && !hasMainType && !hasSubType && !hasCountry) {
      return const Stream<List<Recipe>>.empty();
    }
    
    Query<Map<String, dynamic>> q = _col;
    if (hasMainType) {
      q = q.where('mainType', isEqualTo: mainType);
    }
    if (hasSubType) {
      q = q.where('subType', isEqualTo: subType);
    }
    if (hasCountry) {
      q = q.where('country', isEqualTo: country);
    }
    if (hasQuery) {
      final kw = query.trim().toLowerCase();
      q = q.where('keywords', arrayContains: kw);
    }
    return q.snapshots().map((qs) {
      final items = qs.docs.map((d) => Recipe.fromDoc(d)).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  /// Beğeni arttır/azalt (transaction ile güvenli)
  Future<void> toggleLike({required String recipeId, required bool like}) async {
    await _db.runTransaction((tx) async {
      final ref = _col.doc(recipeId);
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final current = (snap.data()!['likesCount'] ?? 0) as int;
      final next = like ? current + 1 : (current > 0 ? current - 1 : 0);
      tx.update(ref, {'likesCount': next});
    });
  }

  /// Kullanıcı bu tarifi beğenmiş mi?
  Stream<bool> watchUserLiked({required String recipeId, required String userId}) {
    final docId = '${recipeId}_$userId';
    return _likesCol.doc(docId).snapshots().map((s) => s.exists && (s.data()?['liked'] == true));
  }

  /// Hem tarifin likesCount'unu günceller, hem de kullanıcı like kaydını setler/siler
  Future<void> setUserLike({required String recipeId, required String userId, required bool like}) async {
    final likeDocId = '${recipeId}_$userId';
    await _db.runTransaction((tx) async {
      final recipeRef = _col.doc(recipeId);
      final likeRef = _likesCol.doc(likeDocId);
      final recipeSnap = await tx.get(recipeRef);
      if (!recipeSnap.exists) return;
      final current = (recipeSnap.data()!['likesCount'] ?? 0) as int;
      final next = like ? current + 1 : (current > 0 ? current - 1 : 0);
      tx.update(recipeRef, {'likesCount': next});
      if (like) {
        tx.set(likeRef, {'recipeId': recipeId, 'userId': userId, 'liked': true, 'updatedAt': FieldValue.serverTimestamp()});
      } else {
        tx.delete(likeRef);
      }
    });
  }

  /// Kullanıcının beğendiği tarifler
  Stream<List<Recipe>> watchUserFavorites(String userId) {
    return _likesCol
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((likesSnap) async {
      final ids = likesSnap.docs.map((d) => d.data()['recipeId'] as String).toList();
      if (ids.isEmpty) return <Recipe>[];
      // Firestore whereIn limit 10; parçalara böl
      final List<Recipe> all = [];
      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final qs = await _col.where(FieldPath.documentId, whereIn: chunk).get();
        all.addAll(qs.docs.map((d) => Recipe.fromDoc(d)));
      }
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return all;
    });
  }

  /// Tüm tarifleri getir (kategori filtresi olmadan)
  Stream<List<Recipe>> watchAllRecipes() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map((d) => Recipe.fromDoc(d)).toList());
  }
}


