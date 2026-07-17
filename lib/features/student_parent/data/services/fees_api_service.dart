import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/fee_details_model.dart';

class FeesApiService {
  const FeesApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<FeeDetailsModel> fetchFeeDetails({int? academicSessionId}) async {
    DioException? lastError;
    for (final baseUrl in AppConfig.baseUrls) {
      try {
        final data = await _getMap(
          '$baseUrl/api/mobile/fees/',
          queryParameters: {'academic_session_id': ?academicSessionId},
          options: _jsonOptions(
            connectTimeout: const Duration(seconds: 2),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        return FeeDetailsModel.fromJson(data);
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

  Future<Map<String, dynamic>> _getMap(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _apiClient.getCachedJsonMap(
      url,
      queryParameters: queryParameters,
      options: options ?? _jsonOptions(),
      ttl: const Duration(minutes: 2),
    );
  }

  Options _jsonOptions({
    Duration connectTimeout = const Duration(seconds: 4),
    Duration receiveTimeout = const Duration(seconds: 8),
  }) {
    return Options(
      extra: {'requiresAuth': true},
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
    );
  }

  bool _shouldTryNextHost(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError;
  }

  Future<String> downloadReceipt(String url) async {
    DioException? lastError;
    for (final receiptUrl in _receiptUrls(url)) {
      try {
        final response = await _apiClient.dio.get<String>(
          receiptUrl,
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
    throw const ApiException('Unable to download receipt.');
  }

  Iterable<String> _receiptUrls(String url) sync* {
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
