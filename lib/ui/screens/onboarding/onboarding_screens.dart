import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<_OnboardingItem> _items = [
    _OnboardingItem(
      title: 'Modern Saving Circles',
      subtitle:
          'Join trusted Equb groups digitally. Save together, grow together with friends and community.',
      icon: Icons.groups_rounded,
    ),
    _OnboardingItem(
      title: 'Automated Contributions',
      subtitle:
          'Never miss a round. Secure payments via Telebirr, CBE, or other gateways fully automated.',
      icon: Icons.autorenew_rounded,
    ),
    _OnboardingItem(
      title: 'Transparent Payouts',
      subtitle:
          'Track winners, rounds, and your payout date. Fair and transparent for everyone.',
      icon: Icons.payments_rounded,
    ),
  ];

  void _nextPage() {
    if (_currentIndex < _items.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    // Navigate to dashboard/home
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    // NeoPay Style: Clean white background, lime accents
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _items.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  return _OnboardingPage(item: _items[index]);
                },
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final isLast = _currentIndex == _items.length - 1;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dots Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_items.length, (index) {
              final isActive = index == _currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 32 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.surfaceBright,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          // Buttons
          Row(
            children: [
              if (!isLast)
                TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Skip',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLast ? 'Get Started' : 'Next',
                      style: AppTextStyles.button.copyWith(color: Colors.black),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLast ? Icons.check : Icons.arrow_forward_rounded,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingItem {
  final String title;
  final String subtitle;
  final IconData icon;

  _OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingItem item;

  const _OnboardingPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color:
                  AppColors.surface, // Misty Gray background for illustration
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              size: 100, // Big Icon
              color: AppColors.primary, // Lime Icon
            ),
          ),
          const SizedBox(height: 48),
          Text(
            item.title,
            style: AppTextStyles.headline1.copyWith(
              fontSize: 28,
              height: 1.2,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            item.subtitle,
            style: AppTextStyles.bodyText1.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
