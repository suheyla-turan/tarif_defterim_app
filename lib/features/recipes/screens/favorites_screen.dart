import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/recipes_provider.dart';
import '../../../core/providers/localization_provider.dart';
import '../models/recipe.dart';
import '../utils/recipe_type_labels.dart';
import '../constants/recipe_types.dart';
import 'recipe_detail_screen.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String? _selectedMainType;
  int _currentSubCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final favs = ref.watch(favoritesProvider);
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final double overlayHeight = mediaQuery.padding.top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            if (_selectedMainType != null) {
              final subTypes = RecipeTypes.subTypesOf(_selectedMainType!);
              if (subTypes.isNotEmpty && _currentSubCategoryIndex < subTypes.length) {
                return Text(RecipeTypeLabels.subType(l10n, subTypes[_currentSubCategoryIndex]));
              }
              return Text(RecipeTypeLabels.mainType(l10n, _selectedMainType!));
            }
            return Text(l10n.myFavorites);
          },
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_selectedMainType != null) {
              setState(() {
                _selectedMainType = null;
                _currentSubCategoryIndex = 0;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          
          // Kalp simgeleri
          final heartIcons = [
            Icons.favorite,
            Icons.favorite_border,
            Icons.favorite_outline,
            Icons.favorite_outlined,
            Icons.heart_broken,
            Icons.favorite_rounded,
            Icons.favorite_border_rounded,
            Icons.volunteer_activism,
          ];
          
          // Grid parametreleri
          final cols = 5;
          final rows = 7;
          final cellWidth = screenWidth / cols;
          final cellHeight = screenHeight / rows;
          final iconSize = (cellWidth * 0.4).clamp(35.0, 65.0);
          final spacing = cellWidth * 0.15;
          final maxOffset = cellWidth * 0.3;
          
          // Rotasyon açıları
          final rotations = [
            0.3, -0.25, 0.4, -0.2, 0.35,
            -0.4, 0.25, -0.3, 0.45, -0.35,
            0.2, -0.4, 0.3, -0.25, 0.4,
            -0.3, 0.25, -0.4, 0.35, -0.2,
            0.4, -0.3, 0.25, -0.35, 0.3,
            -0.25, 0.4, -0.3, 0.35, -0.2,
            0.3, -0.4, 0.25, -0.35, 0.4,
          ];
          
          // Opacity değerleri
          final opacities = [
            0.12, 0.10, 0.13, 0.11, 0.12,
            0.10, 0.13, 0.11, 0.12, 0.10,
            0.13, 0.11, 0.12, 0.10, 0.13,
            0.11, 0.12, 0.10, 0.13, 0.11,
            0.12, 0.10, 0.13, 0.11, 0.12,
            0.10, 0.13, 0.11, 0.12, 0.10,
            0.13, 0.11, 0.12, 0.10, 0.13,
          ];
          
          // Renkler
          final colors = [
            Colors.red,
            Colors.pink,
            Colors.redAccent,
            Colors.deepOrange,
            Colors.orange,
            Colors.grey,
          ];
          
          return Stack(
            children: [
              // Arka plan dekoratif simgeler
              ...List.generate(
                cols * rows,
                (index) {
                  final row = index ~/ cols;
                  final col = index % cols;
                  
                  final baseX = cellWidth * (col + 0.5) - iconSize / 2;
                  final baseY = cellHeight * (row + 0.5) - iconSize / 2;
                  
                  final offsetX = ((index % 7) - 3) * (maxOffset / 3);
                  final offsetY = ((index % 5) - 2) * (maxOffset / 3);
                  
                  final x = (baseX + offsetX).clamp(spacing, screenWidth - iconSize - spacing);
                  final y = (baseY + offsetY).clamp(spacing, screenHeight - iconSize - spacing);
                  
                  final iconData = heartIcons[index % heartIcons.length];
                  final rotation = rotations[index % rotations.length];
                  final opacity = opacities[index % opacities.length];
                  final color = colors[index % colors.length];
                  
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
              ),
              // İçerik
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(top: overlayHeight),
                  child: _buildContent(favs, l10n),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(AsyncValue<List<Recipe>> favorites, AppLocalizations l10n) {
    // Ana kategori seçilmişse PageView ile alt kategorilerin tariflerini göster
    if (_selectedMainType != null) {
      return favorites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(l10n.noFavorites),
                ],
              ),
            );
          }

          final filtered = list.where((r) => r.mainType == _selectedMainType).toList();
          final subTypes = RecipeTypes.subTypesOf(_selectedMainType!);

          if (subTypes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.category_outlined, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(l10n.noRecipesInCategory),
                ],
              ),
            );
          }

          return _FavoritesSubCategoriesPageView(
            subTypes: subTypes,
            favorites: filtered,
            l10n: l10n,
            mainType: _selectedMainType!,
            initialPage: _currentSubCategoryIndex,
            onPageChanged: (index) {
              setState(() => _currentSubCategoryIndex = index);
            },
          );
        },
      );
    }

    // Ana ekran: 3 buton
    return _FavoritesMainCategoriesView(
      l10n: l10n,
      favorites: favorites,
      onMainTypeSelected: (mainType) {
        setState(() {
          _selectedMainType = mainType;
          _currentSubCategoryIndex = 0;
        });
      },
    );
  }
}

