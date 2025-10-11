import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/providers/onboarding_provider.dart';
import 'core/providers/auth_provider.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
// Login/Register henüz boş; Adım 4'te dolduracağız ama import edip ismi kullanalım:
import 'features/auth/screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TarifDefterimApp());
}

class TarifDefterimApp extends StatelessWidget {
  const TarifDefterimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OnboardingProvider()..init()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tarif Defterim',
        theme: ThemeData(primarySwatch: Colors.orange),
        home: const _RootDecider(),
      ),
    );
  }
}

class _RootDecider extends StatelessWidget {
  const _RootDecider();

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingProvider>();
    final auth = context.watch<AuthProvider>();

    if (!onboarding.isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!onboarding.isCompleted) {
      return const OnboardingScreen();
    }

    return auth.isLoggedIn ? const DummyHomeScreen() : const LoginScreen();
  }
}

// Geçici anasayfa (giriş sonrası)
class DummyHomeScreen extends StatelessWidget {
  const DummyHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tarif Defterim')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Hoş geldin, ${auth.userEmail ?? 'Misafir'}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.read<AuthProvider>().signOut(),
              child: const Text('Çıkış Yap'),
            ),
          ],
        ),
      ),
    );
  }
}
