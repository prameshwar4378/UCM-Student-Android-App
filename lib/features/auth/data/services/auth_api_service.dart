import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/login_response_model.dart';
import '../models/user_model.dart';

class AuthApiService {
  const AuthApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<LoginResponseModel> login({
    required String username,
    required String password,
  }) async {
    DioException? lastError;
    for (final url in AppConfig.loginUrls) {
      try {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          url,
          data: {'username': username, 'password': password},
          options: Options(
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );

        final data = response.data;
        if (data == null) {
          throw const ApiException('Empty response from server.');
        }

        return LoginResponseModel.fromJson(data);
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldTryNextHost(error)) {
          throw _apiClient.handleDioException(error);
        }
      }
    }
    if (lastError != null) {
      throw _apiClient.handleDioException(lastError);
    }
    throw const ApiException('Unable to connect to the server.');
  }

  Future<UserModel> currentUser() async {
    DioException? lastError;
    for (final url in AppConfig.meUrls) {
      try {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          url,
          options: Options(
            extra: {'requiresAuth': true},
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );

        final data = response.data;
        if (data == null) {
          throw const ApiException('Empty response from server.');
        }

        return UserModel.fromJson(data['user'] as Map<String, dynamic>);
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldTryNextHost(error)) {
          throw _apiClient.handleDioException(error);
        }
      }
    }
    if (lastError != null) {
      throw _apiClient.handleDioException(lastError);
    }
    throw const ApiException('Unable to connect to the server.');
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    DioException? lastError;
    for (final url in AppConfig.changePasswordUrls) {
      try {
        await _apiClient.dio.post<Map<String, dynamic>>(
          url,
          data: {
            'current_password': currentPassword,
            'new_password': newPassword,
            'confirm_password': confirmPassword,
          },
          options: Options(
            extra: {'requiresAuth': true},
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );
        return;
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldTryNextHost(error)) {
          throw _apiClient.handleDioException(error);
        }
      }
    }
    if (lastError != null) {
      throw _apiClient.handleDioException(lastError);
    }
    throw const ApiException('Unable to connect to the server.');
  }

  bool _shouldTryNextHost(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError;
  }
}
