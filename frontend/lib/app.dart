import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

class MyApp extends StatelessWidget {
    const MyApp({super.key});

    @override
    Widget build(BuildContext context) {
        return MaterialApp(
            title: 'SpendSense',
            theme: ThemeData(
                primarySwatch: Colors.blue,
                visualDensity: VisualDensity.adaptivePlatformDensity,
                useMaterial3: true,
            ),
            home: FutureBuilder(
                future: _checkLoginStatus(),
                builder: (context, snapshot) {
                    if (snapchot.connectionStatus == ConnectionStatus.waiting) {
                        return const SplashScreen();
                    }
                    return snapshot.data == true ? const HomeScreen() : const LoginScreen();
                },
            ),
        );
    }

    Future <bool> _checkLoginStatus() async {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString('token') != null;
    }
}

class SplashScreen extends StatelessWidget {
    const SplashScreen({super.key});

    @override
    Widget build (BuildContext context) {
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
