import 'package:permission_handler/permission_handler.dart';
import 'package:dailywallpaper/services/permissions/permission_service.dart';

class PermissionServiceImpl implements PermissionService {
  @override
  Future<bool> isWallpaperPermissionGranted() async {
    // SET_WALLPAPER is a normal permission on Android, usually always granted if in manifest.
    // However, permission_handler doesn't have a specific 'wallpaper' type as it's not a runtime permission.
    // We return true as it's declared in manifest.
    return true;
  }

  @override
  Future<bool> isNotificationPermissionGranted() async {
    return await Permission.notification.isGranted;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestInitialPermissions() async {
    return await [
      Permission.notification,
    ].request();
  }

  @override
  Future<PermissionStatus> requestPermission(Permission permission) async {
    return await permission.request();
  }
}
