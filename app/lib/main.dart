import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/auth_screens.dart';
import 'screens/home_shell.dart';
import 'screens/splash.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ApplyToAnythingApp());
}

class ApplyToAnythingApp extends StatelessWidget {
  const ApplyToAnythingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..boot(),
      child: MaterialApp(
        title: 'ApplyToAnything',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const Root(),
      ),
    );
  }
}

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.booted) return const SplashScreen();
    if (app.user == null) return const LoginScreen();
    return const HomeShell();
  }
}
