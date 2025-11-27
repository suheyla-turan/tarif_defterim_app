import '../../../core/providers/localization_provider.dart';

class RecipeTypeLabels {
  static String mainType(AppLocalizations l10n, String mainType) {
    switch (mainType) {
      case 'yemek':
        return l10n.meals;
      case 'tatli':
        return l10n.desserts;
      case 'icecek':
        return l10n.drinks;
      default:
        return _titleCase(mainType);
    }
  }

  static String subType(AppLocalizations l10n, String subType) {
    switch (subType) {
      case 'corba':
        return l10n.soup;
      case 'ana_yemek':
        return l10n.mainDish;
      case 'meze':
        return l10n.appetizer;
      case 'salata':
        return l10n.salad;
      case 'hamur_isi':
        return l10n.pastry;
      case 'kahvaltilik':
        return l10n.isTurkish ? 'Kahvaltılıklar' : 'Breakfast dishes';
      case 'sutlu':
        return l10n.milky;
      case 'serbetli':
        return l10n.syrupy;
      case 'kek_pasta':
        return l10n.cake;
      case 'kurabiye':
        return l10n.cookie;
      case 'sicak':
        return l10n.hot;
      case 'soguk':
        return l10n.cold;
      case 'smoothie':
        return l10n.smoothie;
      default:
        return _titleCase(subType);
    }
  }

  static String summary(
    AppLocalizations l10n, {
    required String mainType,
    String? subType,
    String? country,
  }) {
    final parts = <String>[RecipeTypeLabels.mainType(l10n, mainType)];
    if (subType != null && subType.isNotEmpty) {
      parts.add(RecipeTypeLabels.subType(l10n, subType));
    }
    if (country != null && country.trim().isNotEmpty) {
      parts.add(country.trim());
    }
    return parts.join(' • ');
  }

  static String _titleCase(String value) {
    final normalized = value.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return value;
    return normalized
        .split(RegExp(r'\s+'))
        .map((word) =>
            word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}


