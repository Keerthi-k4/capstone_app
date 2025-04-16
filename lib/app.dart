import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attempt2/screens/auth/login_screen.dart';
import 'package:attempt2/screens/auth/signup_screen.dart';
import 'package:attempt2/screens/home_screen.dart';
import 'package:attempt2/core/theme.dart';
import 'package:attempt2/providers/auth_provider.dart';
import 'package:attempt2/providers/diet_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DietProvider()),
      ],
      child: MaterialApp(
        title: 'Diet & Fitness App',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) =>
              const SignupScreen(), // Fixed casing to match class name
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}
