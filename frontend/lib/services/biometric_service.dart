import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:budget_app/services/auth_service.dart';
import 'package:budget_app/models/user.dart';

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static bool _isAuthenticating = false; // Track if biometric auth is in progress

  // Check if biometric authentication is available (fingerprint, face, etc.)
  static Future<bool> isAvailable() async {
    try {
      // First, try a quick check without timeout to avoid false negatives
      bool isDeviceSupported = false;
      bool canCheckBiometrics = false;
      
      try {
        isDeviceSupported = await _localAuth.isDeviceSupported();
      } catch (e) {
        print('Error checking device support: $e');
        // Continue to next check
      }
      
      try {
        canCheckBiometrics = await _localAuth.canCheckBiometrics;
      } catch (e) {
        print('Error checking canCheckBiometrics: $e');
        // Continue to next check
      }
      
      print('Biometric check - Device supported: $isDeviceSupported, Can check: $canCheckBiometrics');
      
      // If either check returns true, we likely have biometric support
      // This is especially important for Samsung devices that may report support
      // even if getAvailableBiometrics() doesn't return types immediately
      if (isDeviceSupported || canCheckBiometrics) {
        print('Device reports biometric support - checking available types...');
        
        // Try to get available biometric types (but don't fail if this times out)
        List<BiometricType> availableBiometrics = [];
        try {
          availableBiometrics = await getAvailableBiometrics()
              .timeout(Duration(seconds: 5), onTimeout: () => <BiometricType>[]);
        } catch (e) {
          print('Error getting available biometrics: $e');
          // Continue with empty list - we'll use fallback
        }
        
        print('Available biometric types: $availableBiometrics');
        
        // If we have any biometric type available, return true
        if (availableBiometrics.isNotEmpty) {
          print('Biometrics available: ${availableBiometrics.length} types');
          return true;
        }
        
        // Fallback: if device reports support, trust it (Samsung compatibility)
        // Many Samsung devices support biometrics but may not list types immediately
        print('Device supports biometrics but types not listed - allowing (Samsung compatibility)');
        return true;
      }
      
      // If device doesn't support at all, return false
      print('Device does not support biometrics');
      return false;
    } catch (e) {
      print('Error checking biometric availability: $e');
      // On error, try a simple fallback check
      try {
        final canCheck = await _localAuth.canCheckBiometrics
            .timeout(Duration(seconds: 3), onTimeout: () => false);
        if (canCheck) {
          print('Biometrics available via fallback check');
          return true;
        }
      } catch (e2) {
        print('Fallback check also failed: $e2');
      }
      // On error, return false to be safe
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

  // Check if biometric authentication is currently in progress
  static bool get isAuthenticating => _isAuthenticating;

  // Authenticate using fingerprint only
  static Future<bool> authenticate() async {
    try {
      // Mark that authentication is in progress
      _isAuthenticating = true;
      
      // Check if device supports biometrics
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      
      print('Device supported: $isDeviceSupported, Can check biometrics: $canCheckBiometrics');
      
      if (!isDeviceSupported && !canCheckBiometrics) {
        _isAuthenticating = false; // Reset flag on error
        throw PlatformException(
          code: 'FINGERPRINT_NOT_AVAILABLE',
          message: 'Fingerprint authentication is not available on this device',
        );
      }

      // Check available biometrics
      final availableBiometrics = await getAvailableBiometrics();
      print('Available biometrics: $availableBiometrics');

      // Try to authenticate - use any available biometric (fingerprint, face, etc.)
      print('Starting biometric authentication...');
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please use your biometric to access SpendSense',
        options: const AuthenticationOptions(
          biometricOnly: true, // Use biometrics only (fingerprint, face, etc.)
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      
      print('Fingerprint authentication result: $didAuthenticate');
      _isAuthenticating = false; // Reset flag after authentication completes
      return didAuthenticate;
    } on PlatformException catch (e) {
      _isAuthenticating = false; // Reset flag on error
      print('Fingerprint authentication PlatformException: ${e.code} - ${e.message}');
      
      // Handle specific error codes
      if (e.code == 'NotAvailable' || e.code == 'NotEnrolled') {
        throw PlatformException(
          code: 'FINGERPRINT_NOT_AVAILABLE',
          message: 'Please set up fingerprint authentication in your device settings',
        );
      } else if (e.code == 'NotAuthenticated') {
        // User failed authentication (wrong fingerprint)
        throw PlatformException(
          code: 'AUTHENTICATION_FAILED',
          message: 'Fingerprint not recognized. Please try again.',
        );
      } else if (e.code == 'UserCancel' || e.code == 'cancel') {
        // User cancelled
        throw PlatformException(
          code: 'USER_CANCELLED',
          message: 'Fingerprint authentication was cancelled',
        );
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        throw PlatformException(
          code: 'LOCKED_OUT',
          message: 'Too many failed attempts. Please try again later or use your password.',
        );
      }
      
      // For other errors, throw with the original message
      throw PlatformException(
        code: e.code,
        message: e.message ?? 'Fingerprint authentication failed',
      );
    } catch (e) {
      _isAuthenticating = false; // Reset flag on any error
      print('Fingerprint authentication error: $e');
      if (e is PlatformException) {
        rethrow;
      }
      throw Exception('Fingerprint authentication failed: ${e.toString()}');
    }
  }

  // Save user credentials securely for biometric login
  static Future<void> saveCredentialsForBiometric(String username, String password) async {
    try {
      if (username.isEmpty || password.isEmpty) {
        throw Exception('Username and password cannot be empty');
      }
      
      print('Saving biometric credentials for user: $username');
      await _secureStorage.write(key: 'biometric_username', value: username.trim());
      await _secureStorage.write(key: 'biometric_password', value: password);
      await _secureStorage.write(key: 'biometric_enabled', value: 'true');
      
      // Verify the credentials were saved
      final savedUsername = await _secureStorage.read(key: 'biometric_username');
      final savedPassword = await _secureStorage.read(key: 'biometric_password');
      
      if (savedUsername != username.trim() || savedPassword != password) {
        throw Exception('Failed to save credentials securely');
      }
      
      print('Biometric credentials saved successfully');
    } catch (e) {
      print('Error saving biometric credentials: $e');
      rethrow;
    }
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
    // Set flag early to prevent app lifecycle from logging out during biometric dialog
    _isAuthenticating = true;
    try {
      // First authenticate with biometric
      print('Starting fingerprint authentication...');
      final authenticated = await authenticate();
      if (!authenticated) {
        print('Fingerprint authentication returned false');
        throw Exception('Fingerprint authentication was not successful. Please try again.');
      }
      print('Fingerprint authentication successful');

      // Get saved credentials
      print('Retrieving saved credentials...');
      final credentials = await getSavedCredentials();
      print('Retrieved credentials - username: ${credentials['username'] != null ? 'present' : 'missing'}, password: ${credentials['password'] != null ? 'present' : 'missing'}');
      
      if (credentials['username'] == null || credentials['password'] == null) {
        print('Saved credentials are missing');
        throw Exception('Saved login credentials not found. Please login with username and password, then enable fingerprint login again.');
      }

      // Login with saved credentials
      print('Attempting login with saved credentials...');
      try {
        final user = await AuthService.login(
          credentials['username']!,
          credentials['password']!,
        );
        print('Login successful with saved credentials');
        return user;
      } catch (e) {
        print('Login with saved credentials failed: $e');
        // If login fails, the credentials might be outdated - clear them
        await disableBiometric();
        rethrow;
      }
    } on PlatformException catch (e) {
      print('Platform exception during biometric login: $e');
      // Ensure flag is reset even if exception occurs
      _isAuthenticating = false;
      if (e.code == 'FINGERPRINT_NOT_AVAILABLE') {
        throw Exception('Fingerprint authentication is not available. Please set up fingerprint in your device settings.');
      }
      throw Exception('Fingerprint authentication error: ${e.message ?? e.code}');
    } catch (e) {
      print('Biometric login error: $e');
      // Ensure flag is reset even if exception occurs
      _isAuthenticating = false;
      final errorMsg = e.toString();
      if (errorMsg.contains('Exception: ')) {
        rethrow; // Re-throw if it's already a formatted exception
      }
      throw Exception('Fingerprint login failed: ${e.toString()}');
    }
  }
}

