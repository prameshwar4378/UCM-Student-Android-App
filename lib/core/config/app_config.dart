import 'package:flutter/foundation.dart';

class AppConfig {
  static const defaultBaseUrl = 'https://ultracoachmatrix.in';
  static const _configuredUrl = String.fromEnvironment('API_BASE_URL');
  static const _configuredUrls = String.fromEnvironment('API_BASE_URLS');
  static const _localBaseUrl = String.fromEnvironment('LOCAL_API_BASE_URL');
  static const _useLocalApi = bool.fromEnvironment('USE_LOCAL_API');
  static const firebaseWebVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
  );
  static const firebaseWebApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
  );
  static const firebaseWebAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const firebaseWebMessagingSenderId = String.fromEnvironment(
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
  );
  static const firebaseWebProjectId = String.fromEnvironment(
    'FIREBASE_WEB_PROJECT_ID',
  );
  static const firebaseWebAuthDomain = String.fromEnvironment(
    'FIREBASE_WEB_AUTH_DOMAIN',
  );
  static const firebaseWebStorageBucket = String.fromEnvironment(
    'FIREBASE_WEB_STORAGE_BUCKET',
  );

  static bool get hasFirebaseWebConfig =>
      firebaseWebApiKey.isNotEmpty &&
      firebaseWebAppId.isNotEmpty &&
      firebaseWebMessagingSenderId.isNotEmpty &&
      firebaseWebProjectId.isNotEmpty;

  static String get baseUrl {
    return baseUrls.first;
  }

  static List<String> get baseUrls {
    if (_configuredUrl.isNotEmpty) {
      return [_normalizeBaseUrl(_configuredUrl)];
    }
    if (_configuredUrls.isNotEmpty) {
      return _splitBaseUrls(_configuredUrls);
    }
    if (_useLocalApi || kDebugMode) {
      return _debugBaseUrls;
    }
    return const [defaultBaseUrl];
  }

  static String get loginUrl => '$baseUrl/api/mobile/auth/login/';
  static String get refreshUrl => '$baseUrl/api/mobile/auth/refresh/';
  static String get meUrl => '$baseUrl/api/mobile/me/';
  static String get changePasswordUrl => '$baseUrl/api/mobile/auth/password/';
  static String get feeDetailsUrl => '$baseUrl/api/mobile/fees/';
  static String get feeSummaryUrl => '$baseUrl/api/mobile/fees/summary/';
  static String get feeInvoicesUrl => '$baseUrl/api/mobile/fees/invoices/';
  static String get feeBreakupUrl => '$baseUrl/api/mobile/fees/breakup/';
  static String get feePaymentsUrl => '$baseUrl/api/mobile/fees/payments/';
  static String get mobileHealthUrl => '$baseUrl/api/mobile/health/';
  static String get studentProfileUrl => '$baseUrl/api/mobile/profile/';
  static String get studentBootstrapUrl => '$baseUrl/api/mobile/bootstrap/';
  static String get attendanceUrl => '$baseUrl/api/mobile/attendance/';
  static String get homeworkPlannerUrl => '$baseUrl/api/mobile/homework/';
  static String get examsUrl => '$baseUrl/api/mobile/exams/';
  static String get noticesUrl => '$baseUrl/api/mobile/notices/';
  static String get registerDeviceUrl =>
      '$baseUrl/api/mobile/devices/register/';
  static String get unregisterDeviceUrl =>
      '$baseUrl/api/mobile/devices/unregister/';
  static String get notificationsUrl => '$baseUrl/api/mobile/notifications/';
  static String get notificationReadUrl =>
      '$baseUrl/api/mobile/notifications/read/';
  static String get pushStatusUrl => '$baseUrl/api/mobile/push/status/';
  static Iterable<String> get loginUrls =>
      baseUrls.map((url) => '$url/api/mobile/auth/login/');
  static Iterable<String> get refreshUrls =>
      baseUrls.map((url) => '$url/api/mobile/auth/refresh/');
  static Iterable<String> get meUrls =>
      baseUrls.map((url) => '$url/api/mobile/auth/me/');
  static Iterable<String> get changePasswordUrls =>
      baseUrls.map((url) => '$url/api/mobile/auth/password/');
  static Iterable<String> get feeDetailsUrls =>
      baseUrls.map((url) => '$url/api/mobile/fees/');
  static Iterable<String> get feeSummaryUrls =>
      baseUrls.map((url) => '$url/api/mobile/fees/summary/');
  static Iterable<String> get feeInvoicesUrls =>
      baseUrls.map((url) => '$url/api/mobile/fees/invoices/');
  static Iterable<String> get feeBreakupUrls =>
      baseUrls.map((url) => '$url/api/mobile/fees/breakup/');
  static Iterable<String> get feePaymentsUrls =>
      baseUrls.map((url) => '$url/api/mobile/fees/payments/');
  static Iterable<String> get mobileHealthUrls =>
      baseUrls.map((url) => '$url/api/mobile/health/');
  static Iterable<String> get studentProfileUrls =>
      baseUrls.map((url) => '$url/api/mobile/profile/');
  static Iterable<String> get studentBootstrapUrls =>
      baseUrls.map((url) => '$url/api/mobile/bootstrap/');
  static Iterable<String> get attendanceUrls =>
      baseUrls.map((url) => '$url/api/mobile/attendance/');
  static Iterable<String> get homeworkPlannerUrls =>
      baseUrls.map((url) => '$url/api/mobile/homework/');
  static Iterable<String> get examsUrls =>
      baseUrls.map((url) => '$url/api/mobile/exams/');
  static Iterable<String> examStartUrls(int examId) =>
      baseUrls.map((url) => '$url/api/mobile/exams/$examId/start/');
  static Iterable<String> examSubmitUrls(int attemptId) =>
      baseUrls.map((url) => '$url/api/mobile/exam-attempts/$attemptId/submit/');
  static Iterable<String> examRoughWorkUploadUrls(int attemptId) => baseUrls
      .map((url) => '$url/api/mobile/exam-attempts/$attemptId/rough-work/');
  static Iterable<String> examRoughWorkDeleteUrls({
    required int attemptId,
    required int uploadId,
  }) => baseUrls.map(
    (url) => '$url/api/mobile/exam-attempts/$attemptId/rough-work/$uploadId/',
  );
  static Iterable<String> examResultUrls(int attemptId) =>
      baseUrls.map((url) => '$url/api/mobile/exam-attempts/$attemptId/result/');
  static Iterable<String> get noticesUrls =>
      baseUrls.map((url) => '$url/api/mobile/notices/');
  static Iterable<String> noticeDetailUrls(int noticeId) =>
      baseUrls.map((url) => '$url/api/mobile/notices/$noticeId/');
  static Iterable<String> get registerDeviceUrls =>
      baseUrls.map((url) => '$url/api/mobile/devices/register/');
  static Iterable<String> get unregisterDeviceUrls =>
      baseUrls.map((url) => '$url/api/mobile/devices/unregister/');
  static Iterable<String> get notificationsUrls =>
      baseUrls.map((url) => '$url/api/mobile/notifications/');
  static Iterable<String> get notificationReadUrls =>
      baseUrls.map((url) => '$url/api/mobile/notifications/read/');
  static Iterable<String> get pushStatusUrls =>
      baseUrls.map((url) => '$url/api/mobile/push/status/');

  static List<String> get _debugBaseUrls {
    final localUrl = _localBaseUrl.isNotEmpty
        ? _normalizeBaseUrl(_localBaseUrl)
        : _defaultLocalBaseUrl;
    return _uniqueBaseUrls([localUrl, defaultBaseUrl]);
  }

  static String get _defaultLocalBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static List<String> _splitBaseUrls(String value) {
    return _uniqueBaseUrls(
      value
          .split(',')
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .map(_normalizeBaseUrl),
    );
  }

  static List<String> _uniqueBaseUrls(Iterable<String> urls) {
    final seen = <String>{};
    return [
      for (final url in urls)
        if (seen.add(url)) url,
    ];
  }

  static String _normalizeBaseUrl(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
