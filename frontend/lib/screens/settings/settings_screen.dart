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
import 'dart:math' as math;

class SettingsScreen extends StatefulWidget {
  final bool highlightBudgetSetting;
  
  const SettingsScreen({super.key, this.highlightBudgetSetting = false});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _isLoading = true;
  String _selectedCurrency = SettingsService.defaultCurrency;
  String _themeMode = SettingsService.defaultThemeMode;
  double _startingBalance = SettingsService.defaultStartingBalance;
  bool _highlightBudgetSetting = false;
  final GlobalKey _budgetSettingKey = GlobalKey();
  late AnimationController _highlightAnimationController;
  late AnimationController _fadeOutAnimationController;
  late Animation<double> _highlightAnimation;
  late Animation<double> _fadeOutAnimation;

  @override
  void initState() {
    super.initState();
    _highlightBudgetSetting = widget.highlightBudgetSetting;
    
    // Initialize animation controllers if highlighting is needed
    if (_highlightBudgetSetting) {
      _highlightAnimationController = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1000),
      );
      _highlightAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
        CurvedAnimation(
          parent: _highlightAnimationController,
          curve: Curves.easeInOut,
        ),
      );
      
      // Fade-out animation controller for smooth transition
      _fadeOutAnimationController = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 800),
      );
      _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _fadeOutAnimationController,
          curve: Curves.easeOut,
        ),
      );
      
      _highlightAnimationController.repeat(reverse: true);
    }
    
    _loadSettings();
    
    // If we need to highlight, scroll to the budget setting after a short delay
    if (_highlightBudgetSetting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBudgetSetting();
      });
      
      // Start fade-out after 3 seconds, then remove highlight
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          _highlightAnimationController.stop();
          // Start fade-out animation
          _fadeOutAnimationController.forward().then((_) {
            if (mounted) {
              setState(() {
                _highlightBudgetSetting = false;
              });
            }
          });
        }
      });
    }
  }
  
  @override
  void dispose() {
    if (widget.highlightBudgetSetting) {
      _highlightAnimationController.dispose();
      _fadeOutAnimationController.dispose();
    }
    super.dispose();
  }
  
  void _scrollToBudgetSetting() {
    if (_budgetSettingKey.currentContext != null) {
      Scrollable.ensureVisible(
        _budgetSettingKey.currentContext!,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadSettings() async {
    try {
      // Load settings - don't timeout biometric check as it may need more time
      final enabled = await BiometricService.isBiometricEnabled()
          .timeout(Duration(seconds: 5), onTimeout: () => false);

      // Check availability with longer timeout and retry
      bool available = false;
      try {
        available = await BiometricService.isAvailable()
            .timeout(Duration(seconds: 8), onTimeout: () {
          // If timeout, try one more time
          print('Biometric check timed out, retrying...');
          return false;
        });

        // If first check failed, try once more
        if (!available) {
          print('First biometric check failed, retrying...');
          await Future.delayed(Duration(milliseconds: 500));
          available = await BiometricService.isAvailable()
              .timeout(Duration(seconds: 5), onTimeout: () => false);
        }
      } catch (e) {
        print('Error checking biometric availability: $e');
        available = false;
      }

      if (mounted) {
        setState(() {
          _biometricEnabled = enabled;
          _biometricAvailable = available;
          _selectedCurrency = SettingsService.getCurrency();
          _themeMode = SettingsService.getThemeMode();
          _startingBalance = SettingsService.getStartingBalance();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      // Set defaults if loading fails, but try to check biometric one more time
      if (mounted) {
        // Try one final biometric check
        bool available = false;
        try {
          available = await BiometricService.isAvailable()
              .timeout(Duration(seconds: 3), onTimeout: () => false);
        } catch (e2) {
          print('Final biometric check failed: $e2');
        }

        setState(() {
          _biometricEnabled = false;
          _biometricAvailable = available;
          _selectedCurrency = SettingsService.getCurrency();
          _themeMode = SettingsService.getThemeMode();
          _startingBalance = SettingsService.getStartingBalance();
          _isLoading = false;
        });
      }
    }
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
                      color:
                          isSelected ? Color(0xFF14B8A6) : Colors.transparent,
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
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
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

  Future<void> _editStartingBalance() async {
    final theme = Theme.of(context);
    final currencySymbol = SettingsService.getCurrencySymbol();
    final controller = TextEditingController(
      text: _startingBalance.toStringAsFixed(2),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Set Starting Balance',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your starting balance. This will be used as the baseline to determine if you are saving or losing money.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Starting Balance',
                prefixText: currencySymbol,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF14B8A6), width: 2),
                ),
              ),
              style: GoogleFonts.inter(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null) {
                Navigator.pop(context, value);
              } else {
                Helpers.showErrorSnackBar(
                  context,
                  'Please enter a valid number',
                );
              }
            },
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                color: Color(0xFF14B8A6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      final previousBalance = _startingBalance;
      await SettingsService.setStartingBalance(result);
      setState(() {
        _startingBalance = result;
      });
      if (mounted) {
        Helpers.showSuccessSnackBar(
          context,
          'Starting balance updated to ${currencySymbol}${result.toStringAsFixed(2)}',
        );
        
        // If balance was changed from default (0.0) and we came from notification, navigate back
        if (widget.highlightBudgetSetting && previousBalance == 0.0 && result != 0.0) {
          // Wait a moment for the snackbar to show, then navigate back
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
      }
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
            return userMap['name']?.toString().toLowerCase() ==
                currentUser.name.toLowerCase();
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
          Helpers.showErrorSnackBar(
              context, 'Error resetting data: $errorMessage');
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
                    _startingBalance = SettingsService.getStartingBalance();

                    return ListView(
                      padding: EdgeInsets.only(top: 16, bottom: 24, left: 0, right: 0),
                      children: [
                        // Appearance Section
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                    .firstWhere((c) =>
                                        c['code'] ==
                                        _selectedCurrency)['name']!,
                                onTap: _selectCurrency,
                              ),
                              Divider(height: 32),
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color:
                                          Color(0xFF14B8A6).withOpacity(0.15),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Dark Mode',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: theme
                                                .textTheme.bodyLarge?.color,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          _themeMode == 'dark'
                                              ? 'Dark theme enabled'
                                              : 'Light theme enabled',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: theme
                                                .textTheme.bodyMedium?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _themeMode == 'dark',
                                    onChanged: (value) => _toggleThemeMode(),
                                    activeThumbColor: Color(0xFF14B8A6),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Budget Section
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Budget',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        Container(
                          key: _budgetSettingKey,
                          child: _highlightBudgetSetting
                              ? AnimatedBuilder(
                                  animation: Listenable.merge([_highlightAnimation, _fadeOutAnimation]),
                                  builder: (context, child) {
                                    // Combine pulsing and fade-out animations
                                    final pulseValue = _highlightAnimation.value;
                                    final fadeValue = _fadeOutAnimation.value;
                                    final combinedOpacity = pulseValue * fadeValue;
                                    
                                    return Container(
                                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      padding: EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(27),
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF14B8A6).withOpacity(combinedOpacity),
                                            Color(0xFF14B8A6).withOpacity(combinedOpacity * 0.5),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0xFF14B8A6).withOpacity(combinedOpacity * 0.8),
                                            blurRadius: 25 * fadeValue,
                                            spreadRadius: 3 * fadeValue,
                                          ),
                                        ],
                                      ),
                                      child: _buildSettingsCard(
                                        child: _buildSettingsItem(
                                          icon: Icons.account_balance_wallet_rounded,
                                          title: 'Starting Balance',
                                          subtitle: '${SettingsService.getCurrencySymbol()}${_startingBalance.toStringAsFixed(2)}',
                                          onTap: _editStartingBalance,
                                          iconColor: Color(0xFF14B8A6),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : _buildSettingsCard(
                                  child: _buildSettingsItem(
                                    icon: Icons.account_balance_wallet_rounded,
                                    title: 'Starting Balance',
                                    subtitle: '${SettingsService.getCurrencySymbol()}${_startingBalance.toStringAsFixed(2)}',
                                    onTap: _editStartingBalance,
                                    iconColor: Color(0xFF14B8A6),
                                  ),
                                ),
                        ),

                        // Security Section
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                  subtitle:
                                      'Fingerprint not available on this device',
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
                                            color: Color(0xFF14B8A6)
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(12),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Fingerprint Login',
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.textTheme
                                                      .bodyLarge?.color,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Use fingerprint to login',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: theme.textTheme
                                                      .bodyMedium?.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          value: _biometricEnabled,
                                          onChanged: _toggleBiometric,
                                          activeThumbColor: Color(0xFF14B8A6),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),

                        // Categories Section
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            subtitle:
                                'Add, edit, or delete custom income and expense categories',
                            iconColor: Color(0xFF14B8A6),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ManageCriteriaScreen(),
                                ),
                              );
                            },
                          ),
                        ),

                        // About Section
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                subtitle:
                                    'Clear all users, transactions, and sessions',
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
