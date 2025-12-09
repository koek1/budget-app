import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:budget_app/services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/initial_splash_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isAppInBackground = false;
  bool _settingsBoxReady = false;

  @override
  void initState() {
    super.initState();
    // Listen to app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    // Check if settings box is ready and listen for it to become available
    _checkSettingsBox();
    // Disable screenshot protection initially (will be enabled when app goes to background)
    _disableScreenshotProtection();
  }

  void _checkSettingsBox() {
    if (Hive.isBoxOpen('settingsBox')) {
      if (!_settingsBoxReady) {
        setState(() {
          _settingsBoxReady = true;
        });
      }
      _setupSettingsListener();
    } else {
      // Check again after a short delay
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _checkSettingsBox();
        }
      });
    }
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
  bool _wasPaused = false;
  bool _wasInactive = false; // Track inactive state separately

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print('App lifecycle state changed to: $state');
    print(
        'Current flags: _wasDetached=$_wasDetached, _wasPaused=$_wasPaused, _wasInactive=$_wasInactive');

    // Handle different app lifecycle states
    if (state == AppLifecycleState.detached) {
      // App is being closed/terminated
      print('App detached - closing/terminating');
      _wasDetached = true;
      _isAppInBackground = true;
      _logoutOnAppClose();
      _enableScreenshotProtection();
      setState(() {}); // Update UI to show blur overlay
    } else if (state == AppLifecycleState.paused) {
      // App is minimized (goes to background)
      // IMPORTANT: Always set _wasPaused when app goes to paused state
      // The inactive state check was preventing proper detection of minimize
      print('App paused - minimized/backgrounded');
      _wasPaused = true;
      _isAppInBackground = true;
      _logoutOnAppClose();
      _enableScreenshotProtection();
      setState(() {}); // Update UI to show blur overlay
      _wasInactive = false; // Reset inactive flag
    } else if (state == AppLifecycleState.inactive) {
      // App is temporarily inactive (notification bar, incoming call, etc.)
      // Do NOT logout or set paused flag - this is temporary
      // But also don't clear _wasPaused if it was already set
      print('App inactive - temporary (notification bar, etc.)');
      _wasInactive = true;
    } else if (state == AppLifecycleState.resumed) {
      // App is active again
      print('App resumed');
      print(
          'Resume flags: _wasDetached=$_wasDetached, _wasPaused=$_wasPaused, _wasInactive=$_wasInactive');
      _isAppInBackground = false;

      // Check if we were coming from paused or detached state
      final wasPausedOrDetached = _wasDetached || _wasPaused;

      if (_wasInactive && !wasPausedOrDetached) {
        // Coming from inactive ONLY (notification bar) - don't require login
        print('Resumed from inactive only - no login required');
        _wasInactive = false;
        _disableScreenshotProtection();
        setState(() {}); // Update UI to hide blur overlay
      } else if (wasPausedOrDetached) {
        // App was minimized or closed - require login immediately
        print('Resumed from paused/detached - requiring login');
        final wasPaused = _wasPaused;
        _wasDetached = false;
        _wasPaused = false;
        _wasInactive = false;
        _disableScreenshotProtection();

        // CRITICAL: Navigate to login screen IMMEDIATELY in the next frame
        // This prevents the home screen from flashing before navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print(
                'Navigating to login screen immediately (post-frame callback)');
            _forceNavigateToLoginImmediate();
          }
        });

        setState(() {}); // Update UI to hide blur overlay

        // Do logout in background after navigation has started
        // This ensures navigation happens first, preventing home screen flash
        Future.microtask(() async {
          print(
              'App resumed from ${wasPaused ? "paused" : "detached"} - forcing logout in background');
          // Force logout multiple times to ensure it completes
          await AuthService.logout();
          // Verify logout completed - retry if needed
          int retryCount = 0;
          while (retryCount < 3) {
            final isLoggedIn = await AuthService.isLoggedIn();
            print(
                'Logout check attempt ${retryCount + 1}: isLoggedIn = $isLoggedIn');
            if (!isLoggedIn) {
              print('Logout successful after ${retryCount + 1} attempt(s)');
              break; // Logout successful
            }
            // If still logged in, force logout again
            print('User still logged in, retrying logout...');
            await AuthService.logout();
            await Future.delayed(const Duration(milliseconds: 50));
            retryCount++;
          }
        });
      } else {
        // App resumed normally (not from inactive, paused, or detached)
        print('App resumed normally - no action needed');
        _wasInactive = false;
        _disableScreenshotProtection();
        setState(() {}); // Update UI to hide blur overlay
      }
    }
  }

  // Immediate navigation - called from post-frame callback for instant navigation
  void _forceNavigateToLoginImmediate() {
    print('_forceNavigateToLoginImmediate called');
    if (!mounted) {
      print('Widget not mounted, cannot navigate');
      return;
    }

    if (_navigatorKey.currentState == null) {
      print('Navigator key state is null, scheduling retry');
      // If navigator isn't ready, schedule for next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _forceNavigateToLoginImmediate();
        }
      });
      return;
    }

    print('Navigating to login screen immediately with disableAutoLogin=true');
    try {
      // Clear navigation stack and go to login screen immediately without animation
      // Disable auto-login to prevent LoginScreen from auto-navigating to home
      // This prevents flashing the home screen and ensures user must login
      _navigatorKey.currentState?.pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(disableAutoLogin: true),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          opaque: true,
        ),
        (route) => false,
      );
      print('Immediate navigation to login screen completed');
    } catch (e) {
      print('Error with immediate navigation: $e');
      // Try alternative navigation method
      try {
        if (mounted && _navigatorKey.currentState != null) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const LoginScreen(disableAutoLogin: true),
            ),
            (route) => false,
          );
          print('Alternative immediate navigation completed');
        }
      } catch (e2) {
        print('Error with alternative immediate navigation: $e2');
        // Last resort: schedule for next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _navigatorKey.currentState != null) {
            try {
              _navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) =>
                      const LoginScreen(disableAutoLogin: true),
                ),
                (route) => false,
              );
            } catch (e3) {
              print('Final navigation attempt failed: $e3');
            }
          }
        });
      }
    }
  }

  Future<void> _logoutOnAppClose() async {
    try {
      // Clear user session when app is closed or minimized
      // Do this immediately and synchronously to ensure it completes before app is killed
      print('Logging out user due to app being minimized/closed...');

      // Force immediate logout - don't wait for async operations if possible
      if (Hive.isBoxOpen('userBox')) {
        final box = Hive.box('userBox');
        // Delete keys immediately
        box.delete('userId');
        box.delete('user');
        // Also clear the box
        box.clear();
        print('User session cleared immediately via direct box access');
      }

      // Also call the service method to ensure consistency
      await AuthService.logout();

      // Verify logout completed
      final isLoggedIn = await AuthService.isLoggedIn();
      if (isLoggedIn) {
        print('Warning: User still logged in after logout, forcing clear...');
        // Force clear again
        if (Hive.isBoxOpen('userBox')) {
          final box = Hive.box('userBox');
          box.delete('userId');
          box.delete('user');
          box.clear();
        }
        await AuthService.logout();
      }
      print('User logged out successfully due to app being minimized/closed');
    } catch (e) {
      print('Error logging out on app close: $e');
      // Try immediate clear as fallback
      try {
        if (Hive.isBoxOpen('userBox')) {
          final box = Hive.box('userBox');
          box.delete('userId');
          box.delete('user');
          box.clear();
        }
      } catch (e2) {
        print('Error on fallback clear: $e2');
      }
    }
  }

  // Enable screenshot protection (blur in app switcher)
  Future<void> _enableScreenshotProtection() async {
    try {
      const platform = MethodChannel('com.budgetapp/security');
      await platform.invokeMethod('enableScreenshotProtection');
    } catch (e) {
      print('Error enabling screenshot protection: $e');
      // Continue even if this fails - not critical
    }
  }

  // Disable screenshot protection when app is active
  Future<void> _disableScreenshotProtection() async {
    try {
      const platform = MethodChannel('com.budgetapp/security');
      await platform.invokeMethod('disableScreenshotProtection');
    } catch (e) {
      print('Error disabling screenshot protection: $e');
      // Continue even if this fails - not critical
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
    // Check if settings box is open before trying to access it
    if (!_settingsBoxReady || !Hive.isBoxOpen('settingsBox')) {
      // Box not open yet - use default light theme
      return MaterialApp(
        title: 'SpendSense',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.light,
        builder: (context, child) {
          // Wrap the app with protection overlay
          return AppProtectionOverlay(
            isInBackground: _isAppInBackground,
            child: child!,
          );
        },
        home: const InitialSplashScreen(),
      );
    }

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
          builder: (context, child) {
            // Wrap the app with protection overlay
            return AppProtectionOverlay(
              isInBackground: _isAppInBackground,
              child: child!,
            );
          },
          home: const InitialSplashScreen(),
        );
      },
    );
  }
}

/// Widget that provides app protection overlay when app is in background
/// This hides the app content when viewed in the app switcher
class AppProtectionOverlay extends StatelessWidget {
  final bool isInBackground;
  final Widget child;

  const AppProtectionOverlay({
    super.key,
    required this.isInBackground,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isInBackground) {
      // App is active - show normal content
      return child;
    }

    // App is in background - show blurred/obscured overlay
    return Stack(
      children: [
        // Blur the actual content
        child,
        // Overlay with blur effect
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'SpendSense',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'App is protected',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Center(
        child: Lottie.asset(
          'splash_screen_animation/splash_screen_animation.json',
          width: 300,
          height: 300,
          fit: BoxFit.contain,
          repeat: true,
        ),
      ),
    );
  }
}
