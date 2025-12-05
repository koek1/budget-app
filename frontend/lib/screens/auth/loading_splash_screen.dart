import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

class LoadingSplashScreen extends StatefulWidget {
  final Future<void> loadingTask;
  final Widget destination;

  const LoadingSplashScreen({
    super.key,
    required this.loadingTask,
    required this.destination,
  });

  @override
  _LoadingSplashScreenState createState() => _LoadingSplashScreenState();
}

class _LoadingSplashScreenState extends State<LoadingSplashScreen> {
  @override
  void initState() {
    super.initState();
    // Start loading and navigate when done
    _startLoading();
  }

  Future<void> _startLoading() async {
    try {
      // Wait for loading task to complete
      await widget.loadingTask;
      
      // Small delay for smooth transition
      await Future.delayed(Duration(milliseconds: 300));
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => widget.destination,
            transitionDuration: Duration(milliseconds: 400),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      }
    } catch (e) {
      print('Loading error: $e');
      // Navigate anyway if there's an error
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => widget.destination),
        );
      }
    }
  }


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

