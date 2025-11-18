import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

//  Provider dosyaları
import 'core/providers/auth_provider.dart';
import 'core/providers/onboarding_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/localization_provider.dart';

//  Ekranlar
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/home/home_view.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // .env dosyasını yükle
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: .env file not found. Using default values. Error: $e');
  }
  
  // Global error handling - uygulamanın çökmesini önle
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Production'da burada crash reporting yapılabilir
  };
  
  // Platform hatalarını yakala
  PlatformDispatcher.instance.onError = (error, stack) {
    // Hataları logla ama uygulamayı çökertme
    debugPrint('Platform error: $error');
    debugPrint('Stack trace: $stack');
    return true; // Hatayı işledik
  };
  
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Firebase başlatma başarısız olsa bile uygulamayı çalıştır
  }
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final locale = ref.watch(localeProvider);
    
    // Tema seçimi
    ThemeMode themeMode;
    switch (settings.theme) {
      case AppTheme.light:
        themeMode = ThemeMode.light;
        break;
      case AppTheme.dark:
        themeMode = ThemeMode.dark;
        break;
      case AppTheme.system:
        themeMode = ThemeMode.system;
        break;
    }
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tarif Defterim',
      locale: locale,
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
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
        // Önce Firebase Auth durumunu kontrol et
        final authStream = ref.watch(firebaseAuthStateProvider);
        
        // Firebase Auth durumu değiştiğinde profil kontrolünü güncelle
        ref.listen(firebaseAuthStateProvider, (previous, next) {
          next.when(
            data: (firebaseUser) {
              // Auth durumu değiştiğinde profil kontrolü yap
              ref.read(authControllerProvider.notifier).checkAuthState();
            },
            loading: () {},
            error: (_, __) {},
          );
        });
        
        return authStream.when(
          data: (firebaseUser) {
            // Firebase Auth'da kullanıcı yoksa giriş sayfasına yönlendir
            if (firebaseUser == null) {
              return const LoginScreen();
            }
            
            // Firebase Auth'da kullanıcı varsa, profil kontrolü yap
            final authState = ref.watch(authControllerProvider);
            
            // Profil yükleniyorsa bekle
            if (authState.loading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            // Profil yoksa (yani daha önce başarılı giriş yapılmamışsa) giriş sayfasına yönlendir
            if (authState.user == null) {
              return const LoginScreen();
            }
            
            // Profil varsa ana sayfaya yönlendir
            return const HomeView();
          },
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

