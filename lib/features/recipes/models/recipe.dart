import 'package:cloud_firestore/cloud_firestore.dart';

/// Uygulamanın temel tarif modeli
class Recipe {
  final String id; // Firestore doc id
  final String ownerId;
  final String title;
  final String? description;

  /// Ana tür: yemek, tatli, icecek
  final String mainType;

  /// Alt tür: örn. yemek -> [corba, ana_yemek, meze], tatli -> [sutlu, serbetli], icecek -> [sicak, soguk]
  final String? subType;

  /// Ülke (opsiyonel)
  final String? country;

  /// Malzemeler listesi (opsiyonel ama önerilir)
  final List<String> ingredients;

  /// Tarif adımları (sıralı)
  final List<String> steps;

  /// İsteğe bağlı görseller
  final List<String> imageUrls;

  /// Beğeni sayısı (server tarafında artar/azalır)
  final int likesCount;

  /// Oluşturulma zamanı
  final DateTime createdAt;

  /// Basit arama için indekslenen anahtar kelimeler (lowercase)
  final List<String> keywords;

  /// Tarifin porsiyon sayısı (opsiyonel, varsayılan 1)
  final int? portions;

  const Recipe({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    required this.mainType,
    this.subType,
    this.country,
    required this.ingredients,
    required this.steps,
    required this.imageUrls,
    required this.likesCount,
    required this.createdAt,
    required this.keywords,
    this.portions,
  });

  Recipe copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? description,
    String? mainType,
    String? subType,
    String? country,
    List<String>? ingredients,
    List<String>? steps,
    List<String>? imageUrls,
    int? likesCount,
    DateTime? createdAt,
    List<String>? keywords,
    int? portions,
  }) {
    return Recipe(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      mainType: mainType ?? this.mainType,
      subType: subType ?? this.subType,
      country: country ?? this.country,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      imageUrls: imageUrls ?? this.imageUrls,
      likesCount: likesCount ?? this.likesCount,
      createdAt: createdAt ?? this.createdAt,
      keywords: keywords ?? this.keywords,
      portions: portions ?? this.portions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'mainType': mainType,
      'subType': subType,
      'country': country,
      'ingredients': ingredients,
      'steps': steps,
      'imageUrls': imageUrls,
      'likesCount': likesCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'keywords': keywords,
      'portions': portions,
    };
  }

  factory Recipe.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Recipe(
      id: doc.id,
      ownerId: data['ownerId'] as String,
      title: (data['title'] as String).trim(),
      description: data['description'] as String?,
      mainType: data['mainType'] as String,
      subType: data['subType'] as String?,
      country: data['country'] as String?,
      ingredients: List<String>.from((data['ingredients'] ?? const <String>[]) as List),
      steps: List<String>.from((data['steps'] ?? const <String>[]) as List),
      imageUrls: List<String>.from((data['imageUrls'] ?? const <String>[]) as List),
      likesCount: (data['likesCount'] ?? 0) as int,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      keywords: List<String>.from((data['keywords'] ?? const <String>[]) as List),
      portions: data['portions'] as int?,
    );
  }

  factory Recipe.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parseCreatedAt(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is DateTime) {
        return value;
      } else if (value is String) {
        return DateTime.parse(value);
      } else {
        return DateTime.now();
      }
    }

    return Recipe(
      id: id ?? map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String,
      title: (map['title'] as String).trim(),
      description: map['description'] as String?,
      mainType: map['mainType'] as String,
      subType: map['subType'] as String?,
      country: map['country'] as String?,
      ingredients: List<String>.from((map['ingredients'] ?? const <String>[]) as List),
      steps: List<String>.from((map['steps'] ?? const <String>[]) as List),
      imageUrls: List<String>.from((map['imageUrls'] ?? const <String>[]) as List),
      likesCount: (map['likesCount'] ?? 0) as int,
      createdAt: parseCreatedAt(map['createdAt'] ?? DateTime.now()),
      keywords: List<String>.from((map['keywords'] ?? const <String>[]) as List),
      portions: map['portions'] as int?,
    );
  }

  static List<String> buildKeywords({
    required String title,
    String? description,
    String? country,
    required String mainType,
    String? subType,
    List<String> ingredients = const [],
  }) {
    final pool = <String>{};

    void addTerms(String? text) {
      if (text == null || text.trim().isEmpty) return;
      final t = text.toLowerCase().trim();
      pool.add(t);
      for (final part in t.split(RegExp(r'\s+'))) {
        if (part.isNotEmpty) pool.add(part);
      }
    }

    addTerms(title);
    addTerms(description);
    addTerms(country);
    addTerms(mainType);
    addTerms(subType);
    for (final ing in ingredients) {
      addTerms(ing);
    }
    return pool.toList(growable: false);
  }
}


