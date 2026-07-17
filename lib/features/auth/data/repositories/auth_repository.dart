import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/errors/api_exception.dart';
import '../models/login_response_model.dart';
import '../models/user_model.dart';
import '../services/auth_api_service.dart';

class AuthRepository {
  const AuthRepository(this._authApiService, this._secureStorageService);

  final AuthApiService _authApiService;
  final SecureStorageService _secureStorageService;

  Future<LoginResponseModel> login({
    required String username,
    required String password,
  }) async {
    final response = await _authApiService.login(
      username: username,
      password: password,
    );

    await _secureStorageService.saveAuthSession(
      accessToken: response.access,
      refreshToken: response.refresh,
      userId: response.user.id,
      username: response.user.username,
      role: response.user.role,
      instituteId: response.user.instituteId,
    );

    return response;
  }

  Future<void> logout() {
    return _secureStorageService.clearAuthSession();
  }

  Future<UserModel?> restoreSession() async {
    final refreshToken = await _secureStorageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }
    try {
      return await _authApiService.currentUser();
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _secureStorageService.clearAuthSession();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _authApiService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }
}
