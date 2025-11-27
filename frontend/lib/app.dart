import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:budget_app/services/auth_service.dart';
import 'package:budget_app/services/biometric_service.dart';
import 'package:budget_app/services/settings_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Listen to settings changes - ensure box is open first
    _setupSettingsListener();
  }

  void _setupSettingsListener() {
    if (Hive.isBoxOpen('settingsBox')) {
      Hive.box('settingsBox').listenable().addListener(_onSettingsChanged);
    }
  }

  @override
  void dispose() {
    if (Hive.isBoxOpen('settingsBox')) {
      Hive.box('settingsBox').listenable().removeListener(_onSettingsChanged);
    }
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {
        // Rebuild app when settings change
      });
    }
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: Color(0xFF2563EB),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardColor: Colors.white,
      dividerColor: Colors.grey[300],
    );
  }

  ThemeData _buildDarkTheme() {
    final darkGrey = Color(0xFF1E1E1E);
    return ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: Color(0xFF2563EB),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Color(0xFF121212),
      appBarTheme: AppBarTheme(
        backgroundColor: darkGrey,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardColor: darkGrey,
      dividerColor: Colors.grey[700],
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkGrey,
        selectedItemColor: Color(0xFF2563EB),
        unselectedItemColor: Colors.grey[400],
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = SettingsService.isDarkMode();

    return MaterialApp(
      title: 'SpendSense',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: FutureBuilder(
        future: _checkLoginStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          return snapshot.data == true
              ? const HomeScreen()
              : const LoginScreen();
        },
      ),
    );
  }

  Future<bool> _checkLoginStatus() async {
    // First check if user is already logged in
    final isLoggedIn = await AuthService.isLoggedIn();
    if (isLoggedIn) return true;

    // If not logged in, check if biometric is enabled and available
    final biometricEnabled = await BiometricService.isBiometricEnabled();
    final biometricAvailable = await BiometricService.isAvailable();

    if (biometricEnabled && biometricAvailable) {
      // Try biometric login automatically
      final user = await BiometricService.loginWithBiometric();
      return user != null;
    }

    return false;
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              'SpendSense',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
