import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// 🔹 Provider dosyaları
import 'core/providers/auth_provider.dart';
import 'core/providers/onboarding_provider.dart';

// 🔹 Ekranlar
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/home/home_view.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tarif Defterim',
      theme: ThemeData(useMaterial3: true),
      // 🔹 Basit named routes
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const HomeView(),
      },
      home: const _RootGate(),
    );
  }
}

/// 🔹 İlk açılışta onboarding, sonra login/home kontrolü
class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingDoneProvider);

    return onboarding.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Onboarding yüklenemedi')),
      ),
      data: (done) {
        if (!done) {
          // 🔹 Onboarding ekranı ilk kez gösterilecek
          return const OnboardingScreen();
        }

        // 🔹 Onboarding tamamlandıysa Auth durumuna bak
        final authStream = ref.watch(firebaseAuthStateProvider);
        return authStream.when(
          data: (user) => user == null
              ? const LoginScreen()
              : const HomeView(),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const Scaffold(
            body: Center(child: Text('Oturum kontrolü hatası')),
          ),
        );
      },
    );
  }
}

