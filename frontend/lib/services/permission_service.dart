/// Service to track when system permission dialogs are being shown
/// This prevents the app from logging out users when permission dialogs appear
class PermissionService {
  static bool _isRequestingPermission = false;

  /// Check if a permission request is currently in progress
  static bool get isRequestingPermission => _isRequestingPermission;

  /// Mark that a permission request is starting
  static void startPermissionRequest() {
    _isRequestingPermission = true;
    print('Permission request started');
  }

  /// Mark that a permission request has completed
  static void endPermissionRequest() {
    _isRequestingPermission = false;
    print('Permission request ended');
  }
}

