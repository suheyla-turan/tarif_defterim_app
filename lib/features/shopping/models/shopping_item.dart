class ShoppingItem {
  final String name; // malzeme adı (lowercase normalize edilmiş)
  final String? unit; // birim: gr, kg, adet, ml vb.
  final double? quantity; // miktar (toplanabilir)

  const ShoppingItem({required this.name, this.unit, this.quantity});

  ShoppingItem copyWith({String? name, String? unit, double? quantity}) =>
      ShoppingItem(name: name ?? this.name, unit: unit ?? this.unit, quantity: quantity ?? this.quantity);

  Map<String, dynamic> toMap() => {
        'name': name,
        'unit': unit,
        'quantity': quantity,
      };

  factory ShoppingItem.fromMap(Map<String, dynamic> map) => ShoppingItem(
        name: (map['name'] as String).toLowerCase().trim(),
        unit: map['unit'] as String?,
        quantity: (map['quantity'] as num?)?.toDouble(),
      );
}


