import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/notice_model.dart';

class NoticesApiService {
  const NoticesApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<NoticeBoardModel> fetchNotices({
    int? academicSessionId,
    String category = '',
    String priority = '',
    bool unread = false,
    String search = '',
    int limit = 50,
  }) async {
    DioException? lastError;
    for (final url in AppConfig.noticesUrls) {
      try {
        final data = await _apiClient.getCachedJsonMap(
          url,
          queryParameters: {
            'academic_session_id': ?academicSessionId,
            if (category.isNotEmpty) 'category': category,
            if (priority.isNotEmpty) 'priority': priority,
            if (unread) 'unread': '1',
            if (search.isNotEmpty) 'search': search,
            'limit': limit,
          },
          options: _jsonOptions(),
          ttl: const Duration(seconds: 60),
        );
        return NoticeBoardModel.fromJson(data);
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
    throw const ApiException('Unable to load notices.');
  }

  Future<void> markRead(int noticeId) async {
    DioException? lastError;
    for (final url in AppConfig.noticesUrls) {
      try {
        await _apiClient.dio.post<Map<String, dynamic>>(
          '$url${noticeId.toString()}/read/',
          options: _jsonOptions(),
        );
        _apiClient.clearGetCache(contains: '/api/mobile/notices/');
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
    throw const ApiException('Unable to update notice.');
  }

  Future<NoticeItemModel> fetchNotice(int noticeId) async {
    DioException? lastError;
    for (final url in AppConfig.noticeDetailUrls(noticeId)) {
      try {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          url,
          options: _jsonOptions(),
        );
        final notice = response.data?['notice'];
        if (notice is Map) {
          return NoticeItemModel.fromJson(Map<String, dynamic>.from(notice));
        }
        throw const ApiException('Notice details are unavailable.');
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
    throw const ApiException('Unable to load notice details.');
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
}
