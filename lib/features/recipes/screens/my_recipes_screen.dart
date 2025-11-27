import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/localization_provider.dart';
import '../../../core/providers/auth_provider.dart' as feature_auth;
import '../application/recipes_provider.dart';
import '../data/recipes_repository.dart';
import '../models/recipe.dart';
import '../utils/recipe_type_labels.dart';
import '../constants/recipe_types.dart';
import 'recipe_detail_screen.dart';
import 'add_recipe_screen.dart';
import 'edit_recipe_screen.dart';

class MyRecipesScreen extends ConsumerStatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  ConsumerState<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends ConsumerState<MyRecipesScreen> {
  String? _selectedMainType;
  int _currentSubCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(myRecipesProvider);
    final repo = ref.read(recipesRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    final userId = ref.watch(feature_auth.firebaseAuthStateProvider).value?.uid;

    return Scaffold(
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
            return Text(l10n.myRecipesTitle);
          },
        ),
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

          final bookIcons = [
            Icons.menu_book,
            Icons.book,
            Icons.menu_book_outlined,
            Icons.library_books,
            Icons.book_outlined,
            Icons.auto_stories,
            Icons.collections_bookmark,
            Icons.chrome_reader_mode,
          ];

          final cols = 5;
          final rows = 7;
          final cellWidth = screenWidth / cols;
          final cellHeight = screenHeight / rows;
          final iconSize = (cellWidth * 0.4).clamp(35.0, 65.0);
          final spacing = cellWidth * 0.15;
          final maxOffset = cellWidth * 0.3;

          final rotations = [
            0.25, -0.3, 0.4, -0.2, 0.35, -0.4, 0.3, -0.25, 0.45, -0.35, 0.2, -0.4,
            0.3, -0.25, 0.4, -0.3, 0.25, -0.4, 0.35, -0.2, 0.4, -0.3, 0.25, -0.35,
            0.3, -0.25, 0.4, -0.3, 0.35, -0.2, 0.3, -0.4, 0.25, -0.35, 0.4,
          ];

          final opacities = [
            0.10, 0.12, 0.11, 0.13, 0.09, 0.12, 0.10, 0.13, 0.11, 0.12, 0.10, 0.13,
            0.11, 0.12, 0.10, 0.13, 0.11, 0.12, 0.10, 0.13, 0.11, 0.12, 0.10, 0.13,
            0.11, 0.12, 0.10, 0.13, 0.11, 0.12, 0.10, 0.13, 0.11, 0.12, 0.10,
          ];

          final colors = [
            Colors.brown,
            Colors.orange,
            Colors.deepOrange,
            Colors.amber,
            Colors.grey,
            Colors.blueGrey,
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

                  final iconData = bookIcons[index % bookIcons.length];
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
                child: _buildContent(recipes, repo, l10n, userId),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _selectedMainType == null
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddRecipeScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.addRecipe),
            )
          : null,
    );
  }

  Widget _buildContent(
    AsyncValue<List<Recipe>> recipes,
    RecipesRepository repo,
    AppLocalizations l10n,
    String? userId,
  ) {
    // Ana kategori seçilmişse PageView ile alt kategorilerin tariflerini göster
    if (_selectedMainType != null) {
      return recipes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (list) {
          if (list.isEmpty) {
            return _GlobalEmptyState(l10n: l10n);
          }

          final filtered = list.where((r) => r.mainType == _selectedMainType).toList();
          final subTypes = RecipeTypes.subTypesOf(_selectedMainType!);

          if (subTypes.isEmpty) {
            return _GlobalEmptyState(l10n: l10n);
          }

          return _SubCategoriesPageView(
            subTypes: subTypes,
            recipes: filtered,
            l10n: l10n,
            mainType: _selectedMainType!,
            repo: repo,
            initialPage: _currentSubCategoryIndex,
            onPageChanged: (index) {
              setState(() => _currentSubCategoryIndex = index);
            },
          );
        },
      );
    }

    // Ana ekran: 3 buton
    return _MainCategoriesView(
      l10n: l10n,
      recipes: recipes,
      onMainTypeSelected: (mainType) {
        setState(() {
          _selectedMainType = mainType;
          _currentSubCategoryIndex = 0;
        });
      },
    );
  }
}

