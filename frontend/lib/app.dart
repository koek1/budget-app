import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:budget_app/services/settings_service.dart';
import 'screens/auth/login_screen.dart';

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
    final primaryTurquoise = const Color(0xFF14B8A6); // Turquoise
    return ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: primaryTurquoise,
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
    final darkGrey = Color(0xFF1E293B);
    final primaryTurquoise = const Color(0xFF14B8A6); // Turquoise
    return ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: primaryTurquoise,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Color(0xFF0F172A),
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
        selectedItemColor: primaryTurquoise,
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
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: FutureBuilder(
        future: _checkLoginStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          // Always show login screen - don't persist login across app restarts
          return const LoginScreen();
        },
      ),
    );
  }

  Future<bool> _checkLoginStatus() async {
    // Don't persist login - user must login every time app opens
    // This ensures security and prevents auto-login after app close
    return false;
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryTurquoise = const Color(0xFF14B8A6);
    final primaryBlue = const Color(0xFF0EA5E9);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryTurquoise,
              primaryBlue,
              const Color(0xFF3B82F6),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'images/logo.png',
                          width: 100,
                          height: 100,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'SpendSense',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 40),
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
