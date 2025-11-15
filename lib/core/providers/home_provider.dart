import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart'; // aynı klasörde

/// AppBar altındaki selamlama metni
final greetingProvider = Provider<String>((ref) {
  final u = ref.watch(authControllerProvider).user;
  return 'Hoş geldin, ${u?.displayName ?? u?.email ?? 'kullanıcı'}';
});

/// (opsiyonel) menü/sekme seçimi
final menuIndexProvider = StateProvider<int>((_) => 0);

/// Aktif kullanıcının tarifleri (recipes.ownerId == uid)
final recipesStreamProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(authControllerProvider).user?.uid;
  if (uid == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('recipes')
      .where('ownerId', isEqualTo: uid)
      .snapshots();
});
