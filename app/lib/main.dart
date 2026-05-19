import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'screens/settings/settings_screen.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Background sync task
    try {
      // Note: full DI not available in background isolate.
      // Sync is handled by SyncService which creates its own DB + ApiService.
      // For simplicity, we skip background sync here and rely on foreground sync.
    } catch (_) {}
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register background sync every 15 minutes
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'tractormate_sync',
    'syncTask',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );

  runApp(const ProviderScope(child: TractorMateApp()));
}

class TractorMateApp extends ConsumerWidget {
  const TractorMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);

    return MaterialApp(
      title: 'TractorMate',
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('kn')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      home: const _Splash(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
      },
    );
  }
}

class _Splash extends ConsumerWidget {
  const _Splash();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Widget>(
      future: _resolveStartScreen(ref),
      builder: (ctx, snap) {
        if (snap.hasData) return snap.data!;
        return const Scaffold(
          backgroundColor: AppTheme.primary,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.agriculture, size: 80, color: Colors.white),
                SizedBox(height: 16),
                Text('TractorMate',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                Text('ಟ್ರ್ಯಾಕ್ಟರ್‌ಮೇಟ್',
                    style: TextStyle(color: Colors.white70, fontSize: 18)),
                SizedBox(height: 32),
                CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Widget> _resolveStartScreen(WidgetRef ref) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Show splash briefly

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    if (!onboardingDone) return const OnboardingScreen();

    final authState = ref.read(authProvider);
    if (authState.isLoggedIn) return const HomeScreen();

    // Check token in storage
    final api = ref.read(apiServiceProvider);
    final hasToken = await api.isLoggedIn();
    if (hasToken) return const HomeScreen();

    return const LoginScreen();
  }
}
