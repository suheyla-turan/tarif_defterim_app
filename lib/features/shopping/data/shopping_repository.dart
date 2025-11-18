import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shopping_entry.dart';
import '../models/shopping_item.dart';

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
    final Map<String, ShoppingItem> merged = {};
    
    // İlk entry'deki item'ları ekle
    for (final it in a.items) {
      merged[it.name] = it;
    }
    
    // İkinci entry'deki item'ları birleştir
    for (final it in b.items) {
      final existing = merged[it.name];
      if (existing == null) {
        merged[it.name] = it;
      } else {
        // Miktarları topla
        final q1 = existing.quantity ?? 0;
        final q2 = it.quantity ?? 0;
        final totalQuantity = (q1 + q2) == 0 ? null : q1 + q2;
        
        // Birimleri birleştir (varsa)
        final unit = it.unit ?? existing.unit;
        
        merged[it.name] = ShoppingItem(
          name: it.name,
          unit: unit,
          quantity: totalQuantity,
        );
      }
    }
    
    return ShoppingEntry(
      id: a.id,
      ownerId: a.ownerId,
      recipeId: a.recipeId,
      recipeTitle: a.recipeTitle,
      items: merged.values.toList(),
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


