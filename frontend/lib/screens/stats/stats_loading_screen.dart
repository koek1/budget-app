import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class StatsLoadingScreen extends StatefulWidget {
  final Future<Map<String, dynamic>> loadingTask;

  const StatsLoadingScreen({
    super.key,
    required this.loadingTask,
  });

  @override
  _StatsLoadingScreenState createState() => _StatsLoadingScreenState();
}

class _StatsLoadingScreenState extends State<StatsLoadingScreen> {
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

