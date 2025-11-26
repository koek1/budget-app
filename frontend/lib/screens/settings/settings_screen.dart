import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:budget_app/services/biometric_service.dart';

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
      _isLoading = false;
    });
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
          : ListView(
              children: [
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
            ),
    );
  }
}

