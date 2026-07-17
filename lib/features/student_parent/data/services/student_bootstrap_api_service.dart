import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/student_bootstrap_model.dart';

class StudentBootstrapApiService {
  const StudentBootstrapApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<StudentBootstrapModel> fetchBootstrap({int? academicSessionId}) async {
    DioException? lastError;
    for (final url in AppConfig.studentBootstrapUrls) {
      try {
        final data = await _apiClient.getCachedJsonMap(
          url,
          queryParameters: {'academic_session_id': ?academicSessionId},
          options: Options(
            extra: {'requiresAuth': true},
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 10),
          ),
          ttl: const Duration(minutes: 2),
        );
        return StudentBootstrapModel.fromJson(data);
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
    throw const ApiException('Unable to load the dashboard.');
  }

  bool _shouldTryNextHost(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError;
  }
}
