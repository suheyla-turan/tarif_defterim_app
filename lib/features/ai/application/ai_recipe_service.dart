import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../recipes/models/recipe.dart';

enum RecipeTransformType { vegan, diet, portion }

final aiRecipeServiceProvider = Provider<AiRecipeService>((ref) {
  return AiRecipeService();
});

class AiRecipeService {
  final FirebaseFunctions _functions;
  
  AiRecipeService({FirebaseFunctions? functions}) 
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Cloud Functions ile AI dönüştürme
  Future<Recipe> transformRecipe({
    required Recipe base,
    required RecipeTransformType type,
    int? targetPortions,
  }) async {
    try {
      // Cloud Functions çağrısı
      final callable = _functions.httpsCallable('transformRecipe');
      final result = await callable.call({
        'recipe': base.toMap(),
        'transformType': type.name,
        'targetPortions': targetPortions,
        'currentPortions': base.portions, // Mevcut porsiyon bilgisini gönder
      });
      
      final data = result.data as Map<String, dynamic>;
      return Recipe.fromMap(data['transformedRecipe'] as Map<String, dynamic>);
    } catch (e) {
      // Cloud Functions başarısız olursa fallback olarak basit dönüştürme kullan
      debugPrint('AI transform error: $e, using fallback');
      return _transformFallback(base, type, targetPortions);
    }
  }

  /// Tarif hakkında soru-cevap
  /// Soruyu, verilen tarifin başlığı/malzemeleri/adımları bağlamında cevaplar.
  Future<String> askRecipeQuestion({
    required Recipe recipe,
    required String question,
    String? imageUrl,
  }) async {
    if (question.trim().isEmpty) {
      return 'Lütfen tarifle ilgili bir soru yazın.';
    }

    try {
      final callable = _functions.httpsCallable('askRecipeQuestion');
      final result = await callable.call({
        'recipe': recipe.toMap(),
        'question': question.trim(),
        'imageUrl': imageUrl,
      });

      final data = result.data as Map<String, dynamic>;
      final answer = data['answer'] as String?;
      if (answer == null || answer.trim().isEmpty) {
        return 'Şu anda bu tarif hakkında yanıt veremiyorum. Lütfen daha sonra tekrar deneyin.';
      }
      return answer.trim();
    } catch (e) {
      debugPrint('AI recipe QA error: $e, using fallback');
      // Basit fallback: tarife dayalı sabit bir cevap
      final buf = StringBuffer();
      buf.writeln(
        'Şu anda akıllı cevap veremiyorum ama elimdeki tarif bilgilerini paylaşabilirim:\n',
      );
      buf.writeln('Tarif: ${recipe.title}');
      if (recipe.portions != null) {
        buf.writeln('Porsiyon: ${recipe.portions}');
      }
      buf.writeln('\nMalzemeler:');
      for (final ing in recipe.ingredients) {
        buf.writeln('- $ing');
      }
      buf.writeln('\nAdımlar:');
      for (var i = 0; i < recipe.steps.length; i++) {
        buf.writeln('${i + 1}. ${recipe.steps[i]}');
      }
      return buf.toString();
    }
  }

  /// Fallback: Basit dönüştürme (Cloud Functions yoksa)
  Recipe _transformFallback(Recipe base, RecipeTransformType type, int? targetPortions) {
    switch (type) {
      case RecipeTransformType.vegan:
        return _makeVegan(base);
      case RecipeTransformType.diet:
        return _makeDiet(base);
      case RecipeTransformType.portion:
        return _scalePortions(base, targetPortions ?? 1);
    }
  }

  Recipe _makeVegan(Recipe base) {
    final replacements = <String, String>{
      'süt': 'bitkisel süt',
      'yoğurt': 'bitkisel yoğurt',
      'peynir': 'vegan peynir',
      'tereyağı': 'zeytinyağı',
      'yumurta': 'keten tohumu yumurtası',
      'bal': 'agave şurubu',
      'et': 'bitkisel protein',
      'tavuk': 'nohut/karnabahar',
      'kıyma': 'soya kıyması',
    };

    List<String> newIngredients = base.ingredients.map((ing) {
      var out = ing.toLowerCase();
      for (final entry in replacements.entries) {
        out = out.replaceAll(entry.key, entry.value);
      }
      return _capitalizeLike(ing, out);
    }).toList(growable: false);

    List<String> newSteps = base.steps.map((s) {
      var out = s.toLowerCase();
      for (final entry in replacements.entries) {
        out = out.replaceAll(entry.key, entry.value);
      }
      return _capitalizeLike(s, out);
    }).toList(growable: false);

    return base.copyWith(
      title: '${base.title} (Vegan)',
      ingredients: newIngredients,
      steps: newSteps,
      keywords: [...base.keywords, 'vegan'],
    );
  }

