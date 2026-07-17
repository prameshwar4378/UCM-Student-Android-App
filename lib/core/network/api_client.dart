import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../errors/api_exception.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  ApiClient(this._secureStorageService)
    : dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final requiresAuth = options.extra['requiresAuth'] == true;
          if (requiresAuth) {
            final token = await _secureStorageService.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          _captureSubscriptionAccess(error.response);
          final canRefresh =
              error.response?.statusCode == 401 &&
              error.requestOptions.extra['requiresAuth'] == true &&
              error.requestOptions.extra['_retryAfterRefresh'] != true;
          if (canRefresh) {
            final refreshed = await _refreshAccessToken();
            if (refreshed) {
              try {
                final response = await _retry(error.requestOptions);
                handler.resolve(response);
                return;
              } on DioException catch (retryError) {
                handler.next(retryError);
                return;
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final SecureStorageService _secureStorageService;
  final Dio dio;
  final Map<String, _CachedJsonResponse> _getCache = {};
  final Map<String, Future<Map<String, dynamic>>> _getRefreshes = {};
  final ValueNotifier<Set<String>> backgroundRefreshes =
      ValueNotifier<Set<String>>(<String>{});
  final ValueNotifier<SubscriptionAccessState> subscriptionAccess =
      ValueNotifier<SubscriptionAccessState>(
        const SubscriptionAccessState.allowed(),
      );
  Future<bool>? _refreshFuture;
  DateTime? _lastCacheClearAt;
  DateTime? _lastRefreshAt;
  DateTime? _lastStaleServedAt;
  int _staleServedCount = 0;

  void setSubscriptionAccess({required bool allowed, String message = ''}) {
    subscriptionAccess.value = allowed
        ? const SubscriptionAccessState.allowed()
        : SubscriptionAccessState.blocked(message);
  }

  void _captureSubscriptionAccess(Response<dynamic>? response) {
    final data = response?.data;
    if (response?.statusCode != 403 || data is! Map) {
      return;
    }
    if (data['code'] == 'subscription_expired') {
      setSubscriptionAccess(
        allowed: false,
        message:
            data['detail'] as String? ??
            'Your institute subscription has expired.',
      );
    }
  }

  Future<bool> _refreshAccessToken() {
    final inFlight = _refreshFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _doRefreshAccessToken();
    _refreshFuture = future;
    future.whenComplete(() => _refreshFuture = null);
    return future;
  }

  Future<bool> _doRefreshAccessToken() async {
    final refreshToken = await _secureStorageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    for (final url in AppConfig.refreshUrls) {
      try {
        final response = await dio.post<Map<String, dynamic>>(
          url,
          data: {'refresh': refreshToken},
          options: Options(
            extra: {'skipAuthRefresh': true},
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );
        final access = response.data?['access'] as String? ?? '';
        if (access.isEmpty) {
          continue;
        }
        await _secureStorageService.saveAccessToken(access);
        return true;
      } on DioException catch (error) {
        if (!_shouldTryNextRefreshHost(error)) {
          return false;
        }
      }
    }
    return false;
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final accessToken = await _secureStorageService.getAccessToken();
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    final extra = Map<String, dynamic>.from(requestOptions.extra)
      ..['_retryAfterRefresh'] = true;

    return dio.fetch<dynamic>(
      requestOptions.copyWith(headers: headers, extra: extra),
    );
  }

  bool _shouldTryNextRefreshHost(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError;
  }

  Future<Map<String, dynamic>> getCachedJsonMap(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    Duration ttl = const Duration(minutes: 2),
    Duration staleTtl = const Duration(minutes: 10),
  }) async {
    final cacheKey = _cacheKey(url, queryParameters);
    final cached = _getCache[cacheKey];
    final now = DateTime.now();
    if (cached != null && cached.expiresAt.isAfter(now)) {
      return Map<String, dynamic>.from(cached.data);
    }

    if (cached != null && cached.staleUntil.isAfter(now)) {
      _lastStaleServedAt = now;
      _staleServedCount += 1;
      _refreshInBackground(
        cacheKey,
        url,
        queryParameters: queryParameters,
        options: options,
        ttl: ttl,
        staleTtl: staleTtl,
      );
      return Map<String, dynamic>.from(cached.data);
    }

    return _refreshCachedJsonMap(
      cacheKey,
      url,
      queryParameters: queryParameters,
      options: options,
      ttl: ttl,
      staleTtl: staleTtl,
    );
  }

  void _refreshInBackground(
    String cacheKey,
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    required Duration ttl,
    required Duration staleTtl,
  }) {
    if (_getRefreshes.containsKey(cacheKey)) {
      return;
    }
    backgroundRefreshes.value = {...backgroundRefreshes.value, cacheKey};
    _refreshCachedJsonMap(
      cacheKey,
      url,
      queryParameters: queryParameters,
      options: options,
      ttl: ttl,
      staleTtl: staleTtl,
    ).whenComplete(() {
      final active = {...backgroundRefreshes.value}..remove(cacheKey);
      backgroundRefreshes.value = active;
    }).ignore();
  }

  Future<Map<String, dynamic>> _refreshCachedJsonMap(
    String cacheKey,
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    required Duration ttl,
    required Duration staleTtl,
  }) {
    final inFlight = _getRefreshes[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }
    final refresh = _fetchAndCacheJsonMap(
      cacheKey,
      url,
      queryParameters: queryParameters,
      options: options,
      ttl: ttl,
      staleTtl: staleTtl,
    );
    _getRefreshes[cacheKey] = refresh;
    refresh.whenComplete(() => _getRefreshes.remove(cacheKey));
    return refresh;
  }

  Future<Map<String, dynamic>> _fetchAndCacheJsonMap(
    String cacheKey,
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    required Duration ttl,
    required Duration staleTtl,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      url,
      queryParameters: queryParameters,
      options: options,
    );
    final data = response.data;
    if (data == null) {
      throw const ApiException('Empty response from server.');
    }
    final now = DateTime.now();
    final copiedData = Map<String, dynamic>.from(data);
    _getCache[cacheKey] = _CachedJsonResponse(
      copiedData,
      now.add(ttl),
      now.add(staleTtl),
    );
    _lastRefreshAt = now;
    return Map<String, dynamic>.from(copiedData);
  }

  void clearGetCache({String? contains}) {
    _lastCacheClearAt = DateTime.now();
    if (contains == null || contains.isEmpty) {
      _getCache.clear();
      _getRefreshes.clear();
      return;
    }
    _getCache.removeWhere((key, _) => key.contains(contains));
    _getRefreshes.removeWhere((key, _) => key.contains(contains));
  }

  bool hasFreshCachedResponse(String cacheKey) {
    return _getCache[cacheKey]?.expiresAt.isAfter(DateTime.now()) ?? false;
  }

  CacheSyncStatus get cacheSyncStatus {
    final now = DateTime.now();
    final fresh = _getCache.values
        .where((item) => item.expiresAt.isAfter(now))
        .length;
    final stale = _getCache.length - fresh;
    return CacheSyncStatus(
      cachedResponses: _getCache.length,
      freshResponses: fresh,
      staleResponses: stale,
      inFlightRefreshes: _getRefreshes.length,
      backgroundRefreshes: backgroundRefreshes.value.length,
      lastCacheClearAt: _lastCacheClearAt,
      lastRefreshAt: _lastRefreshAt,
      lastStaleServedAt: _lastStaleServedAt,
      staleServedCount: _staleServedCount,
    );
  }

  ApiException handleDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const ApiException('Request timed out. Please try again.');
    }

    if (error.type == DioExceptionType.connectionError) {
      return const ApiException(
        'Unable to connect to the server. Check your internet or API URL.',
      );
    }

    if (data is Map<String, dynamic>) {
      final detail = data['detail'] ?? data['message'] ?? data['error'];
      if (detail is String && detail.isNotEmpty) {
        return ApiException(
          detail,
          statusCode: statusCode,
          code: data['code'] as String?,
        );
      }
    }

    if (statusCode == 401) {
      return ApiException(
        'Your session has expired. Please login again.',
        statusCode: statusCode,
      );
    }

    if (statusCode == 400 || statusCode == 403) {
      return ApiException(
        statusCode == 403
            ? 'You are not allowed to perform this action.'
            : 'Request could not be completed. Please try again.',
        statusCode: statusCode,
      );
    }

    return ApiException(
      'Something went wrong. Please try again.',
      statusCode: statusCode,
    );
  }
}

