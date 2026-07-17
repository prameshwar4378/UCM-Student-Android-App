import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/push_notification_model.dart';

class NotificationsApiService {
  const NotificationsApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<PushNotificationFeedModel> fetchNotifications() async {
    DioException? lastError;
    for (final url in AppConfig.notificationsUrls) {
      try {
        final data = await _apiClient.getCachedJsonMap(
          url,
          options: Options(
            extra: {'requiresAuth': true},
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 8),
          ),
          ttl: const Duration(seconds: 30),
        );
        return PushNotificationFeedModel.fromJson(data);
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
    throw const ApiException('Unable to load notifications.');
  }

  Future<void> markRead(Map<String, dynamic> notificationData) async {
    DioException? lastError;
    for (final url in AppConfig.notificationReadUrls) {
      try {
        await _apiClient.dio.post<Map<String, dynamic>>(
          url,
          data: notificationData,
          options: Options(
            extra: {'requiresAuth': true},
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );
        _apiClient.clearGetCache(contains: '/api/mobile/notifications/');
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
    throw const ApiException('Unable to update notification.');
  }

  bool _shouldTryNextHost(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError;
  }
}
