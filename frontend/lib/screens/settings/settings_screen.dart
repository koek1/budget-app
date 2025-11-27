import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:budget_app/services/biometric_service.dart';
import 'package:budget_app/services/settings_service.dart';

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
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Currency'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: SettingsService.availableCurrencies.map((currency) {
              return ListTile(
                title: Text(currency['name']!),
                leading: Text(
                  currency['symbol']!,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context, currency['code']);
                },
                selected: currency['code'] == _selectedCurrency,
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
      // Enable biometric - need to authenticate first
      final authenticated = await BiometricService.authenticate();
      if (authenticated) {
        // Get current user credentials to save
        final credentials = await BiometricService.getSavedCredentials();
        if (credentials['email'] != null && credentials['password'] != null) {
          await BiometricService.saveCredentialsForBiometric(
            credentials['email']!,
            credentials['password']!,
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
                content: Text('Please login with password first to enable biometric login'),
              ),
            );
            setState(() {
              _biometricEnabled = false;
            });
          }
        }
      } else {
        setState(() {
          _biometricEnabled = false;
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Builder(
              builder: (context) {
                if (!Hive.isBoxOpen('settingsBox')) {
                  return Center(
                    child: Text('Settings box not initialized'),
                  );
                }
                
                return ValueListenableBuilder(
                  valueListenable: Hive.box('settingsBox').listenable(),
                  builder: (context, box, _) {
                    // Refresh settings when box changes
                    _selectedCurrency = SettingsService.getCurrency();
                    _themeMode = SettingsService.getThemeMode();
                    
                    return ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Appearance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.currency_exchange),
                      title: const Text('Currency'),
                      subtitle: Text(
                        SettingsService.availableCurrencies
                            .firstWhere((c) => c['code'] == _selectedCurrency)['name']!,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _selectCurrency,
                    ),
                    SwitchListTile(
                      secondary: Icon(
                        _themeMode == 'dark' ? Icons.dark_mode : Icons.light_mode,
                      ),
                      title: const Text('Dark Mode'),
                      subtitle: Text(
                        _themeMode == 'dark' 
                            ? 'Dark theme enabled' 
                            : 'Light theme enabled',
                      ),
                      value: _themeMode == 'dark',
                      onChanged: (value) => _toggleThemeMode(),
                    ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Security',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!_biometricAvailable)
                      const ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Biometric Authentication'),
                        subtitle: Text('Not available on this device'),
                      ),
                    if (_biometricAvailable) ...[
                      SwitchListTile(
                        secondary: const Icon(Icons.fingerprint),
                        title: const Text('Biometric Login'),
                        subtitle: const Text('Use fingerprint or Face ID to login'),
                        value: _biometricEnabled,
                        onChanged: _toggleBiometric,
                      ),
                      if (_biometricEnabled)
                        SwitchListTile(
                          secondary: const Icon(Icons.touch_app),
                          title: const Text('Fingerprint Only'),
                          subtitle: const Text('Restrict to fingerprint authentication only'),
                          value: _fingerprintOnly,
                          onChanged: _toggleFingerprintOnly,
                        ),
                    ],
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'About',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const ListTile(
                      leading: Icon(Icons.info),
                      title: Text('App Version'),
                      subtitle: Text('1.0.0'),
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

