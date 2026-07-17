import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/homework_planner_model.dart';

class HomeworkApiService {
  const HomeworkApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<HomeworkPlannerModel> fetchHomeworkPlanner({
    int? academicSessionId,
  }) async {
    DioException? lastError;
    for (final url in AppConfig.homeworkPlannerUrls) {
      try {
        final data = await _apiClient.getCachedJsonMap(
          url,
          queryParameters: {'academic_session_id': ?academicSessionId},
          options: _jsonOptions(),
          ttl: const Duration(minutes: 2),
        );
        return HomeworkPlannerModel.fromJson(data);
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

  Future<String> downloadPlannerDocument(String url) async {
    DioException? lastError;
    for (final documentUrl in _documentUrls(url)) {
      try {
        final response = await _apiClient.dio.get<String>(
          documentUrl,
          options: Options(
            extra: {'requiresAuth': true},
            responseType: ResponseType.plain,
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );
        return response.data ?? '';
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
    throw const ApiException('Unable to download homework planner.');
  }

  Options _jsonOptions() {
    return Options(
      extra: {'requiresAuth': true},
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 8),
    );
  }

  bool _shouldTryNextHost(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError;
  }

  Iterable<String> _documentUrls(String url) sync* {
    yield url;
    final parsed = Uri.tryParse(url);
    if (parsed == null) {
      return;
    }
    if (parsed.host != '127.0.0.1' && parsed.host != 'localhost') {
      return;
    }
    for (final baseUrl in AppConfig.baseUrls) {
      final base = Uri.parse(baseUrl);
      yield parsed
          .replace(scheme: base.scheme, host: base.host, port: base.port)
          .toString();
    }
  }
}
