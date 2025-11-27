import 'package:flutter/material.dart';
import 'package:budget_app/screens/home/dashboard_screen.dart';
import 'package:budget_app/screens/transactions/transactions_screen.dart';
import 'package:budget_app/screens/home/add_transaction_screen.dart';
import 'package:budget_app/services/auth_service.dart';
import 'package:budget_app/screens/export/export_screen.dart';
import 'package:budget_app/screens/auth/login_screen.dart';
import 'package:budget_app/screens/settings/settings_screen.dart';
import 'package:budget_app/screens/stats/stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Widget> get _screens => [
    DashboardScreen(onMenuTap: () => _scaffoldKey.currentState?.openDrawer()),
    TransactionsScreen(onMenuTap: () => _scaffoldKey.currentState?.openDrawer()),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _screens[_currentIndex],
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddTransactionScreen(),
                  ),
                );
                // Force refresh when returning from add transaction
                if (result == true && mounted) {
                  setState(() {});
                }
              },
              backgroundColor: Color(0xFF2563EB),
              child: Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() {
            _currentIndex = index;
          }),
          selectedItemColor: Color(0xFF2563EB),
          unselectedItemColor: theme.brightness == Brightness.dark 
              ? Colors.grey[400] 
              : Colors.grey,
          backgroundColor: theme.bottomNavigationBarTheme.backgroundColor ?? 
              (theme.brightness == Brightness.dark 
                  ? theme.cardColor 
                  : Colors.white),
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Transactions',
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF2563EB),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Color(0xFF2563EB), size: 30),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'SpendSense',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.bar_chart, color: Colors.grey[700]),
              title: Text('Statistics'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StatsScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings, color: Colors.grey[700]),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.assessment, color: Colors.grey[700]),
              title: Text('Export'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ExportScreen()),
                );
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await AuthService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }
}
