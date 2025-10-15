import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/home_provider.dart';
import '../recipes/screens/add_recipe_screen.dart';
import '../recipes/screens/my_recipes_screen.dart';
import '../recipes/screens/search_screen.dart';
import '../recipes/screens/favorites_screen.dart';
import '../shopping/screens/shopping_list_screen.dart';

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

    final recipes = ref.watch(recipesStreamProvider);

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
          children: [
            Expanded(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    // TODO: Tarif listesi sayfasına git
                  },
                  child: Center(
                    child: recipes.when(
                      data: (snap) => Text(
                        'Tarifler (${snap.size})',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Tarifler yüklenemedi'),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),

      // Çırak butonu kaldırıldı
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
            const SizedBox(height: 24),
            const Divider(thickness: 1.2),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Profil',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Profil
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ayarlar'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FavoritesScreen()),
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




