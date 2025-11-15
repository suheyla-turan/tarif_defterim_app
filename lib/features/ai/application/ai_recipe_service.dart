import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../recipes/models/recipe.dart';

enum RecipeTransformType { vegan, diet, portion }

final aiRecipeServiceProvider = Provider<AiRecipeService>((ref) {
  return AiRecipeService();
});

class AiRecipeService {
  Future<Recipe> transformRecipe({
    required Recipe base,
    required RecipeTransformType type,
    int? targetPortions,
  }) async {
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
    // Referans olarak mevcut tarif 1 porsiyon varsayımıyla çarpan uygula
    final factor = targetPortions.toDouble();
    final numRe = RegExp(r'(\d+[\.,]?\d*)');
    List<String> newIngredients = base.ingredients.map((ing) {
      return ing.replaceAllMapped(numRe, (m) {
        final raw = m.group(1)!.replaceAll(',', '.');
        final val = double.tryParse(raw) ?? 0.0;
        final scaled = (val * factor);
        // .0 ise tam sayı göster
        final shown = scaled % 1 == 0 ? scaled.toInt().toString() : scaled.toStringAsFixed(1);
        return shown;
      });
    }).toList(growable: false);

    return base.copyWith(
      title: '${base.title} (${targetPortions} porsiyon)',
      ingredients: newIngredients,
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


