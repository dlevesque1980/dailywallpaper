import 'package:dailywallpaper/services/permissions/permission_service.dart';
import 'package:dailywallpaper/services/permissions/permission_service_impl.dart';

class RequestInitialPermissionsUseCase {
  final PermissionService _permissionService;

  RequestInitialPermissionsUseCase({PermissionService? permissionService})
      : _permissionService = permissionService ?? PermissionServiceImpl();

  Future<void> call() async {
    await _permissionService.requestInitialPermissions();
  }
}