class _MainCategoriesView extends StatelessWidget {
  final AppLocalizations l10n;
  final AsyncValue<List<Recipe>> recipes;
  final Function(String) onMainTypeSelected;

  const _MainCategoriesView({
    required this.l10n,
    required this.recipes,
    required this.onMainTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return recipes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (list) {
        if (list.isEmpty) {
          return _GlobalEmptyState(l10n: l10n);
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MainCategoryButton(
                title: l10n.meals,
                icon: Icons.room_service,
                color: Colors.orange,
                count: list.where((r) => r.mainType == 'yemek').length,
                onTap: () => onMainTypeSelected('yemek'),
              ),
              const SizedBox(height: 16),
              _MainCategoryButton(
                title: l10n.desserts,
                icon: Icons.cake,
                color: Colors.pink,
                count: list.where((r) => r.mainType == 'tatli').length,
                onTap: () => onMainTypeSelected('tatli'),
              ),
              const SizedBox(height: 16),
              _MainCategoryButton(
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

class _MainCategoryButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;

  const _MainCategoryButton({
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

class _SubCategoriesPageView extends StatefulWidget {
  final List<String> subTypes;
  final List<Recipe> recipes;
  final AppLocalizations l10n;
  final String mainType;
  final RecipesRepository repo;
  final int initialPage;
  final Function(int) onPageChanged;

  const _SubCategoriesPageView({
    required this.subTypes,
    required this.recipes,
    required this.l10n,
    required this.mainType,
    required this.repo,
    required this.initialPage,
    required this.onPageChanged,
  });

  @override
  State<_SubCategoriesPageView> createState() => _SubCategoriesPageViewState();
}

class _SubCategoriesPageViewState extends State<_SubCategoriesPageView> {
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
                final subTypeRecipes = widget.recipes.where((r) => r.subType == subType).toList();
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
                          if (subTypeRecipes.isNotEmpty) ...[
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
                                '${subTypeRecipes.length}',
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
                final subTypeRecipes = widget.recipes.where((r) => r.subType == subType).toList();
                
                if (subTypeRecipes.isEmpty) {
                  return _CategoryEmptyState(l10n: widget.l10n);
                }
                
                return _RecipeListView(
                  recipes: subTypeRecipes,
                  repo: widget.repo,
                  l10n: widget.l10n,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeListView extends StatelessWidget {
  final List<Recipe> recipes;
  final RecipesRepository repo;
  final AppLocalizations l10n;

  const _RecipeListView({
    required this.recipes,
    required this.repo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: recipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final recipe = recipes[i];
        return Card(
          child: ListTile(
            title: Text(
              recipe.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              RecipeTypeLabels.summary(
                l10n,
                mainType: recipe.mainType,
                subType: recipe.subType,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, size: 18, color: Colors.redAccent),
                const SizedBox(width: 4),
                Text('${recipe.likesCount}'),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.edit,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditRecipeScreen(recipe: recipe),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(context, recipe),
                ),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Recipe recipe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteRecipe),
        content: Text('${recipe.title} ${l10n.deleteRecipeConfirm}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await repo.deleteRecipe(recipe.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.recipeDeleted)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.error}: $e')),
          );
        }
      }
    }
  }
}

class _GlobalEmptyState extends StatelessWidget {
  final AppLocalizations l10n;

  const _GlobalEmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(l10n.noRecipes),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddRecipeScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.addFirstRecipeButton),
          ),
        ],
      ),
    );
  }
}

class _CategoryEmptyState extends StatelessWidget {
  final AppLocalizations l10n;

  const _CategoryEmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.category_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(l10n.noRecipesInCategory),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddRecipeScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.addFirstRecipeButton),
          ),
        ],
      ),
    );
  }
}
