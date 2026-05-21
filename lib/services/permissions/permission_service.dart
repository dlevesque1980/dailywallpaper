import 'package:permission_handler/permission_handler.dart';

abstract class PermissionService {
  Future<bool> isWallpaperPermissionGranted();
  Future<bool> isNotificationPermissionGranted();
  Future<Map<Permission, PermissionStatus>> requestInitialPermissions();
  Future<PermissionStatus> requestPermission(Permission permission);
}
