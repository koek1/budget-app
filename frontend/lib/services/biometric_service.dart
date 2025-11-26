import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:budget_app/services/auth_service.dart';
import 'package:budget_app/models/user.dart';

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Check if biometric authentication is available
  static Future<bool> isAvailable() async {
    try {
      final bool canAuthenticate = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuthenticate || isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  // Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Authenticate using biometrics
  static Future<bool> authenticate() async {
    try {
      // Check if fingerprint-only mode is enabled
      final fingerprintOnly = await isFingerprintOnly();
      
      // Get available biometrics
      final availableBiometrics = await getAvailableBiometrics();
      
      // If fingerprint-only is enabled, check if fingerprint is available
      if (fingerprintOnly) {
        if (!availableBiometrics.contains(BiometricType.fingerprint)) {
          throw PlatformException(
            code: 'FINGERPRINT_NOT_AVAILABLE',
            message: 'Fingerprint authentication is not available on this device',
          );
        }
        // If fingerprint-only is enabled, we still use biometricOnly: true
        // The system will use fingerprint if it's the only available biometric
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access SpendSense',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Biometric authentication error: $e');
      return false;
    }
  }

  // Save user credentials securely for biometric login
  static Future<void> saveCredentialsForBiometric(String email, String password) async {
    await _secureStorage.write(key: 'biometric_email', value: email);
    await _secureStorage.write(key: 'biometric_password', value: password);
    await _secureStorage.write(key: 'biometric_enabled', value: 'true');
  }

  // Get saved credentials
  static Future<Map<String, String?>> getSavedCredentials() async {
    final email = await _secureStorage.read(key: 'biometric_email');
    final password = await _secureStorage.read(key: 'biometric_password');
    return {'email': email, 'password': password};
  }

  // Check if biometric login is enabled
  static Future<bool> isBiometricEnabled() async {
    final enabled = await _secureStorage.read(key: 'biometric_enabled');
    return enabled == 'true';
  }

  // Disable biometric login
  static Future<void> disableBiometric() async {
    await _secureStorage.delete(key: 'biometric_email');
    await _secureStorage.delete(key: 'biometric_password');
    await _secureStorage.delete(key: 'biometric_enabled');
    await _secureStorage.delete(key: 'fingerprint_only');
  }

  // Check if fingerprint-only mode is enabled
  static Future<bool> isFingerprintOnly() async {
    final fingerprintOnly = await _secureStorage.read(key: 'fingerprint_only');
    return fingerprintOnly == 'true';
  }

  // Set fingerprint-only mode
  static Future<void> setFingerprintOnly(bool value) async {
    await _secureStorage.write(key: 'fingerprint_only', value: value.toString());
  }

  // Perform biometric login
  static Future<User?> loginWithBiometric() async {
    try {
      // First authenticate with biometric
      final authenticated = await authenticate();
      if (!authenticated) {
        return null;
      }

      // Get saved credentials
      final credentials = await getSavedCredentials();
      if (credentials['email'] == null || credentials['password'] == null) {
        return null;
      }

      // Login with saved credentials
      return await AuthService.login(
        credentials['email']!,
        credentials['password']!,
      );
    } catch (e) {
      print('Biometric login error: $e');
      return null;
    }
  }
}

