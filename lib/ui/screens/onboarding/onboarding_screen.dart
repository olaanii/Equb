import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equb/providers/app_providers.dart';
import 'package:equb/ui/screens/auth/signup_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      image: 'assets/images/onboarding_culture.png',
      title: 'Rooted in Tradition',
      description:
          'Experience the timeless Ethiopian Equb, reimagined for the digital age. Connect with your community in a trusted, modern way.',
    ),
    _OnboardingPage(
      image: 'assets/images/onboarding_trust.png',
      title: 'Secured by Technology',
      description:
          'Instant deposits via Telebirr & CBE. Our transparent, provably fair lottery system ensures everyone gets their turn.',
    ),
    _OnboardingPage(
      image: 'assets/images/onboarding_growth.png',
      title: 'Grow Together',
      description:
          'Save consistently, access credit when you need it, and achieve your financial goals with the power of your community.',
    ),
  ];

  Future<void> _completeOnboarding({bool startWithSignup = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (startWithSignup && mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SignupScreen()));
    }

    // Invalidate the provider so AuthWrapper fetches the new status and redirects.
    ref.invalidate(onboardingStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.background,
      body: Stack(
        children: [
          // Background Gradient (Subtle)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [scheme.surface, scheme.background],
                ),
              ),
            ),
          ),

          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged:
                      (index) => setState(() => _currentPage = index),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return _buildPage(page);
                  },
                ),
              ),
              _buildBottomControls(),
            ],
          ),

          // Skip Button
          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: () => _completeOnboarding(startWithSignup: true),
              child: Text(
                'Skip',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(page.image, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 40),
          // Text
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  page.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Outfit', // Assuming standard app font
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  page.description,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Indicator
          Row(
            children: List.generate(
              _pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 8),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color:
                      _currentPage == index
                          ? AppColors.primary
                          : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          // Button
          ElevatedButton(
            onPressed: () {
              if (_currentPage < _pages.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              } else {
                _completeOnboarding();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
            ),
            child: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String image;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.image,
    required this.title,
    required this.description,
  });
}
