import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import 'local_notification_service.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final service = PushNotificationService(ref.watch(apiClientProvider));
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class PushNotificationService {
  PushNotificationService(this._apiClient);

  final ApiClient _apiClient;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<Map<String, dynamic>>?
  _localNotificationOpenedSubscription;

  Future<bool> registerCurrentDevice({
    void Function(Map<String, dynamic> data)? onDataChanged,
    void Function(Map<String, dynamic> data)? onNotificationOpened,
  }) async {
    final messaging = _messagingOrNull();
    if (messaging == null) {
      debugPrint('Push registration skipped: Firebase Messaging is not ready.');
      return false;
    }

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push registration skipped: notification permission denied.');
      return false;
    }

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _getToken(messaging);
    if (token == null || token.isEmpty) {
      debugPrint('Push registration skipped: Firebase returned empty token.');
      return false;
    }

    final registered = await _registerToken(token);
    if (!registered) {
      return false;
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) {
      _registerToken(newToken);
    });
    await _foregroundMessageSubscription?.cancel();
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((
      message,
    ) async {
      debugPrint(
        'Push received in foreground: ${message.notification?.title ?? message.data['title'] ?? 'Notification'}',
      );
      try {
        await LocalNotificationService.showForegroundMessage(message);
      } catch (error) {
        debugPrint('Unable to display foreground notification: $error');
      }
      onDataChanged?.call(_messagePayload(message));
    });
    await _messageOpenedSubscription?.cancel();
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      final data = _messagePayload(message);
      debugPrint('Push opened: ${message.messageId ?? data}');
      onDataChanged?.call(data);
      onNotificationOpened?.call(data);
    });
    await _localNotificationOpenedSubscription?.cancel();
    _localNotificationOpenedSubscription = LocalNotificationService
        .openedNotifications
        .listen((data) {
          onDataChanged?.call(data);
          onNotificationOpened?.call(data);
        });
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      final data = _messagePayload(initialMessage);
      onDataChanged?.call(data);
      onNotificationOpened?.call(data);
    }
    final localLaunchPayload =
        LocalNotificationService.takePendingLaunchPayload();
    if (localLaunchPayload != null) {
      onDataChanged?.call(localLaunchPayload);
      onNotificationOpened?.call(localLaunchPayload);
    }
    return true;
  }

  Map<String, dynamic> _messagePayload(RemoteMessage message) {
    return {
      ...message.data,
      'title': ?message.notification?.title,
      'body': ?message.notification?.body,
      if (message.sentTime case final sentTime?)
        'created_at': sentTime.toIso8601String(),
    };
  }

  Future<void> unregisterCurrentDevice() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    await _localNotificationOpenedSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _messageOpenedSubscription = null;
    _localNotificationOpenedSubscription = null;

    final messaging = _messagingOrNull();
    if (messaging == null) {
      return;
    }

    final token = await _getToken(messaging);
    if (token == null || token.isEmpty) {
      return;
    }
    for (final url in AppConfig.unregisterDeviceUrls) {
      try {
        await _apiClient.dio.post<Map<String, dynamic>>(
          url,
          data: {'token': token},
          options: Options(
            extra: {'requiresAuth': true},
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );
        break;
      } on DioException catch (error) {
        if (!_shouldTryNextHost(error)) {
          rethrow;
        }
      }
    }
  }

  Future<bool> _registerToken(String token) async {
    for (final url in AppConfig.registerDeviceUrls) {
      try {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          url,
          data: {'token': token, 'platform': _platformName()},
          options: Options(extra: {'requiresAuth': true}),
        );
        final firebaseReady = response.data?['firebase_ready'] == true;
        final firebaseDetail =
            response.data?['firebase_detail']?.toString() ?? '';
        debugPrint(
          firebaseReady
              ? 'Push device token registered; Firebase backend is ready.'
              : 'Push device token registered, but Firebase backend is not ready: $firebaseDetail',
        );
        return true;
      } on DioException catch (error) {
        if (!_shouldTryNextHost(error)) {
          debugPrint(
            'Push registration failed: ${error.response?.statusCode ?? error.type} ${error.response?.data ?? error.message}',
          );
          return false;
        }
      }
    }
    debugPrint(
      'Push registration failed: no API host accepted the device token.',
    );
    return false;
  }

  FirebaseMessaging? _messagingOrNull() {
    try {
      return FirebaseMessaging.instance;
    } on FirebaseException {
      return null;
    }
  }

  Future<String?> _getToken(FirebaseMessaging messaging) async {
    try {
      return await messaging.getToken(
        vapidKey: AppConfig.firebaseWebVapidKey.isEmpty
            ? null
            : AppConfig.firebaseWebVapidKey,
      );
    } on FirebaseException catch (error) {
      debugPrint(
        'Unable to get Firebase token: ${error.code} ${error.message}',
      );
      return null;
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    await _localNotificationOpenedSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _messageOpenedSubscription = null;
    _localNotificationOpenedSubscription = null;
  }

  bool _shouldTryNextHost(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError;
  }

  String _platformName() {
    if (kIsWeb) {
      return 'WEB';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'ANDROID';
      case TargetPlatform.iOS:
        return 'IOS';
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return 'DESKTOP';
      case TargetPlatform.fuchsia:
        return 'UNKNOWN';
    }
  }
}
