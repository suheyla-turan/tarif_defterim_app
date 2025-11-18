import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../core/providers/onboarding_provider.dart';
import '../../../core/providers/localization_provider.dart';
import '../../auth/screens/login_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    // Reset and restart animations for smooth page transitions
    _fadeController.reset();
    _slideController.reset();
    Future.microtask(() {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  Future<void> _finishOnboarding() async {
    await ref.read(onboardingProvider).completeOnboarding();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.grey[900]!,
                    Colors.grey[800]!,
                  ]
                : [
                    Colors.orange[50]!,
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _finishOnboarding,
                      child: Text(
                        l10n.onboardingSkip,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // PageView
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: _onPageChanged,
                  children: [
                    _OnboardingPage(
                      fadeAnimation: _fadeAnimation,
                      slideAnimation: _slideAnimation,
                      icon: Icons.restaurant_menu,
                      iconColor: Colors.orange,
                      title: l10n.onboardingWelcome,
                      description: l10n.onboardingWelcomeDesc,
                      gradientColors: [
                        Colors.orange[400]!,
                        Colors.orange[600]!,
                      ],
                    ),
                    _OnboardingPage(
                      fadeAnimation: _fadeAnimation,
                      slideAnimation: _slideAnimation,
                      icon: Icons.menu_book,
                      iconColor: Colors.purple,
                      title: l10n.onboardingRecipes,
                      description: l10n.onboardingRecipesDesc,
                      gradientColors: [
                        Colors.purple[400]!,
                        Colors.purple[600]!,
                      ],
                    ),
                    _OnboardingPage(
                      fadeAnimation: _fadeAnimation,
                      slideAnimation: _slideAnimation,
                      icon: Icons.shopping_cart,
                      iconColor: Colors.green,
                      title: l10n.onboardingShopping,
                      description: l10n.onboardingShoppingDesc,
                      gradientColors: [
                        Colors.green[400]!,
                        Colors.green[600]!,
                      ],
                    ),
                    _OnboardingPage(
                      fadeAnimation: _fadeAnimation,
                      slideAnimation: _slideAnimation,
                      icon: Icons.mic,
                      iconColor: Colors.blue,
                      title: l10n.onboardingAI,
                      description: l10n.onboardingAIDesc,
                      gradientColors: [
                        Colors.blue[400]!,
                        Colors.blue[600]!,
                      ],
                    ),
                    _OnboardingPage(
                      fadeAnimation: _fadeAnimation,
                      slideAnimation: _slideAnimation,
                      icon: Icons.rocket_launch,
                      iconColor: Colors.red,
                      title: l10n.onboardingReady,
                      description: l10n.onboardingReadyDesc,
                      gradientColors: [
                        Colors.red[400]!,
                        Colors.red[600]!,
                      ],
                    ),
                  ],
                ),
              ),

              // Page indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: SmoothPageIndicator(
                  controller: _controller,
                  count: 5,
                  effect: ExpandingDotsEffect(
                    activeDotColor: Colors.orange,
                    dotColor: Colors.grey.withOpacity(0.4),
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 3,
                    spacing: 8,
                  ),
                ),
              ),

              // Navigation buttons
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentPage > 0)
                      TextButton.icon(
                        onPressed: () {
                          _controller.previousPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: Text(l10n.back),
                      )
                    else
                      const SizedBox.shrink(),
                    _currentPage == 4
                        ? Expanded(
                            child: FilledButton.icon(
                              onPressed: _finishOnboarding,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.arrow_forward),
                              label: Text(
                                l10n.onboardingGetStarted,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        : Expanded(
                            child: FilledButton.icon(
                              onPressed: _nextPage,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.arrow_forward),
                              label: Text(
                                l10n.onboardingNext,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final List<Color> gradientColors;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.gradientColors,
    required this.fadeAnimation,
    required this.slideAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container with gradient
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 100,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),
              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[900],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),
              // Description
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark
                      ? Colors.grey[300]
                      : Colors.grey[700],
                  height: 1.6,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
