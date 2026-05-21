import 'package:dailywallpaper/features/wallpaper/domain/usecases/request_initial_permissions.dart';
import 'package:dailywallpaper/services/permissions/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';

class MockPermissionService extends Mock implements PermissionService {}

void main() {
  late MockPermissionService mockPermissionService;
  late RequestInitialPermissionsUseCase useCase;

  setUp(() {
    mockPermissionService = MockPermissionService();
    useCase = RequestInitialPermissionsUseCase(
        permissionService: mockPermissionService);
  });

  test('should call requestInitialPermissions on the service', () async {
    // Arrange
    when(() => mockPermissionService.requestInitialPermissions()).thenAnswer(
        (_) async => {Permission.notification: PermissionStatus.granted});

    // Act
    await useCase();

    // Assert
    verify(() => mockPermissionService.requestInitialPermissions()).called(1);
    verifyNoMoreInteractions(mockPermissionService);
  });
}
