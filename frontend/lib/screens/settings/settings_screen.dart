import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:budget_app/services/biometric_service.dart';
import 'package:budget_app/services/settings_service.dart';
import 'package:budget_app/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _fingerprintOnly = false;
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
    final fingerprintOnly = await BiometricService.isFingerprintOnly();
    
    setState(() {
      _biometricEnabled = enabled;
      _biometricAvailable = available;
      _fingerprintOnly = fingerprintOnly;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Currency updated to ${result}')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Theme changed to ${newMode} mode')),
      );
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Biometric login enabled')),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to enable biometric login. Please login again.'),
                ),
              );
              setState(() {
                _biometricEnabled = false;
              });
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to enable biometric login. Please login again.'),
              ),
            );
            setState(() {
              _biometricEnabled = false;
            });
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login first to enable biometric login'),
            ),
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
        _fingerprintOnly = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric login disabled')),
        );
      }
    }
  }

  Future<void> _toggleFingerprintOnly(bool value) async {
    if (!_biometricEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable biometric login first')),
        );
      }
      return;
    }

    if (value) {
      // Check if fingerprint is available
      final availableBiometrics = await BiometricService.getAvailableBiometrics();
      if (!availableBiometrics.contains(BiometricType.fingerprint)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fingerprint is not available on this device'),
            ),
          );
        }
        return;
      }
    }

    await BiometricService.setFingerprintOnly(value);
    setState(() {
      _fingerprintOnly = value;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value 
            ? 'Fingerprint-only mode enabled' 
            : 'All biometric types enabled'),
        ),
      );
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
                                  title: 'Biometric Authentication',
                                  subtitle: 'Not available on this device',
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
                                                'Biometric Login',
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.textTheme.bodyLarge?.color,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Use fingerprint or Face ID to login',
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
                                    if (_biometricEnabled) ...[
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
                                              Icons.touch_app_rounded,
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
                                                  'Fingerprint Only',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.textTheme.bodyLarge?.color,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Restrict to fingerprint authentication only',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    color: theme.textTheme.bodyMedium?.color,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Switch(
                                            value: _fingerprintOnly,
                                            onChanged: _toggleFingerprintOnly,
                                            activeColor: Color(0xFF14B8A6),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
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
                          child: _buildSettingsItem(
                            icon: Icons.info_rounded,
                            title: 'App Version',
                            subtitle: '1.0.0',
                            iconColor: Colors.grey,
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

