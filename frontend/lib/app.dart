import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:budget_app/services/auth_service.dart';
import 'screens/auth/login_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Listen to app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    if (Hive.isBoxOpen('settingsBox')) {
      Hive.box('settingsBox').listenable().removeListener(_onSettingsChanged);
    }
    super.dispose();
  }

  bool _wasDetached = false;
  DateTime? _lastPausedTime;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Only lock when app is detached (closed)
    // For paused/inactive, just track the time (user might be switching apps)
    if (state == AppLifecycleState.detached) {
      _wasDetached = true;
      _logoutOnAppClose();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Track when app was paused - if it was paused for a long time,
      // it might indicate phone was locked/slept
      _lastPausedTime = DateTime.now();
    }

    // When app resumes, check if it was closed (detached) or if it was paused for a long time
    // (indicating phone was locked/slept)
    if (state == AppLifecycleState.resumed) {
      if (_wasDetached) {
        // App was closed - require login
        _wasDetached = false;
        _checkAndNavigateToLogin();
      } else if (_lastPausedTime != null) {
        // Check if app was paused for more than 30 seconds (likely phone was locked/slept)
        final pauseDuration = DateTime.now().difference(_lastPausedTime!);
        if (pauseDuration.inSeconds > 30) {
          // App was paused for a long time - likely phone was locked/slept
          _logoutOnAppClose();
          _checkAndNavigateToLogin();
        }
        _lastPausedTime = null;
      }
    }
  }

  Future<void> _checkAndNavigateToLogin() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn && mounted && _navigatorKey.currentState != null) {
      // Clear navigation stack and go to login screen without animation
      _navigatorKey.currentState?.pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
        (route) => false,
      );
    }
  }

  Future<void> _logoutOnAppClose() async {
    try {
      // Clear user session when app is closed
      await AuthService.logout();
      print('User logged out due to app being closed');
    } catch (e) {
      print('Error logging out on app close: $e');
    }
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
    // Use ValueListenableBuilder to reactively update theme when settings change
    return ValueListenableBuilder<Box>(
      valueListenable: Hive.box('settingsBox').listenable(),
      builder: (context, box, _) {
        final themeMode = box.get('themeMode', defaultValue: 'light') as String;
        // Ensure we only use 'light' or 'dark', default to 'light' if invalid
        final isDarkMode = (themeMode == 'dark');

        return MaterialApp(
          title: 'SpendSense',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: FutureBuilder<bool>(
            future: _checkLoginStatus(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }
              // Check if user is logged in - if not, show login screen
              // This prevents flashing the home screen
              final isLoggedIn = snapshot.data ?? false;
              if (isLoggedIn) {
                // User is logged in - show home (will be handled by login screen check)
                return const LoginScreen(); // LoginScreen will auto-redirect if logged in
              }
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }

  Future<bool> _checkLoginStatus() async {
    // Check if user is logged in
    // This prevents flashing home screen before login check
    try {
      return await AuthService.isLoggedIn();
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _textSlide;
  late Animation<double> _textFade;

  @override
  void initState() {
    super.initState();

    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );

    _logoRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOut,
      ),
    );

    _textSlide = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeIn,
      ),
    );

    // Start animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _textController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryTurquoise = const Color(0xFF14B8A6);
    final primaryBlue = const Color(0xFF0EA5E9);
    final accentBlue = const Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryTurquoise.withOpacity(0.15),
              primaryBlue.withOpacity(0.1),
              accentBlue.withOpacity(0.08),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScale.value,
                    child: Transform.rotate(
                      angle: (_logoRotation.value - 1.0) * 0.1,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primaryTurquoise.withOpacity(0.2),
                              primaryBlue.withOpacity(0.15),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryTurquoise.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'images/logo.png',
                          width: 120,
                          height: 120,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              // Animated SpendSense Text
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _textSlide.value),
                    child: Opacity(
                      opacity: _textFade.value,
                      child: Text(
                        'SpendSense',
                        style: GoogleFonts.poppins(
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: primaryTurquoise,
                          shadows: [
                            Shadow(
                              color: primaryTurquoise.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 50),
              // Loading indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryTurquoise),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
