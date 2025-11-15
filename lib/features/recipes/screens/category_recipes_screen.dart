import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import 'recipe_detail_screen.dart';
import '../application/recipes_provider.dart';
import '../constants/recipe_types.dart';

class CategoryRecipesScreen extends ConsumerWidget {
  final String? mainType;
  
  const CategoryRecipesScreen({
    super.key,
    this.mainType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kategori başlığını belirle
    String title;
    IconData icon;
    Color color;
    
    switch (mainType) {
      case 'yemek':
        title = 'Yemekler';
        icon = Icons.restaurant;
        color = Colors.orange;
        break;
      case 'tatli':
        title = 'Tatlılar';
        icon = Icons.cake;
        color = Colors.pink;
        break;
      case 'icecek':
        title = 'İçecekler';
        icon = Icons.local_drink;
        color = Colors.blue;
        break;
      default:
        title = 'Tüm Tarifler';
        icon = Icons.menu_book;
        color = Colors.green;
    }

    // Alt kategorileri al
    final subTypes = mainType != null ? RecipeTypes.subTypesOf(mainType!) : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        backgroundColor: color.withOpacity(0.1),
      ),
      body: Column(
        children: [
          // Alt kategoriler (sadece ana kategori seçilmişse göster)
          if (mainType != null && subTypes.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alt Kategoriler',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: subTypes.length,
                      itemBuilder: (context, index) {
                        final subType = subTypes[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _SubCategoryChip(
                            label: _getSubTypeDisplayName(subType),
                            onTap: () => _navigateToSubCategory(context, mainType!, subType),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          
          // Tarifler listesi
          Expanded(
            child: _RecipesList(mainType: mainType),
          ),
        ],
      ),
    );
  }

  String _getSubTypeDisplayName(String subType) {
    switch (subType) {
      case 'corba':
        return 'Çorba';
      case 'ana_yemek':
        return 'Ana Yemek';
      case 'meze':
        return 'Meze';
      case 'salata':
        return 'Salata';
      case 'hamur_isi':
        return 'Hamur İşi';
      case 'sutlu':
        return 'Sütlü';
      case 'serbetli':
        return 'Şerbetli';
      case 'kek_pasta':
        return 'Kek & Pasta';
      case 'kurabiye':
        return 'Kurabiye';
      case 'sicak':
        return 'Sıcak';
      case 'soguk':
        return 'Soğuk';
      case 'smoothie':
        return 'Smoothie';
      default:
        return subType;
    }
  }

  void _navigateToSubCategory(BuildContext context, String mainType, String subType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubCategoryRecipesScreen(
          mainType: mainType,
          subType: subType,
        ),
      ),
    );
  }
}

class _RecipesList extends ConsumerWidget {
  final String? mainType;

  const _RecipesList({this.mainType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(recipesRepositoryProvider);
    
    // Tarifleri filtrele
    final recipesStream = mainType != null
        ? repository.searchFiltered(mainType: mainType)
        : repository.watchAllRecipes();

    return StreamBuilder<List<Recipe>>(
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
                  'Tarifler yüklenemedi',
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
                Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Bu kategoride henüz tarif yok',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'İlk tarifi sen ekle!',
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

class _SubCategoryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SubCategoryChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w500,
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
    
    // Ana kategori başlığını belirle
    String mainTitle;
    IconData mainIcon;
    Color mainColor;
    
    switch (mainType) {
      case 'yemek':
        mainTitle = 'Yemekler';
        mainIcon = Icons.restaurant;
        mainColor = Colors.orange;
        break;
      case 'tatli':
        mainTitle = 'Tatlılar';
        mainIcon = Icons.cake;
        mainColor = Colors.pink;
        break;
      case 'icecek':
        mainTitle = 'İçecekler';
        mainIcon = Icons.local_drink;
        mainColor = Colors.blue;
        break;
      default:
        mainTitle = 'Tarifler';
        mainIcon = Icons.menu_book;
        mainColor = Colors.green;
    }

    // Alt kategori başlığını belirle
    String subTitle;
    switch (subType) {
      case 'corba':
        subTitle = 'Çorba';
        break;
      case 'ana_yemek':
        subTitle = 'Ana Yemek';
        break;
      case 'meze':
        subTitle = 'Meze';
        break;
      case 'salata':
        subTitle = 'Salata';
        break;
      case 'hamur_isi':
        subTitle = 'Hamur İşi';
        break;
      case 'sutlu':
        subTitle = 'Sütlü';
        break;
      case 'serbetli':
        subTitle = 'Şerbetli';
        break;
      case 'kek_pasta':
        subTitle = 'Kek & Pasta';
        break;
      case 'kurabiye':
        subTitle = 'Kurabiye';
        break;
      case 'sicak':
        subTitle = 'Sıcak';
        break;
      case 'soguk':
        subTitle = 'Soğuk';
        break;
      case 'smoothie':
        subTitle = 'Smoothie';
        break;
      default:
        subTitle = subType;
    }

    // Tarifleri filtrele
    final recipesStream = repository.searchFiltered(
      mainType: mainType,
      subType: subType,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(mainIcon, color: mainColor, size: 20),
                const SizedBox(width: 8),
                Text(mainTitle, style: const TextStyle(fontSize: 16)),
              ],
            ),
            Text(
              subTitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: mainColor,
                fontWeight: FontWeight.w500,
              ),
            ),
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
                    'Tarifler yüklenemedi',
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
                    '$subTitle kategorisinde henüz tarif yok',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İlk tarifi sen ekle!',
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