  Recipe _makeDiet(Recipe base) {
    // Basit "diyet" yaklaşımı: yağ/şeker miktarlarını azalt, pişirme yöntemlerini hafiflet
    final reducePatterns = <RegExp, String>{
      RegExp(r'\b(\d+(?:[\.,]\d+)?)\s*(yemek|tatli|çay)?\s*kaşığı\b'): '1 çay kaşığı',
      RegExp(r'\b(\d+(?:[\.,]\d+)?)\s*gram\b'): '50 gram',
      RegExp(r'\b(\d+(?:[\.,]\d+)?)\s*ml\b'): '50 ml',
    };

    final unhealthy = <String, String>{
      'şeker': 'eritritol/stevia',
      'tereyağı': 'zeytinyağı',
      'kızart': 'fırınla',
    };

    List<String> newIngredients = base.ingredients.map((ing) {
      var out = ing;
      for (final re in reducePatterns.keys) {
        out = out.replaceAll(re, reducePatterns[re]!);
      }
      unhealthy.forEach((k, v) {
        out = out.replaceAll(k, v);
      });
      return out;
    }).toList(growable: false);

    List<String> newSteps = base.steps.map((s) {
      var out = s;
      unhealthy.forEach((k, v) {
        out = out.replaceAll(k, v);
      });
      return out;
    }).toList(growable: false);

    return base.copyWith(
      title: '${base.title} (Diyet)',
      ingredients: newIngredients,
      steps: newSteps,
      keywords: [...base.keywords, 'diyet'],
    );
  }

  Recipe _scalePortions(Recipe base, int targetPortions) {
    if (targetPortions <= 0) targetPortions = 1;
    // Mevcut porsiyon bilgisini kullan (yoksa 1 varsay)
    final currentPortions = base.portions ?? 1;
    // Oranı hesapla: hedef / mevcut
    final factor = targetPortions / currentPortions;
    final numRe = RegExp(r'(\d+[\.,]?\d*)');
    
    // Sabit kalması gereken malzemeler (küçük harfe çevirerek kontrol et)
    const fixedIngredients = [
      'tuz', 'karabiber', 'kırmızıbiber', 'toz biber', 'pul biber',
      'karbonat', 'kabartma tozu', 'mayalama tozu',
      'vanilya', 'vanilin', 'vanilya özü',
      'limon suyu', 'sirke',
      'biberiye', 'kekik', 'nane', 'fesleğen',
      'tarçın', 'karanfil', 'yenibahar'
    ];

    bool shouldKeepFixed(String ingredient) {
      final lower = ingredient.toLowerCase();
      return fixedIngredients.any((fixed) => lower.contains(fixed));
    }

    List<String> newIngredients = base.ingredients.map((ing) {
      // Eğer sabit kalması gereken bir malzeme ise, sadece çok az artır (max %50)
      if (shouldKeepFixed(ing)) {
        // Sabit malzemeler için maksimum %50 artış (veya aynı kalır)
        final adjustedFactor = factor > 1.5 ? 1.5 : factor;
        return ing.replaceAllMapped(numRe, (m) {
          final raw = m.group(1)!.replaceAll(',', '.');
          final val = double.tryParse(raw) ?? 0.0;
          // Eğer çok küçük bir değerse (çay kaşığı, tutam vb.) aynı kal
          if (val <= 2 && adjustedFactor > 1.2) {
            return m.group(0)!; // Aynı kal
          }
          final scaled = val * adjustedFactor;
          final shown = scaled % 1 == 0 ? scaled.toInt().toString() : scaled.toStringAsFixed(1);
          return shown;
        });
      } else {
        // Normal malzemeler için orantılı ölçekleme
        return ing.replaceAllMapped(numRe, (m) {
          final raw = m.group(1)!.replaceAll(',', '.');
          final val = double.tryParse(raw) ?? 0.0;
          final scaled = val * factor;
          final shown = scaled % 1 == 0 ? scaled.toInt().toString() : scaled.toStringAsFixed(1);
          return shown;
        });
      }
    }).toList(growable: false);

    return base.copyWith(
      title: '${base.title} (${targetPortions} porsiyon)',
      ingredients: newIngredients,
      portions: targetPortions,
      keywords: [...base.keywords, 'porsiyon'],
    );
  }

  String _capitalizeLike(String original, String lowerReplaced) {
    // Orijinal büyük/küçük harf yapısını basitçe korumaya çalışır
    if (original.isEmpty) return lowerReplaced;
    if (RegExp(r'^[A-ZÇĞİÖŞÜ]').hasMatch(original)) {
      return lowerReplaced.isEmpty
          ? lowerReplaced
          : lowerReplaced[0].toUpperCase() + lowerReplaced.substring(1);
    }
    return lowerReplaced;
  }
}


