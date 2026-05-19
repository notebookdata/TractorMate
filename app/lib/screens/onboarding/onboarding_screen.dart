import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = const [
    _OnboardPage(
      icon: Icons.agriculture,
      title: 'Track Rentals Easily',
      titleKn: 'ಸುಲಭವಾಗಿ ಬಾಡಿಗೆ ದಾಖಲಿಸಿ',
      desc: 'Record every tractor rental with customer name, work type, and payment in seconds.',
      descKn: 'ಗ್ರಾಹಕರ ಹೆಸರು, ಕೆಲಸದ ವಿಧ ಮತ್ತು ಪಾವತಿಯನ್ನು ಕ್ಷಣಾರ್ಧದಲ್ಲಿ ದಾಖಲಿಸಿ.',
      color: AppTheme.primary,
    ),
    _OnboardPage(
      icon: Icons.receipt_long,
      title: 'Monitor All Expenses',
      titleKn: 'ಎಲ್ಲಾ ಖರ್ಚುಗಳನ್ನು ಟ್ರ್ಯಾಕ್ ಮಾಡಿ',
      desc: 'Track diesel, repairs, and maintenance costs to know your true profit.',
      descKn: 'ಡೀಸೆಲ್, ದುರಸ್ತಿ ಮತ್ತು ನಿರ್ವಹಣಾ ವೆಚ್ಚಗಳನ್ನು ಟ್ರ್ಯಾಕ್ ಮಾಡಿ.',
      color: AppTheme.secondary,
    ),
    _OnboardPage(
      icon: Icons.cloud_done,
      title: 'Works Offline',
      titleKn: 'ಆಫ್‌ಲೈನ್‌ನಲ್ಲಿ ಕಾರ್ಯ ನಿರ್ವಹಿಸುತ್ತದೆ',
      desc: 'Use the app anywhere — even without internet. Data syncs automatically when back online.',
      descKn: 'ಇಂಟರ್ನೆಟ್ ಇಲ್ಲದೆಯೂ ಬಳಸಿ. ಆನ್‌ಲೈನ್ ಬಂದಾಗ ಸ್ವಯಂಚಾಲಿತವಾಗಿ ಸಿಂಕ್ ಆಗುತ್ತದೆ.',
      color: Colors.blue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip', style: TextStyle(fontSize: 16)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (ctx, i) => _pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Row(
                    children: List.generate(_pages.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? AppTheme.primary : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _page == _pages.length - 1 ? _finish : _next,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 52),
                    ),
                    child: Text(_page == _pages.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(fontSize: 17)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _next() => _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }
}

class _OnboardPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String titleKn;
  final String desc;
  final String descKn;
  final Color color;

  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.titleKn,
    required this.desc,
    required this.descKn,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: color),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            titleKn,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            descKn,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.5),
          ),
        ],
      ),
    );
  }
}
