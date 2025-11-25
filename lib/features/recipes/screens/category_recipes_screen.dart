import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import 'recipe_detail_screen.dart';
import '../application/recipes_provider.dart';
import '../../../core/providers/localization_provider.dart';
import '../constants/recipe_types.dart';

class CategoryRecipesScreen extends ConsumerStatefulWidget {
  final String? mainType;
  final String? subType; // Alt kategori seçilmişse
  
  const CategoryRecipesScreen({
    super.key,
    this.mainType,
    this.subType,
  });

  @override
  ConsumerState<CategoryRecipesScreen> createState() => _CategoryRecipesScreenState();
}

class _CategoryRecipesScreenState extends ConsumerState<CategoryRecipesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    // Kategori başlığını belirle
    String title;
    IconData icon;
    Color color;
    
    switch (widget.mainType) {
      case 'yemek':
        title = l10n.meals;
        icon = Icons.room_service;
        color = Colors.orange;
        break;
      case 'tatli':
        title = l10n.desserts;
        icon = Icons.cake;
        color = Colors.pink;
        break;
      case 'icecek':
        title = l10n.drinks;
        icon = Icons.local_drink;
        color = Colors.blue;
        break;
      default:
        title = l10n.allRecipes;
        icon = Icons.menu_book;
        color = Colors.green;
    }

    // Alt kategorileri al
    final subTypes = widget.mainType != null ? RecipeTypes.subTypesOf(widget.mainType!) : <String>[];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Padding(
          padding: EdgeInsets.only(
            top: widget.mainType == 'tatli' ? 20.0 : 0.0,
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: widget.mainType == 'tatli' ? kToolbarHeight + 28 : null,
        centerTitle: false,
        flexibleSpace: widget.mainType == 'icecek'
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.surface.withOpacity(0.2),
                      Theme.of(context).colorScheme.surface.withOpacity(0.0),
                    ],
                    stops: const [0.0, 0.25],
                  ),
                ),
              )
            : widget.mainType == 'tatli'
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).colorScheme.surface.withOpacity(0.6),
                          Theme.of(context).colorScheme.surface.withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.3],
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).colorScheme.surface.withOpacity(0.85),
                          Theme.of(context).colorScheme.surface.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
        actions: [
          // Arama butonu sadece alt kategori sayfasında göster
          if (widget.subType != null)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                final l10n = AppLocalizations.of(context);
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.searchInCategory),
                    content: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: l10n.searchRecipe,
                        prefixIcon: const Icon(Icons.search),
                      ),
                      autofocus: true,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          Navigator.pop(ctx);
                        },
                        child: Text(l10n.clear),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(l10n.search),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: widget.subType == null
          ? _buildMainCategoryView(context, subTypes, color, l10n)
          : _buildSubCategoryView(context, color, l10n),
    );
  }

  // Ana kategori görünümü: Sadece alt kategori kutucukları
  Widget _buildMainCategoryView(
    BuildContext context,
    List<String> subTypes,
    Color color,
    AppLocalizations l10n,
  ) {
    if (subTypes.isEmpty) {
      return Center(
        child: Text(
          l10n.noRecipesInCategory,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    // Yemek, tatlılar ve içecek kategorileri için arka plan icon'ları
    final bool isMealsCategory = widget.mainType == 'yemek';
    final bool isDessertsCategory = widget.mainType == 'tatli';
    final bool isDrinksCategory = widget.mainType == 'icecek';
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            color.withOpacity(0.05),
            Theme.of(context).colorScheme.surface,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Arka plan icon'ları (yemek, tatlılar ve içecek kategorileri için)
          if (isMealsCategory) ..._buildBackgroundIcons(context, subTypes, color),
          if (isDessertsCategory) ..._buildDessertsBackgroundIcons(context, subTypes, color),
          if (isDrinksCategory) ..._buildDrinksBackgroundIcons(context, color),
          // İçerik
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: subTypes.map((subType) {
                      return _SubCategoryCard(
                        title: _getSubTypeDisplayName(subType, context),
                        icon: _getSubTypeIcon(subType),
                        color: color,
                        onTap: () => _navigateToSubCategory(context, widget.mainType!, subType),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Arka plan icon'larını oluştur - çeşitli yemek simgeleri, asimetrik ama eşit boşluklu
  List<Widget> _buildBackgroundIcons(BuildContext context, List<String> subTypes, Color color) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    // Çeşitli yemek simgeleri - tabakta yemekler, çorbalar, meze, salata, ana yemek vb.
    final mealCategoryIcons = [
      Icons.soup_kitchen,       // Çorba
      Icons.dinner_dining,      // Ana yemek - tabakta yemek
      Icons.set_meal,           // Meze
      Icons.rice_bowl,          // Salata / kasede salata
      Icons.bakery_dining,      // Hamur işi
      Icons.dining,             // Genel tabakta yemek
      Icons.restaurant,         // Restoran yemeği
      Icons.local_dining,       // Yerel yemek
      Icons.fastfood,           // Fast food
      Icons.local_pizza,        // Pizza
      Icons.breakfast_dining,   // Kahvaltı
      Icons.lunch_dining,       // Öğle yemeği
    ];
    
    // Grid parametreleri - asimetrik ama eşit boşluklu yerleşim için
    final cols = 6; // Sütun sayısı
    final rows = 8; // Satır sayısı
    final cellWidth = width / cols;
    final cellHeight = height / rows;
    final iconSize = (cellWidth * 0.35).clamp(45.0, 70.0);
    final spacing = cellWidth * 0.12; // Eşit boşluk
    final maxOffset = cellWidth * 0.3; // Asimetrik görünüm için maksimum offset

    final rotations = [
      0.3, -0.2, 0.5, -0.4, 0.3, -0.25,
      0.45, 0.5, -0.4, 0.3, -0.6, 0.25,
      -0.35, 0.55, 0.2, -0.5, 0.4, -0.3,
      0.6, -0.25, 0.45, 0.3, -0.2, 0.5,
      0.3, -0.2, 0.4, -0.35, 0.25, -0.3,
      0.4, -0.25, 0.35, -0.2, 0.3, -0.4,
      0.25, -0.3, 0.4, -0.25, 0.35, -0.2,
      0.3, -0.4, 0.25, -0.35, 0.4, -0.3,
    ];

    final opacities = [
      0.10, 0.12, 0.11, 0.13, 0.09, 0.14,
      0.12, 0.11, 0.13, 0.10, 0.14, 0.09,
      0.15, 0.12, 0.10, 0.13, 0.11, 0.14,
      0.09, 0.15, 0.12, 0.10, 0.13, 0.11,
      0.12, 0.14, 0.11, 0.13, 0.10, 0.15,
      0.12, 0.13, 0.11, 0.14, 0.10, 0.15,
      0.12, 0.11, 0.13, 0.10, 0.14, 0.09,
      0.15, 0.12, 0.10, 0.13, 0.11, 0.14,
    ];

    // Simge boyutları - çeşitlilik için
    final iconSizes = [
      iconSize * 0.9, iconSize * 1.1, iconSize * 0.95, iconSize * 1.05, iconSize * 0.85, iconSize * 1.0,
      iconSize * 0.92, iconSize * 1.08, iconSize * 0.98, iconSize * 1.02, iconSize * 0.88, iconSize * 1.0,
      iconSize * 0.94, iconSize * 1.06, iconSize * 0.96, iconSize * 1.04, iconSize * 0.9, iconSize * 1.0,
      iconSize * 0.93, iconSize * 1.07, iconSize * 0.97, iconSize * 1.03, iconSize * 0.91, iconSize * 1.0,
      iconSize * 0.95, iconSize * 1.05, iconSize * 0.99, iconSize * 1.01, iconSize * 0.89, iconSize * 1.0,
      iconSize * 0.92, iconSize * 1.08, iconSize * 0.96, iconSize * 1.04, iconSize * 0.93, iconSize * 1.0,
      iconSize * 0.94, iconSize * 1.06, iconSize * 0.98, iconSize * 1.02, iconSize * 0.9, iconSize * 1.0,
      iconSize * 0.97, iconSize * 1.03, iconSize * 0.95, iconSize * 1.05, iconSize * 0.92, iconSize * 1.0,
    ];

    return List.generate(
      cols * rows,
      (index) {
        final row = index ~/ cols;
        final col = index % cols;
        
        // Grid pozisyonu - hücrenin merkezi
        final baseX = cellWidth * (col + 0.5);
        final baseY = cellHeight * (row + 0.5);
        
        // Asimetrik görünüm için offset (ama tutarlı - index'e bağlı)
        final offsetX = ((index % 7) - 3) * (maxOffset / 3.5);
        final offsetY = ((index % 5) - 2) * (maxOffset / 3.5);
        
        final currentIconSize = iconSizes[index % iconSizes.length];
        final x = (baseX + offsetX - currentIconSize / 2).clamp(spacing, width - currentIconSize - spacing);
        final y = (baseY + offsetY - currentIconSize / 2).clamp(spacing, height - currentIconSize - spacing);
        
        final iconData = mealCategoryIcons[index % mealCategoryIcons.length];
        final rotation = rotations[index % rotations.length];
        final opacity = opacities[index % opacities.length];

        return Positioned(
          left: x,
          top: y,
          child: Transform.rotate(
            angle: rotation,
            child: Icon(
              iconData,
              size: currentIconSize,
              color: color.withOpacity(opacity),
            ),
          ),
        );
      },
    );
  }

  // Tatlılar için arka plan icon'larını oluştur - sadece tatlı simgeleri, karışık ama düzenli
  List<Widget> _buildDessertsBackgroundIcons(BuildContext context, List<String> subTypes, Color color) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    
    // Sadece tatlı icon'ları
    final dessertIcons = [
      Icons.cake,          // Kek/Pasta
      Icons.icecream,      // Dondurma
      Icons.cookie,        // Kurabiye
      Icons.celebration,   // Kutlama (pasta)
      Icons.bakery_dining, // Pastane
      Icons.cake_outlined, // Kek (outlined)
      Icons.icecream_outlined, // Dondurma (outlined)
      Icons.cookie_outlined, // Kurabiye (outlined)
    ];
    
    // Grid parametreleri - karışık ama düzenli yerleşim için
    final cols = 6; // Sütun sayısı
    final rows = 8; // Satır sayısı
    final cellWidth = width / cols;
    final cellHeight = height / rows;
    final iconSize = (cellWidth * 0.4).clamp(50.0, 80.0);
    final spacing = cellWidth * 0.15; // Simgeler arası boşluk
    final maxOffset = cellWidth * 0.25; // Karışık görünüm için maksimum offset

    final rotations = [
      0.4, -0.3, 0.6, -0.5, 0.35, -0.25,
      0.45, 0.5, -0.4, 0.3, -0.6, 0.25,
      -0.35, 0.55, 0.2, -0.5, 0.4, -0.3,
      0.6, -0.25, 0.45, 0.3, -0.2, 0.5,
    ];

    final opacities = [
      0.12, 0.15, 0.13, 0.14, 0.11, 0.16,
      0.15, 0.13, 0.14, 0.12, 0.15, 0.11,
      0.16, 0.14, 0.12, 0.15, 0.13, 0.14,
      0.11, 0.16, 0.15, 0.12, 0.13, 0.14,
    ];

    return List.generate(
      cols * rows,
      (index) {
        final row = index ~/ cols;
        final col = index % cols;
        
        // Grid pozisyonu - hücrenin merkezi
        final baseX = cellWidth * (col + 0.5) - iconSize / 2;
        final baseY = cellHeight * (row + 0.5) - iconSize / 2;
        
        // Karışık görünüm için rastgele offset (ama tutarlı - index'e bağlı)
        final offsetX = ((index % 7) - 3) * (maxOffset / 3);
        final offsetY = ((index % 5) - 2) * (maxOffset / 3);
        
        final x = (baseX + offsetX).clamp(spacing, width - iconSize - spacing);
        final y = (baseY + offsetY).clamp(spacing, height - iconSize - spacing);
        
        final iconData = dessertIcons[index % dessertIcons.length];
        final rotation = rotations[index % rotations.length];
        final opacity = opacities[index % opacities.length];

        return Positioned(
          left: x,
          top: y,
          child: Transform.rotate(
            angle: rotation,
            child: Icon(
              iconData,
              size: iconSize,
              color: color.withOpacity(opacity),
            ),
          ),
        );
      },
    );
  }

  // İçecekler için arka plan icon'larını oluştur - sadece içecek simgeleri, karışık ama düzenli
  List<Widget> _buildDrinksBackgroundIcons(BuildContext context, Color color) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    
    // Sadece içecek icon'ları
    final drinkIcons = [
      Icons.local_cafe,              // Kahve
      Icons.emoji_food_beverage,      // Çay
      Icons.local_drink,              // Meşrubat
      Icons.local_bar,                // Bar/Smoothie
      Icons.wine_bar,                 // Şarap
      Icons.local_cafe_outlined,      // Kahve (outlined)
      Icons.emoji_food_beverage_outlined, // Çay (outlined)
      Icons.water_drop,               // Su
    ];
    
    // Grid parametreleri - karışık ama düzenli yerleşim için
    final cols = 6; // Sütun sayısı
    final rows = 8; // Satır sayısı
    final cellWidth = width / cols;
    final cellHeight = height / rows;
    final iconSize = (cellWidth * 0.4).clamp(50.0, 80.0);
    final spacing = cellWidth * 0.15; // Simgeler arası boşluk
    final maxOffset = cellWidth * 0.25; // Karışık görünüm için maksimum offset

    final rotations = [
      0.4, -0.3, 0.6, -0.5, 0.35, -0.4,
      0.25, 0.5, -0.4, 0.3, -0.6, 0.25,
      -0.35, 0.55, 0.2, -0.5, 0.4, -0.3,
      0.6, -0.25, 0.45, 0.3, -0.2, 0.5,
    ];

    final opacities = [
      0.12, 0.14, 0.13, 0.15, 0.11, 0.16,
      0.13, 0.12, 0.15, 0.13, 0.14, 0.11,
      0.16, 0.14, 0.12, 0.15, 0.13, 0.14,
      0.11, 0.16, 0.15, 0.12, 0.13, 0.14,
    ];

    return List.generate(
      cols * rows,
      (index) {
        final row = index ~/ cols;
        final col = index % cols;
        
        // Grid pozisyonu - hücrenin merkezi
        final baseX = cellWidth * (col + 0.5) - iconSize / 2;
        final baseY = cellHeight * (row + 0.5) - iconSize / 2;
        
        // Karışık görünüm için rastgele offset (ama tutarlı - index'e bağlı)
        final offsetX = ((index % 7) - 3) * (maxOffset / 3);
        final offsetY = ((index % 5) - 2) * (maxOffset / 3);
        
        final x = (baseX + offsetX).clamp(spacing, width - iconSize - spacing);
        final y = (baseY + offsetY).clamp(spacing, height - iconSize - spacing);
        
        final iconData = drinkIcons[index % drinkIcons.length];
        final rotation = rotations[index % rotations.length];
        final opacity = opacities[index % opacities.length];

        return Positioned(
          left: x,
          top: y,
          child: Transform.rotate(
            angle: rotation,
            child: Icon(
              iconData,
              size: iconSize,
              color: color.withOpacity(opacity),
            ),
          ),
        );
      },
    );
  }

  // Alt kategori görünümü: Tarifler ve arama
  Widget _buildSubCategoryView(
    BuildContext context,
    Color color,
    AppLocalizations l10n,
  ) {
    // Yemek kategorisi için arka plan ikonları ekle
    final bool isMealsCategory = widget.mainType == 'yemek';
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            color.withOpacity(0.05),
            Theme.of(context).colorScheme.surface,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Arka plan icon'ları (sadece yemek kategorisi için)
          if (isMealsCategory) ..._buildBackgroundIcons(context, [], color),
          // İçerik - AppBar yüksekliği kadar üstten padding ekle
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 
                   (widget.mainType == 'tatli' ? kToolbarHeight + 28 : kToolbarHeight),
            ),
            child: Column(
              children: [
                // Arama çubuğu
                if (_searchQuery.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: color.withOpacity(0.1),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${l10n.search}: $_searchQuery'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                // Tarifler listesi
                Expanded(
                  child: _RecipesList(
                    mainType: widget.mainType,
                    subType: widget.subType,
                    searchQuery: _searchQuery,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSubTypeDisplayName(String subType, BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        return l10n.isTurkish ? 'Kahvaltılık' : 'Breakfast dishes';
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
        return subType;
    }
  }

  void _navigateToSubCategory(BuildContext context, String mainType, String subType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryRecipesScreen(
          mainType: mainType,
          subType: subType,
        ),
      ),
    );
  }

  IconData _getSubTypeIcon(String subType) {
    switch (subType) {
      case 'corba':
        return Icons.soup_kitchen;
      case 'ana_yemek':
        return Icons.dinner_dining; // Ana yemek simgesi: tabakta yemek
      case 'meze':
        return Icons.set_meal;
      case 'salata':
        return Icons.rice_bowl; // Salata simgesi: tabakta/kasede yemek
      case 'hamur_isi':
        return Icons.bakery_dining;
      case 'kahvaltilik':
        return Icons.breakfast_dining;
      case 'sutlu':
        return Icons.icecream;
      case 'serbetli':
        return Icons.cake;
      case 'kek_pasta':
        return Icons.celebration;
      case 'kurabiye':
        return Icons.cookie;
      case 'sicak':
        return Icons.local_cafe;
      case 'soguk':
        return Icons.local_drink;
      case 'smoothie':
        return Icons.local_bar;
      default:
        return Icons.category;
    }
  }
}

class _RecipesList extends ConsumerWidget {
  final String? mainType;
  final String? subType;
  final String searchQuery;

  const _RecipesList({
    this.mainType,
    this.subType,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(recipesRepositoryProvider);
    
    // Tarifleri filtrele
    Stream<List<Recipe>> recipesStream;
    if (searchQuery.isNotEmpty) {
      recipesStream = repository.searchFiltered(
        query: searchQuery,
        mainType: mainType,
        subType: subType,
      );
    } else {
      recipesStream = repository.searchFiltered(
        mainType: mainType,
        subType: subType,
      );
    }

    return StreamBuilder<List<Recipe>>(
      stream: recipesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          final l10n = AppLocalizations.of(context);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  l10n.recipesLoadFailed,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        final recipes = snapshot.data ?? [];
        
        if (recipes.isEmpty) {
          final l10n = AppLocalizations.of(context);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  l10n.noRecipesInCategory,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.addFirstRecipe,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            return _RecipeCard(
              recipe: recipe,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(recipe: recipe),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık ve beğeni sayısı
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (recipe.likesCount > 0) ...[
                    Icon(Icons.favorite, size: 16, color: Colors.red[300]),
                    const SizedBox(width: 4),
                    Text(
                      '${recipe.likesCount}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              
              if (recipe.description != null && recipe.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  recipe.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Kategori etiketleri
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _CategoryChip(
                    label: recipe.mainType,
                    color: _getCategoryColor(recipe.mainType),
                  ),
                  if (recipe.subType != null)
                    _CategoryChip(
                      label: recipe.subType!,
                      color: Colors.grey,
                    ),
                  if (recipe.country != null)
                    _CategoryChip(
                      label: recipe.country!,
                      color: Colors.blue,
                    ),
                ],
              ),
              
              // Görsel varsa göster
              if (recipe.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recipe.imageUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final url = recipe.imageUrls[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              
              const SizedBox(height: 8),
              
              // Alt bilgi
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(recipe.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (recipe.ingredients.isNotEmpty) ...[
                    Icon(Icons.list, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${recipe.ingredients.length} malzeme',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String mainType) {
    switch (mainType) {
      case 'yemek':
        return Colors.orange;
      case 'tatli':
        return Colors.pink;
      case 'icecek':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Bugün';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} hafta önce';
    } else {
      return '${(difference.inDays / 30).floor()} ay önce';
    }
  }
}

class _SubCategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SubCategoryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SubCategoryRecipesScreen extends ConsumerWidget {
  final String mainType;
  final String subType;

  const SubCategoryRecipesScreen({
    super.key,
    required this.mainType,
    required this.subType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(recipesRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    
    // Ana kategori başlığını belirle
    String mainTitle;
    IconData mainIcon;
    Color mainColor;
    
    switch (mainType) {
      case 'yemek':
        mainTitle = l10n.meals;
        mainIcon = Icons.restaurant;
        mainColor = Colors.orange;
        break;
      case 'tatli':
        mainTitle = l10n.desserts;
        mainIcon = Icons.cake;
        mainColor = Colors.pink;
        break;
      case 'icecek':
        mainTitle = l10n.drinks;
        mainIcon = Icons.local_drink;
        mainColor = Colors.blue;
        break;
      default:
        mainTitle = l10n.allRecipes;
        mainIcon = Icons.menu_book;
        mainColor = Colors.green;
    }

    // Tarifleri filtrele
    final recipesStream = repository.searchFiltered(
      mainType: mainType,
      subType: subType,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(mainIcon, color: mainColor),
            const SizedBox(width: 8),
            Text(mainTitle),
          ],
        ),
        backgroundColor: mainColor.withOpacity(0.1),
      ),
      body: StreamBuilder<List<Recipe>>(
        stream: recipesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    l10n.recipesLoadFailed,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          final recipes = snapshot.data ?? [];
          
          if (recipes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(mainIcon, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noRecipesInCategory,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.addFirstRecipe,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return _RecipeCard(
                recipe: recipe,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(recipe: recipe),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color color;

  const _CategoryChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
