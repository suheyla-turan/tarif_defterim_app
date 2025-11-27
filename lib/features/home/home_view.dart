import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/localization_provider.dart';
import '../recipes/screens/my_recipes_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../recipes/screens/favorites_screen.dart';
import '../recipes/screens/category_recipes_screen.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(authControllerProvider).user;
    final l10n = AppLocalizations.of(context);

    // ✅ Öncelik: firstName → firstName + lastName → displayName → email → "kullanıcı"
    final firstName = appUser?.firstName?.trim() ?? '';
    final lastName = appUser?.lastName?.trim() ?? '';
    
    String userName;
    if (firstName.isNotEmpty) {
      userName = lastName.isNotEmpty ? '$firstName $lastName' : firstName;
    } else if ((appUser?.displayName?.trim().isNotEmpty ?? false)) {
      userName = appUser!.displayName!;
    } else {
      final email = appUser?.email;
      userName = email != null ? email.split('@').first : (l10n.isTurkish ? 'kullanıcı' : 'user');
    }

    final greetingText = '${l10n.welcome}, $userName';

    return Scaffold(
      endDrawer: _MenuDrawer(onLogout: () async {
        Navigator.of(context).pop();
        await ref.read(authControllerProvider.notifier).signOut();
        if (!context.mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 12,
        toolbarHeight: kToolbarHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: Text(
          l10n.appName,
          style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: l10n.profile,
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                greetingText,
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3)
                  : Colors.orange.shade50,
              Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2)
                  : Colors.amber.shade50,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;
            
            // Anasayfa için sadece mutfak malzemeleri/araçları
            final kitchenIcons = [
              Icons.soup_kitchen,     // Tencere
              Icons.blender,          // Blender
              Icons.kitchen,          // Mutfak (tava/kap olarak)
              Icons.local_dining,     // Yemek (kepçe olarak)
              Icons.set_meal,         // Yemek seti (spatula olarak)
              Icons.restaurant_menu,  // Menü (mutfak aleti olarak)
              Icons.bakery_dining,    // Fırın
              Icons.breakfast_dining, // Kahvaltı (mutfak aleti olarak)
            ];
            
            // Grid parametreleri - karışık ama düzenli yerleşim için
            final cols = 6; // Sütun sayısı
            final rows = 8; // Satır sayısı
            final cellWidth = screenWidth / cols;
            final cellHeight = screenHeight / rows;
            final iconSize = (cellWidth * 0.4).clamp(40.0, 70.0);
            final spacing = cellWidth * 0.15; // Simgeler arası boşluk
            final maxOffset = cellWidth * 0.25; // Karışık görünüm için maksimum offset
            
            // Rotasyon açıları
            final rotations = [
              0.3, -0.2, 0.5, -0.4, 0.3, -0.25,
              0.45, 0.5, -0.4, 0.3, -0.6, 0.25,
              -0.35, 0.55, 0.2, -0.5, 0.4, -0.3,
              0.6, -0.25, 0.45, 0.3, -0.2, 0.5,
            ];
            
            // Opacity değerleri
            final opacities = [
              0.12, 0.14, 0.11, 0.13, 0.10, 0.15,
              0.12, 0.13, 0.11, 0.14, 0.10, 0.15,
              0.12, 0.13, 0.11, 0.14, 0.10, 0.15,
              0.12, 0.13, 0.11, 0.14, 0.10, 0.15,
            ];
            
            // Renkler
            final colors = [
              Colors.orange,
              Colors.amber,
              Colors.brown,
              Colors.grey,
              Colors.blueGrey,
              Colors.deepOrange,
            ];
            
            return Stack(
              children: [
                // Karışık ama düzenli grid sistemine göre mutfak malzemeleri
                ...List.generate(
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
                    
                    final x = (baseX + offsetX).clamp(spacing, screenWidth - iconSize - spacing);
                    final y = (baseY + offsetY).clamp(spacing, screenHeight - iconSize - spacing);
                    
                    final iconData = kitchenIcons[index % kitchenIcons.length];
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
                Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + kToolbarHeight + 20 + 4,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.categories,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      padding: EdgeInsets.zero,
                      childAspectRatio: 1.2,
                      children: [
                        _CategoryCard(
                          title: l10n.meals,
                          icon: Icons.room_service, // Yemek simgesi: tepsi
                          color: Colors.orange,
                          onTap: () => _navigateToCategory(context, 'yemek'),
                        ),
                        _CategoryCard(
                          title: l10n.desserts,
                          icon: Icons.cake,
                          color: Colors.pink,
                          onTap: () => _navigateToCategory(context, 'tatli'),
                        ),
                        _CategoryCard(
                          title: l10n.drinks,
                          icon: Icons.local_drink,
                          color: Colors.blue,
                          onTap: () => _navigateToCategory(context, 'icecek'),
                        ),
                        _CategoryCard(
                          title: l10n.favorites,
                          icon: Icons.favorite,
                          color: Colors.red,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                            );
                          },
                        ),
                        _CategoryCard(
                          title: l10n.myRecipes,
                          icon: Icons.menu_book,
                          color: Colors.purple,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const MyRecipesScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
              ],
            );
          },
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
    final l10n = AppLocalizations.of(context);
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
            Text(l10n.appName, style: titleStyle),
            const Divider(thickness: 1.2),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.myRecipes, style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyRecipesScreen()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.favorites, style: const TextStyle(fontWeight: FontWeight.w700)),
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
              title: Text(l10n.profile,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settings),
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
              label: Text(l10n.signOut),
            ),
          ],
        ),
      ),
    );
  }
}




