import '../../recipes/models/recipe.dart';
import 'shopping_item.dart';

class ShoppingEntry {
  final String id; // doc id
  final String ownerId;
  final String recipeId;
  final String recipeTitle;
  final List<ShoppingItem> items; // normalize edilmiş, birleştirilmiş
  final DateTime createdAt;

  const ShoppingEntry({
    required this.id,
    required this.ownerId,
    required this.recipeId,
    required this.recipeTitle,
    required this.items,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'recipeId': recipeId,
        'recipeTitle': recipeTitle,
        'items': items.map((e) => e.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory ShoppingEntry.fromMap(String id, Map<String, dynamic> map) => ShoppingEntry(
        id: id,
        ownerId: map['ownerId'] as String,
        recipeId: map['recipeId'] as String,
        recipeTitle: map['recipeTitle'] as String,
        items: (map['items'] as List).map((e) => ShoppingItem.fromMap(e as Map<String, dynamic>)).toList(),
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  static ShoppingEntry fromRecipe({required String? ownerId, required Recipe recipe}) {
    final normalized = _normalizeIngredients(recipe.ingredients);
    return ShoppingEntry(
      id: recipe.id,
      ownerId: ownerId ?? '',
      recipeId: recipe.id,
      recipeTitle: recipe.title,
      items: normalized,
      createdAt: DateTime.now(),
    );
  }

  // Basit normalizasyon: aynı isimdeki malzemeleri birleştir, miktar sayıya çevrilebiliyorsa topla
  static List<ShoppingItem> _normalizeIngredients(List<String> ingredients) {
    final Map<String, ShoppingItem> merged = {};
    for (final raw in ingredients) {
      final lower = raw.toLowerCase();
      final parsed = parseIngredientForMerge(lower);
      final key = parsed.name;
      final existing = merged[key];
      if (existing == null) {
        merged[key] = parsed;
      } else {
        final double q1 = existing.quantity ?? 0;
        final double q2 = parsed.quantity ?? 0;
        merged[key] = existing.copyWith(quantity: (q1 + q2) == 0 ? null : q1 + q2);
      }
    }
    return merged.values.toList();
  }

  // Çok basit bir ayrıştırıcı: "2 adet domates" -> name: domates, unit: adet, quantity: 2
  static ShoppingItem parseIngredientForMerge(String text) {
    final regex = RegExp(r"^(\d+(?:[\.,]\d+)?)\s*(adet|gr|kg|ml|l|yemek ka\s?\s?\*?\s?si|tatli kasigi|cay kasigi)?\s*(.*)$");
    final match = regex.firstMatch(text);
    if (match != null) {
      final q = double.tryParse(match.group(1)!.replaceAll(',', '.'));
      final unit = match.group(2)?.trim();
      final name = (match.group(3) ?? '').trim();
      if (name.isNotEmpty) return ShoppingItem(name: name, unit: unit, quantity: q);
    }
    // sayı bulunamazsa ismi komple al
    return ShoppingItem(name: text.trim());
  }
}


