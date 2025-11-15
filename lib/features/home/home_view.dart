import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../recipes/screens/add_recipe_screen.dart';
import '../recipes/screens/my_recipes_screen.dart';
import '../recipes/screens/search_screen.dart';
import '../shopping/screens/shopping_list_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../recipes/screens/favorites_screen.dart';
import '../recipes/screens/category_recipes_screen.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(authControllerProvider).user;

    // ✅ Öncelik: firstName + lastName → displayName → email → "kullanıcı"
    final fullName = [
      appUser?.firstName?.trim(),
      appUser?.lastName?.trim(),
    ].where((e) => (e ?? '').isNotEmpty).join(' ').trim();

    final fallbackName = (appUser?.displayName?.trim().isNotEmpty ?? false)
        ? appUser!.displayName!
        : (appUser?.email ?? 'kullanıcı');

    final greetingText = 'Hoş geldin, ${fullName.isNotEmpty ? fullName : fallbackName}';

    return Scaffold(
      endDrawer: _MenuDrawer(onLogout: () {
        Navigator.of(context).pop();
        ref.read(authControllerProvider.notifier).signOut();
      }),
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 12,
        title: const Text(
          'TARİF DEFTERİM',
          style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Yeni Tarif',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddRecipeScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Ara',
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          Builder(
            builder: (ctx) => IconButton(
              tooltip: 'Menü',
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(greetingText, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kategoriler',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _CategoryCard(
                    title: 'Yemekler',
                    icon: Icons.restaurant,
                    color: Colors.orange,
                    onTap: () => _navigateToCategory(context, 'yemek'),
                  ),
                  _CategoryCard(
                    title: 'Tatlılar',
                    icon: Icons.cake,
                    color: Colors.pink,
                    onTap: () => _navigateToCategory(context, 'tatli'),
                  ),
                  _CategoryCard(
                    title: 'İçecekler',
                    icon: Icons.local_drink,
                    color: Colors.blue,
                    onTap: () => _navigateToCategory(context, 'icecek'),
                  ),
                  _CategoryCard(
                    title: 'Tüm Tarifler',
                    icon: Icons.menu_book,
                    color: Colors.green,
                    onTap: () => _navigateToAllRecipes(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),

      // Çırak butonu kaldırıldı
    );
  }

  void _navigateToCategory(BuildContext context, String mainType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryRecipesScreen(mainType: mainType),
      ),
    );
  }

  void _navigateToAllRecipes(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryRecipesScreen(mainType: null),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard({
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

class _MenuDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  const _MenuDrawer({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        );

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.7,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 8),
            Text('MENÜ', style: titleStyle),
            const Divider(thickness: 1.2),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tariflerim', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyRecipesScreen()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Alışveriş Listem', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Beğendiklerim', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                );
              },
            ),
            const SizedBox(height: 24),
            const Divider(thickness: 1.2),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Profil',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ayarlar'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Çıkış'),
            ),
          ],
        ),
      ),
    );
  }
}




