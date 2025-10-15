import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shopping_entry.dart';

class ShoppingRepository {
  final FirebaseFirestore _db;
  ShoppingRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('shopping_lists');

  Future<void> addOrMergeEntry(ShoppingEntry entry) async {
    final ref = _col.doc('${entry.ownerId}_${entry.recipeId}');
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, entry.toMap());
        return;
      }
      // Var olan liste ile yeni malzemeleri birleştir
      final existing = ShoppingEntry.fromMap(ref.id, snap.data()!);
      final merged = _mergeItems(existing, entry);
      tx.update(ref, merged.toMap());
    });
  }

  ShoppingEntry _mergeItems(ShoppingEntry a, ShoppingEntry b) {
    final items = <String, Map<String, dynamic>>{};
    for (final it in a.items) {
      items[it.name] = {'unit': it.unit, 'quantity': it.quantity};
    }
    for (final it in b.items) {
      final prev = items[it.name];
      if (prev == null) {
        items[it.name] = {'unit': it.unit, 'quantity': it.quantity};
      } else {
        final q1 = (prev['quantity'] as double?) ?? 0;
        final q2 = it.quantity ?? 0;
        items[it.name] = {'unit': it.unit ?? prev['unit'], 'quantity': (q1 + q2) == 0 ? null : q1 + q2};
      }
    }
    return ShoppingEntry(
      id: a.id,
      ownerId: a.ownerId,
      recipeId: a.recipeId,
      recipeTitle: a.recipeTitle,
      items: items.entries
          .map((e) => {'name': e.key, ...e.value})
          .map((m) => ShoppingEntry.parseIngredientForMerge('${m['quantity'] ?? ''} ${m['unit'] ?? ''} ${m['name']}'))
          .toList(),
      createdAt: a.createdAt,
    );
  }

  Stream<List<ShoppingEntry>> watchMyList(String ownerId) {
    return _col
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map((d) => ShoppingEntry.fromMap(d.id, d.data())).toList());
  }

  Future<void> removeEntry({required String ownerId, required String recipeId}) async {
    await _col.doc('${ownerId}_$recipeId').delete();
  }
}


