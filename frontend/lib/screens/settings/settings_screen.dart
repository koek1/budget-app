import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:budget_app/services/biometric_service.dart';
import 'package:budget_app/services/settings_service.dart';
import 'package:budget_app/services/auth_service.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:budget_app/screens/auth/login_screen.dart';
import 'package:budget_app/screens/settings/manage_criteria_screen.dart';
import 'package:budget_app/utils/helpers.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _isLoading = true;
  String _selectedCurrency = SettingsService.defaultCurrency;
  String _themeMode = SettingsService.defaultThemeMode;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await BiometricService.isBiometricEnabled();
    final available = await BiometricService.isAvailable();
    
    setState(() {
      _biometricEnabled = enabled;
      _biometricAvailable = available;
      _selectedCurrency = SettingsService.getCurrency();
      _themeMode = SettingsService.getThemeMode();
      _isLoading = false;
    });
  }

  Future<void> _selectCurrency() async {
    final theme = Theme.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Select Currency',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: SettingsService.availableCurrencies.map((currency) {
              final isSelected = currency['code'] == _selectedCurrency;
              return InkWell(
                onTap: () {
                  Navigator.pop(context, currency['code']);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Color(0xFF14B8A6).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Color(0xFF14B8A6)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(0xFF14B8A6).withOpacity(0.2)
                              : theme.brightness == Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            currency['symbol']!,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Color(0xFF14B8A6)
                                  : theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          currency['name']!,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? Color(0xFF14B8A6)
                                : theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Color(0xFF14B8A6),
                          size: 24,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );

    if (result != null) {
      await SettingsService.setCurrency(result);
      setState(() {
        _selectedCurrency = result;
      });
      if (mounted) {
        Helpers.showSuccessSnackBar(context, 'Currency updated to ${result}');
      }
    }
  }

  Future<void> _toggleThemeMode() async {
    final newMode = _themeMode == 'light' ? 'dark' : 'light';
    await SettingsService.setThemeMode(newMode);
    setState(() {
      _themeMode = newMode;
    });
      if (mounted) {
        Helpers.showSuccessSnackBar(context, 'Theme changed to ${newMode} mode');
      }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Enable biometric - just save credentials, don't authenticate yet
      // Authentication will happen when user actually tries to login with biometric
      final currentUser = await AuthService.getCurrentUser();
      
      if (currentUser != null) {
        // Get the user's password from the usersBox
        final usersBox = Hive.box('usersBox');
        final users = usersBox.values.toList();
        final userData = users.firstWhere(
          (u) {
            final userMap = u as Map;
            return userMap['name']?.toString().toLowerCase() == currentUser.name.toLowerCase();
          },
          orElse: () => null,
        );
        
        if (userData != null) {
          final userMap = Map<String, dynamic>.from(userData as Map);
          final password = userMap['password']?.toString();
          
          if (password != null) {
            // Save credentials for biometric login
            await BiometricService.saveCredentialsForBiometric(
              currentUser.name,
              password,
            );
            setState(() {
              _biometricEnabled = true;
            });
            if (mounted) {
              Helpers.showSuccessSnackBar(context, 'Fingerprint login enabled');
            }
          } else {
            if (mounted) {
              Helpers.showErrorSnackBar(
                context,
                'Unable to enable biometric login. Please login again.',
              );
              setState(() {
                _biometricEnabled = false;
              });
            }
          }
        } else {
          if (mounted) {
            Helpers.showErrorSnackBar(
              context,
              'Unable to enable biometric login. Please login again.',
            );
            setState(() {
              _biometricEnabled = false;
            });
          }
        }
      } else {
        if (mounted) {
          Helpers.showErrorSnackBar(
            context,
            'Please login first to enable biometric login',
          );
          setState(() {
            _biometricEnabled = false;
          });
        }
      }
    } else {
      // Disable biometric
      await BiometricService.disableBiometric();
      setState(() {
        _biometricEnabled = false;
      });
      if (mounted) {
        Helpers.showInfoSnackBar(context, 'Fingerprint login disabled');
      }
    }
  }

  Future<void> _showResetDataDialog() async {
    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Reset App Data',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will delete all users, transactions, and sessions. This action cannot be undone.\n\nYour settings (currency, theme) will be preserved.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Reset',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        // Logout first
        await AuthService.logout();
        
        // Clear all data
        await LocalStorageService.clearAllData();
        
        // Disable biometric
        await BiometricService.disableBiometric();
        
        if (mounted) {
          Helpers.showSuccessSnackBar(context, 'App data reset successfully');
          
          // Navigate to login screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = e.toString();
          if (errorMessage.startsWith('Exception: ')) {
            errorMessage = errorMessage.substring(11);
          }
          Helpers.showErrorSnackBar(context, 'Error resetting data: $errorMessage');
        }
      }
    }
  }


  Widget _buildSettingsCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Color(0xFF1E293B)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final itemColor = iconColor ?? Color(0xFF14B8A6);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: itemColor.withOpacity(0.15),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (onTap != null && trailing == null)
              Icon(
                Icons.chevron_right_rounded,
                color: theme.textTheme.bodyMedium?.color,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Color(0xFF14B8A6),
              ),
            )
          : Builder(
              builder: (context) {
                if (!Hive.isBoxOpen('settingsBox')) {
                  return Center(
                    child: Text(
                      'Settings box not initialized',
                      style: GoogleFonts.inter(),
                    ),
                  );
                }
                
                return ValueListenableBuilder(
                  valueListenable: Hive.box('settingsBox').listenable(),
                  builder: (context, box, _) {
                    // Refresh settings when box changes
                    _selectedCurrency = SettingsService.getCurrency();
                    _themeMode = SettingsService.getThemeMode();
                    
                    return ListView(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      children: [
                        // Appearance Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Appearance',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        _buildSettingsCard(
                          child: Column(
                            children: [
                              _buildSettingsItem(
                                icon: Icons.currency_exchange_rounded,
                                title: 'Currency',
                                subtitle: SettingsService.availableCurrencies
                                    .firstWhere((c) => c['code'] == _selectedCurrency)['name']!,
                                onTap: _selectCurrency,
                              ),
                              Divider(height: 32),
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF14B8A6).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _themeMode == 'dark'
                                          ? Icons.dark_mode_rounded
                                          : Icons.light_mode_rounded,
                                      color: Color(0xFF14B8A6),
                                      size: 24,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Dark Mode',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: theme.textTheme.bodyLarge?.color,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          _themeMode == 'dark'
                                              ? 'Dark theme enabled'
                                              : 'Light theme enabled',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: theme.textTheme.bodyMedium?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _themeMode == 'dark',
                                    onChanged: (value) => _toggleThemeMode(),
                                    activeColor: Color(0xFF14B8A6),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Security Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Security',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        _buildSettingsCard(
                          child: !_biometricAvailable
                              ? _buildSettingsItem(
                                  icon: Icons.info_outline_rounded,
                                  title: 'Fingerprint Authentication',
                                  subtitle: 'Fingerprint not available on this device',
                                  iconColor: Colors.grey,
                                )
                              : Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Color(0xFF14B8A6).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.fingerprint_rounded,
                                            color: Color(0xFF14B8A6),
                                            size: 24,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Fingerprint Login',
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.textTheme.bodyLarge?.color,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Use fingerprint to login',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: theme.textTheme.bodyMedium?.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          value: _biometricEnabled,
                                          onChanged: _toggleBiometric,
                                          activeColor: Color(0xFF14B8A6),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                        
                        // Categories Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Categories',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        _buildSettingsCard(
                          child: _buildSettingsItem(
                            icon: Icons.category_rounded,
                            title: 'Manage Categories',
                            subtitle: 'Add, edit, or delete custom income and expense categories',
                            iconColor: Color(0xFF14B8A6),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ManageCriteriaScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        // About Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'About',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        _buildSettingsCard(
                          child: Column(
                            children: [
                              _buildSettingsItem(
                                icon: Icons.info_rounded,
                                title: 'App Version',
                                subtitle: '1.0.0',
                                iconColor: Colors.grey,
                              ),
                              Divider(height: 32),
                              _buildSettingsItem(
                                icon: Icons.refresh_rounded,
                                title: 'Reset App Data',
                                subtitle: 'Clear all users, transactions, and sessions',
                                iconColor: Colors.orange,
                                onTap: _showResetDataDialog,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

