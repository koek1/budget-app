import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        DashboardScreen(
            onMenuTap: () => _scaffoldKey.currentState?.openDrawer()),
        TransactionsScreen(
            onMenuTap: () => _scaffoldKey.currentState?.openDrawer()),
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
              backgroundColor: Color(0xFF14B8A6),
              child: Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Color(0xFF1E293B).withOpacity(0.95)
                  : Colors.white.withOpacity(0.95),
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() {
                _currentIndex = index;
              }),
              selectedItemColor: Color(0xFF14B8A6),
              unselectedItemColor: theme.brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey,
              backgroundColor: Colors.transparent,
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
        ),
      ),
      drawer: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Color(0xFF1E293B).withOpacity(0.3)
                  : Colors.white.withOpacity(0.3),
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Header Section with Frosted Glass
                ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 20,
                        bottom: 40,
                        left: 24,
                        right: 24,
                      ),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? Color(0xFF14B8A6).withOpacity(0.2)
                            : Color(0xFF14B8A6).withOpacity(0.15),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Navigator',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () => Navigator.pop(context),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Menu Items Section with Less Blur
                ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? Color(0xFF1E293B).withOpacity(0.2)
                            : Colors.white.withOpacity(0.2),
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: 8),
                          _buildDrawerItem(
                            context,
                            icon: Icons.bar_chart_rounded,
                            title: 'Statistics',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const StatsScreen()),
                              );
                            },
                          ),
                          SizedBox(height: 12),
                          _buildDrawerItem(
                            context,
                            icon: Icons.settings_rounded,
                            title: 'Settings',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const SettingsScreen()),
                              );
                            },
                          ),
                          SizedBox(height: 12),
                          _buildDrawerItem(
                            context,
                            icon: Icons.assessment_rounded,
                            title: 'Export',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ExportScreen()),
                              );
                            },
                          ),
                          SizedBox(height: 24),
                          _buildDrawerItem(
                            context,
                            icon: Icons.logout_rounded,
                            title: 'Logout',
                            color: Colors.red,
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTurquoise = const Color(0xFF14B8A6);
    final itemColor = color ?? (isDark ? Colors.white : Colors.black87);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : primaryTurquoise.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (color ?? primaryTurquoise).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: itemColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      color: itemColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: itemColor.withOpacity(0.5),
                  size: 20,
                ),
              ],
            ),
          ),
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