class _FavoritesMainCategoriesView extends StatelessWidget {
  final AppLocalizations l10n;
  final AsyncValue<List<Recipe>> favorites;
  final Function(String) onMainTypeSelected;

  const _FavoritesMainCategoriesView({
    required this.l10n,
    required this.favorites,
    required this.onMainTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return favorites.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(l10n.noFavorites),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FavoritesMainCategoryButton(
                title: l10n.meals,
                icon: Icons.room_service,
                color: Colors.orange,
                count: list.where((r) => r.mainType == 'yemek').length,
                onTap: () => onMainTypeSelected('yemek'),
              ),
              const SizedBox(height: 16),
              _FavoritesMainCategoryButton(
                title: l10n.desserts,
                icon: Icons.cake,
                color: Colors.pink,
                count: list.where((r) => r.mainType == 'tatli').length,
                onTap: () => onMainTypeSelected('tatli'),
              ),
              const SizedBox(height: 16),
              _FavoritesMainCategoryButton(
                title: l10n.drinks,
                icon: Icons.local_drink,
                color: Colors.blue,
                count: list.where((r) => r.mainType == 'icecek').length,
                onTap: () => onMainTypeSelected('icecek'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FavoritesMainCategoryButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;

  const _FavoritesMainCategoryButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.15),
                color.withOpacity(0.08),
              ],
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count tarif',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesSubCategoriesPageView extends StatefulWidget {
  final List<String> subTypes;
  final List<Recipe> favorites;
  final AppLocalizations l10n;
  final String mainType;
  final int initialPage;
  final Function(int) onPageChanged;

  const _FavoritesSubCategoriesPageView({
    required this.subTypes,
    required this.favorites,
    required this.l10n,
    required this.mainType,
    required this.initialPage,
    required this.onPageChanged,
  });

  @override
  State<_FavoritesSubCategoriesPageView> createState() => _FavoritesSubCategoriesPageViewState();
}

class _FavoritesSubCategoriesPageViewState extends State<_FavoritesSubCategoriesPageView> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    widget.onPageChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final outline = theme.colorScheme.outline.withOpacity(0.4);
    final textColor = theme.colorScheme.onSurface.withOpacity(0.8);

    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          // Alt kategori indicator
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: widget.subTypes.length,
              itemBuilder: (context, index) {
                final subType = widget.subTypes[index];
                final subTypeFavorites = widget.favorites.where((r) => r.subType == subType).toList();
                final isSelected = _currentIndex == index;
                
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primary.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? primary
                            : outline,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            RecipeTypeLabels.subType(widget.l10n, subType),
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? primary : textColor,
                              fontSize: 14,
                            ),
                          ),
                          if (subTypeFavorites.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primary.withOpacity(0.2)
                                    : outline,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${subTypeFavorites.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? primary : textColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // PageView ile tarifler
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.subTypes.length,
              itemBuilder: (context, index) {
                final subType = widget.subTypes[index];
                final subTypeFavorites = widget.favorites.where((r) => r.subType == subType).toList();
                
                if (subTypeFavorites.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.favorite_border, size: 56, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text('Bu kategoride beğenilen tarif bulunmamaktadır'),
                      ],
                    ),
                  );
                }
                
                return _FavoritesRecipeListView(favorites: subTypeFavorites);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoritesRecipeListView extends StatelessWidget {
  final List<Recipe> favorites;

  const _FavoritesRecipeListView({required this.favorites});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: favorites.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
        final Recipe r = favorites[i];
              return Card(
                child: ListTile(
                  title: Text(r.title),
                  subtitle: Text(RecipeTypeLabels.summary(
                    l10n,
                    mainType: r.mainType,
                    subType: r.subType,
                    country: r.country,
                  )),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite, size: 18, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Text('${r.likesCount}')
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: r)),
                  ),
                ),
              );
            },
    );
  }
}
