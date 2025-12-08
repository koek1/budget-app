import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:budget_app/services/auth_service.dart';
import 'package:budget_app/services/biometric_service.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:budget_app/screens/home/home_screen.dart';
import 'package:budget_app/screens/auth/loading_splash_screen.dart';
import 'package:budget_app/utils/helpers.dart';

// Custom page route with fade transition
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
}

class LoginScreen extends StatefulWidget {
  final bool disableAutoLogin;
  
  const LoginScreen({
    super.key,
    this.disableAutoLogin = false,
  });

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _obscurePassword = true;

  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _fadeController;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _textSlide;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeScreen();

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

    // Fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeIn,
      ),
    );

    // Start animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _textController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      _fadeController.forward();
    });
  }

  Future<void> _initializeScreen() async {
    // If auto-login is disabled (e.g., when coming from app resume), skip auto-login check
    if (widget.disableAutoLogin) {
      print('LoginScreen: Auto-login disabled - user must login manually');
      // Just check biometric availability and setup, but don't auto-login
      await _checkBiometricAvailability();
      return;
    }
    
    // Small delay to ensure any pending logout operations complete
    // This prevents race conditions when app resumes from background
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Check if user is already logged in
    final isLoggedIn = await AuthService.isLoggedIn();
    if (isLoggedIn && mounted) {
      // User is already logged in - navigate to home
      final preloadTask = _preloadAppData();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoadingSplashScreen(
            loadingTask: preloadTask,
            destination: const HomeScreen(),
          ),
        ),
      );
      return;
    }

    // Check biometric availability
    await _checkBiometricAvailability();

    // Auto-prompt biometric if enabled (after UI has rendered)
    if (_biometricAvailable && _biometricEnabled && mounted) {
      // Wait for animations to complete, then auto-prompt
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _biometricAvailable && _biometricEnabled) {
          _loginWithBiometric();
        }
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isBiometricEnabled();
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      // Ask user if they want to enable fingerprint login
      if (_biometricAvailable && !_biometricEnabled && user != null) {
        _showBiometricEnableDialog();
      }

      if (mounted) {
        // Preload data in background while showing splash
        final preloadTask = _preloadAppData();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoadingSplashScreen(
              loadingTask: preloadTask,
              destination: const HomeScreen(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Use centralized error message helper
        Helpers.showErrorSnackBar(
          context,
          Helpers.getUserFriendlyErrorMessage(e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithBiometric() async {
    setState(() => _isLoading = true);

    try {
      final user = await BiometricService.loginWithBiometric();
      if (user != null && mounted) {
        // Preload data in background while showing splash
        final preloadTask = _preloadAppData();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoadingSplashScreen(
              loadingTask: preloadTask,
              destination: const HomeScreen(),
            ),
          ),
        );
      } else if (mounted) {
        // Don't show error if user cancelled - just stop loading
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        // Remove "Exception: " prefix if present
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }

        // Don't show error for user cancellation - it's expected behavior
        if (!errorMessage.toLowerCase().contains('cancelled') &&
            !errorMessage.toLowerCase().contains('cancel')) {
          Helpers.showErrorSnackBar(context, errorMessage);
        }
        setState(() => _isLoading = false);
      }
    }
  }

  // Preload app data in background for smoother experience
  Future<void> _preloadAppData() async {
    try {
      // Preload transactions and user data
      await Future.wait([
        LocalStorageService.getTransactions(),
        LocalStorageService.getCurrentUser(),
      ]);
      // Small delay to ensure smooth transition
      await Future.delayed(Duration(milliseconds: 500));
    } catch (e) {
      print('Preload error: $e');
      // Continue anyway - data will load on demand
    }
  }

  void _showBiometricEnableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Enable Fingerprint Login?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Would you like to enable fingerprint authentication for faster login?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await BiometricService.saveCredentialsForBiometric(
                _usernameController.text.trim(),
                _passwordController.text,
              );
              if (mounted) {
                setState(() => _biometricEnabled = true);
              }
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Turquoise/Blue color scheme
    final primaryTurquoise = const Color(0xFF14B8A6); // Turquoise
    final primaryBlue = const Color(0xFF0EA5E9); // Sky Blue
    final accentBlue = const Color(0xFF3B82F6); // Blue

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Color(0xFF0F172A), // Dark blue-gray
                    Color(0xFF1E293B), // Darker blue-gray
                    Color(0xFF0F172A),
                  ]
                : [
                    primaryTurquoise.withOpacity(0.15),
                    primaryBlue.withOpacity(0.1),
                    accentBlue.withOpacity(0.08),
                  ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // Animated Logo and Brand Section
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
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'images/logo.png',
                              width: 80,
                              height: 80,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Animated SpendSense Text
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: Opacity(
                          opacity: _textController.value,
                          child: Column(
                            children: [
                              Text(
                                'SpendSense',
                                style: GoogleFonts.poppins(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  foreground: Paint()
                                    ..shader = LinearGradient(
                                      colors: [
                                        primaryTurquoise,
                                        primaryBlue,
                                        accentBlue
                                      ],
                                    ).createShader(
                                      const Rect.fromLTWH(0, 0, 200, 70),
                                    ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Welcome Back',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign in to continue',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48),

                  // Fade in form elements
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Biometric login button (if available and enabled)
                        if (_biometricAvailable && _biometricEnabled) ...[
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [primaryTurquoise, primaryBlue],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryTurquoise.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isLoading ? null : _loginWithBiometric,
                              icon: const Icon(Icons.fingerprint, size: 24),
                              label: Text(
                                'Login with Biometric',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: isDark
                                      ? Colors.grey[700]
                                      : Colors.grey[300],
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: GoogleFonts.inter(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: isDark
                                      ? Colors.grey[700]
                                      : Colors.grey[300],
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Login Form Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withOpacity(0.3)
                                    : primaryTurquoise.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _usernameController,
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontFamily: GoogleFonts.inter().fontFamily,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  labelStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontFamily: GoogleFonts.inter().fontFamily,
                                  ),
                                  prefixIcon: Icon(Icons.person_outline,
                                      color: primaryTurquoise),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: primaryTurquoise, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? Color(0xFF0F172A)
                                      : Colors.grey[50],
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your username';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontFamily: GoogleFonts.inter().fontFamily,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontFamily: GoogleFonts.inter().fontFamily,
                                  ),
                                  prefixIcon: Icon(Icons.lock_outline,
                                      color: primaryTurquoise),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: primaryTurquoise, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? Color(0xFF0F172A)
                                      : Colors.grey[50],
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 32),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [primaryTurquoise, primaryBlue],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryTurquoise.withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: _isLoading
                                    ? Container(
                                        height: 56,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              primaryTurquoise,
                                              primaryBlue
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 18),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          'Login',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Don\'t have an account? ',
                              style: GoogleFonts.inter(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  FadePageRoute(
                                    page: const RegisterScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                              ),
                              child: Text(
                                'Sign up',
                                style: GoogleFonts.inter(
                                  color: primaryTurquoise,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Add bottom padding to prevent white bar
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _fadeController;
  late Animation<double> _logoScale;
  late Animation<double> _textSlide;
  late Animation<double> _fadeAnimation;

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

    // Fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );

    _textSlide = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeIn,
      ),
    );

    // Start animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _textController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.register(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      // Show success message and navigate back to login
      if (mounted) {
        Helpers.showSuccessSnackBar(
          context,
          'Account created successfully! Please login.',
        );
        Navigator.pop(context); // Go back to login screen
      }
    } catch (e) {
      if (mounted) {
        // Use centralized error message helper
        Helpers.showErrorSnackBar(
          context,
          Helpers.getUserFriendlyErrorMessage(e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Turquoise/Blue color scheme
    final primaryTurquoise = const Color(0xFF14B8A6); // Turquoise
    final primaryBlue = const Color(0xFF0EA5E9); // Sky Blue
    final accentBlue = const Color(0xFF3B82F6); // Blue

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Account',
          style: GoogleFonts.inter(
            color: theme.textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Color(0xFF0F172A), // Dark blue-gray
                    Color(0xFF1E293B), // Darker blue-gray
                    Color(0xFF0F172A),
                  ]
                : [
                    primaryTurquoise.withOpacity(0.15),
                    primaryBlue.withOpacity(0.1),
                    accentBlue.withOpacity(0.08),
                  ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // Animated Logo Section
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScale.value,
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
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'images/logo.png',
                            width: 80,
                            height: 80,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Animated Text
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: Opacity(
                          opacity: _textController.value,
                          child: Column(
                            children: [
                              Text(
                                'Create Account',
                                style: GoogleFonts.poppins(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  foreground: Paint()
                                    ..shader = LinearGradient(
                                      colors: [
                                        primaryTurquoise,
                                        primaryBlue,
                                        accentBlue
                                      ],
                                    ).createShader(
                                      const Rect.fromLTWH(0, 0, 200, 70),
                                    ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Sign up to start managing your budget',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48),

                  // Fade in form elements
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.3)
                                : primaryTurquoise.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _usernameController,
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontFamily: GoogleFonts.inter().fontFamily,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontFamily: GoogleFonts.inter().fontFamily,
                              ),
                              prefixIcon: Icon(Icons.person_outline,
                                  color: primaryTurquoise),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: primaryTurquoise, width: 2),
                              ),
                              filled: true,
                              fillColor:
                                  isDark ? Color(0xFF0F172A) : Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              helperText: 'At least 3 characters',
                              helperStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                                fontFamily: GoogleFonts.inter().fontFamily,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a username';
                              }
                              if (value.length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontFamily: GoogleFonts.inter().fontFamily,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontFamily: GoogleFonts.inter().fontFamily,
                              ),
                              prefixIcon: Icon(Icons.lock_outline,
                                  color: primaryTurquoise),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: primaryTurquoise, width: 2),
                              ),
                              filled: true,
                              fillColor:
                                  isDark ? Color(0xFF0F172A) : Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              helperText: 'At least 6 characters',
                              helperStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                                fontFamily: GoogleFonts.inter().fontFamily,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [primaryTurquoise, primaryBlue],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryTurquoise.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: _isLoading
                                ? Container(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [primaryTurquoise, primaryBlue],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _register,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      'Sign Up',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                        child: Text(
                          'Sign in',
                          style: GoogleFonts.inter(
                            color: primaryTurquoise,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Add bottom padding to prevent white bar
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
