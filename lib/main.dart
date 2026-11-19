import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database/database_helper.dart';
import 'navigation/main_shell.dart';
import 'pages/onboarding_page.dart';
import 'security/app_lock_gate.dart';
import 'services/notification_service.dart';
import 'state/category_store.dart';
import 'state/event_store.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CategoryStore()),
        ChangeNotifierProvider(create: (_) => EventStore()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: NotificationService.navigatorKey,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.transparent, // Allow background image to show
          primaryColor: AppColors.accent,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            secondary: AppColors.accent,
            surface: AppColors.componentBase,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent, // Allow background image to show
            foregroundColor: AppColors.primaryText,
            elevation: 0,
          ),
          cardColor: AppColors.componentBase,
          dividerColor: AppColors.lightShadow,
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: AppColors.primaryText),
            bodyMedium: TextStyle(color: AppColors.primaryText),
            titleLarge: TextStyle(color: AppColors.primaryText),
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: AppColors.darkShadow,
            contentTextStyle: TextStyle(color: AppColors.primaryText),
          ),
        ),
        // Above the Navigator, so the lock covers every route and dialog.
        builder: (context, child) => AppLockGate(child: child!),
        home: const AppGate(),
      ),
    );
  }
}

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  bool _checking = true;
  bool _isNewUser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pick up anything the native listener captured while we were away, and
    // surface anything the background isolate already stored.
    if (state == AppLifecycleState.resumed) {
      NotificationService.onResumed();
    }
  }

  Future<void> _checkUser() async {
    final name = await DatabaseHelper.instance.getUserSetting('user_name');
    if (mounted) {
      setState(() {
        _isNewUser = name == null || name.isEmpty;
        _checking = false;
      });
    }
  }

  void _onOnboardingComplete() {
    setState(() => _isNewUser = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
           // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Content
          if (_checking)
            const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          else if (_isNewUser)
            OnboardingPage(onComplete: _onOnboardingComplete)
          else
            const MainShell(),
        ],
      ),
    );
  }
}
