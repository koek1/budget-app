import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:budget_app/services/auth_service.dart';
import 'package:budget_app/models/user.dart';

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Check if fingerprint authentication is available
  static Future<bool> isAvailable() async {
    try {
      final availableBiometrics = await getAvailableBiometrics();
      return availableBiometrics.contains(BiometricType.fingerprint);
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

  // Authenticate using fingerprint only
  static Future<bool> authenticate() async {
    try {
      // Check if fingerprint is available
      final availableBiometrics = await getAvailableBiometrics();
      if (!availableBiometrics.contains(BiometricType.fingerprint)) {
        throw PlatformException(
          code: 'FINGERPRINT_NOT_AVAILABLE',
          message: 'Fingerprint authentication is not available on this device',
        );
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please use your fingerprint to access SpendSense',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Fingerprint authentication error: $e');
      return false;
    } catch (e) {
      print('Fingerprint authentication error: $e');
      return false;
    }
  }

  // Save user credentials securely for biometric login
  static Future<void> saveCredentialsForBiometric(String username, String password) async {
    await _secureStorage.write(key: 'biometric_username', value: username);
    await _secureStorage.write(key: 'biometric_password', value: password);
    await _secureStorage.write(key: 'biometric_enabled', value: 'true');
  }

  // Get saved credentials
  static Future<Map<String, String?>> getSavedCredentials() async {
    final username = await _secureStorage.read(key: 'biometric_username');
    final password = await _secureStorage.read(key: 'biometric_password');
    return {'username': username, 'password': password};
  }

  // Check if biometric login is enabled
  static Future<bool> isBiometricEnabled() async {
    final enabled = await _secureStorage.read(key: 'biometric_enabled');
    return enabled == 'true';
  }

  // Disable biometric login
  static Future<void> disableBiometric() async {
    await _secureStorage.delete(key: 'biometric_username');
    await _secureStorage.delete(key: 'biometric_password');
    await _secureStorage.delete(key: 'biometric_enabled');
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
      if (credentials['username'] == null || credentials['password'] == null) {
        return null;
      }

      // Login with saved credentials
      return await AuthService.login(
        credentials['username']!,
        credentials['password']!,
      );
    } catch (e) {
      print('Biometric login error: $e');
      return null;
    }
  }
}

