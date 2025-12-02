import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatsLoadingScreen extends StatefulWidget {
  final Future<Map<String, dynamic>> loadingTask;

  const StatsLoadingScreen({
    super.key,
    required this.loadingTask,
  });

  @override
  _StatsLoadingScreenState createState() => _StatsLoadingScreenState();
}

class _StatsLoadingScreenState extends State<StatsLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTurquoise = const Color(0xFF14B8A6);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Chart Icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _pulseAnimation.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: primaryTurquoise.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryTurquoise.withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.bar_chart_rounded,
                          size: 50,
                          color: primaryTurquoise,
                        ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 32),
              
              // Loading text with pulse
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _pulseAnimation.value,
                    child: Text(
                      'Loading Statistics...',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 16),
              
              // Loading indicator
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryTurquoise),
                ),
              ),
              SizedBox(height: 24),
              
              // Subtitle
              Text(
                'Preparing your financial insights',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

