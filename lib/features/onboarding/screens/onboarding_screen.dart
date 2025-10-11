import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../core/providers/onboarding_provider.dart';
import '../../auth/screens/login_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  bool isLastPage = false;

  Future<void> _finishOnboarding() async {
    await ref.read(onboardingProvider).completeOnboarding(); // ✅ Riverpod
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (index) => setState(() => isLastPage = index == 2),
                  children: const [
                    _OnboardingPage(
                      image: null,
                      title: 'Hoş Geldin!',
                      description: 'Tariflerini kolayca kaydet, paylaş ve keşfet.',
                    ),
                    _OnboardingPage(
                      image: null,
                      title: 'Kendine Özel Defter',
                      description: 'Favori tariflerini tek bir yerde topla.',
                    ),
                    _OnboardingPage(
                      image: null,
                      title: 'Hazırsan Başlayalım!',
                      description: 'Hemen kayıt ol veya giriş yap.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SmoothPageIndicator(
                controller: _controller,
                count: 3,
                effect: const ExpandingDotsEffect(activeDotColor: Colors.orange),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _finishOnboarding, // ✅ Atla
                    child: const Text('Atla'),
                  ),
                  isLastPage
                      ? ElevatedButton(
                          onPressed: _finishOnboarding, // ✅ Başla
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: const Text('Başla'),
                        )
                      : TextButton(
                          onPressed: () => _controller.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                          ),
                          child: const Text('İleri →'),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String? image;
  final String title;
  final String description;

  const _OnboardingPage({
    this.image,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (image != null) {
      img = Image.asset(
        image!,
        height: 250,
        errorBuilder: (_, __, ___) => const Placeholder(fallbackHeight: 250),
      );
    } else {
      img = Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.restaurant_menu, size: 80, color: Colors.orange),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        img,
        const SizedBox(height: 40),
        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }
}

