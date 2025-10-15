class RecipeTypes {
  static const List<String> mainTypes = ['yemek', 'tatli', 'icecek'];

  static List<String> subTypesOf(String mainType) {
    switch (mainType) {
      case 'yemek':
        return ['corba', 'ana_yemek', 'meze', 'salata', 'hamur_isi'];
      case 'tatli':
        return ['sutlu', 'serbetli', 'kek_pasta', 'kurabiye'];
      case 'icecek':
        return ['sicak', 'soguk', 'smoothie'];
      default:
        return const <String>[];
    }
  }
}