class SubscriptionAccessState {
  const SubscriptionAccessState.allowed() : isBlocked = false, message = '';

  const SubscriptionAccessState.blocked(this.message) : isBlocked = true;

  final bool isBlocked;
  final String message;
}

class CacheSyncStatus {
  const CacheSyncStatus({
    required this.cachedResponses,
    required this.freshResponses,
    required this.staleResponses,
    required this.inFlightRefreshes,
    required this.backgroundRefreshes,
    required this.lastCacheClearAt,
    required this.lastRefreshAt,
    required this.lastStaleServedAt,
    required this.staleServedCount,
  });

  final int cachedResponses;
  final int freshResponses;
  final int staleResponses;
  final int inFlightRefreshes;
  final int backgroundRefreshes;
  final DateTime? lastCacheClearAt;
  final DateTime? lastRefreshAt;
  final DateTime? lastStaleServedAt;
  final int staleServedCount;

  bool get isSyncing => inFlightRefreshes > 0 || backgroundRefreshes > 0;

  String get detail {
    if (isSyncing) {
      return 'Background refresh is updating cached student data.';
    }
    if (cachedResponses == 0) {
      return 'No cached app data yet. Open pages to build cache.';
    }
    if (staleResponses > 0) {
      return 'Some cached data is stale and will refresh automatically.';
    }
    return 'Cached student data is fresh.';
  }
}

class _CachedJsonResponse {
  const _CachedJsonResponse(this.data, this.expiresAt, this.staleUntil);

  final Map<String, dynamic> data;
  final DateTime expiresAt;
  final DateTime staleUntil;
}

String _cacheKey(String url, Map<String, dynamic>? queryParameters) {
  if (queryParameters == null || queryParameters.isEmpty) {
    return url;
  }
  final keys = queryParameters.keys.toList()..sort();
  final query = keys
      .map(
        (key) => '$key=${Uri.encodeQueryComponent('${queryParameters[key]}')}',
      )
      .join('&');
  return '$url?$query';
}
