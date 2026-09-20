/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:permission_handler/permission_handler.dart'
    hide openAppSettings;
import 'package:permission_handler/permission_handler.dart' as ph
    show openAppSettings;

class PermissionUtils {
  /// Request multiple permissions at once
  static Future<Map<Permission, PermissionStatus>> requestMultiplePermissions(
    List<Permission> permissions,
  ) async {
    return await permissions.request();
  }

  /// Request a single permission
  static Future<PermissionStatus> requestPermission(
      Permission permission) async {
    return await permission.request();
  }

  /// Check if a permission is granted
  static Future<bool> isPermissionGranted(Permission permission) async {
    return await permission.isGranted;
  }

  /// Check if a permission is permanently denied
  static Future<bool> isPermanentlyDenied(Permission permission) async {
    return await permission.isPermanentlyDenied;
  }

  /// Open app settings
  static Future<bool> openAppSettings() async {
    return ph.openAppSettings();
  }

  /// Request all permissions needed for the app
  static Future<Map<Permission, PermissionStatus>>
      requestAllPermissions() async {
    return await requestMultiplePermissions([
      Permission.location,
      Permission.locationAlways,
      Permission.camera,
      Permission.microphone,
      Permission.notification,
      Permission.sms,
    ]);
  }
}
