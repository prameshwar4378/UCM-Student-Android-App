import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/attendance_model.dart';

class AttendanceApiService {
  const AttendanceApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<AttendanceModel> fetchAttendance({
    int? academicSessionId,
    String? status,
    String? batchId,
    String? dateFrom,
    String? dateTo,
    int limit = 180,
  }) async {
    DioException? lastError;
    for (final url in AppConfig.attendanceUrls) {
      try {
        final data = await _apiClient.getCachedJsonMap(
          url,
          queryParameters: {
            'academic_session_id': ?academicSessionId,
            if (status != null && status.isNotEmpty) 'status': status,
            if (batchId != null && batchId.isNotEmpty) 'batch_id': batchId,
            if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
            if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
            'limit': limit,
          },
          options: Options(
            extra: {'requiresAuth': true},
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 8),
          ),
          ttl: const Duration(seconds: 90),
        );
        return AttendanceModel.fromJson(data);
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
    throw const ApiException('Unable to load attendance.');
  }

  bool _shouldTryNextHost(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError;
  }
}
