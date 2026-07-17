import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static const channelId = 'ultracoachmatrix_notifications';
  static const channelName = 'Ultra Coach Matrix notifications';
  static const channelDescription =
      'Fees, notices, exams, results, attendance, and other institute updates.';
  static const downloadChannelId = 'ultracoachmatrix_downloads';
  static const downloadChannelName = 'Ultra Coach Matrix downloads';
  static const downloadChannelDescription =
      'Download progress and completed files.';
  static const _downloadType = 'download_open';
  static const MethodChannel _downloadChannel = MethodChannel(
    'ultracoachmatrix.in/downloads',
  );

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final StreamController<Map<String, dynamic>> _openedController =
      StreamController<Map<String, dynamic>>.broadcast();
  static var _initialized = false;
  static Map<String, dynamic>? _pendingLaunchPayload;

  static Stream<Map<String, dynamic>> get openedNotifications =>
      _openedController.stream;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notification'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingLaunchPayload = _decodePayload(
        launchDetails?.notificationResponse?.payload,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      const channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      const downloadChannel = AndroidNotificationChannel(
        downloadChannelId,
        downloadChannelName,
        description: downloadChannelDescription,
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
      );
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(downloadChannel);
      await androidPlugin?.requestNotificationsPermission();
    }
    _initialized = true;
  }

  static int nextDownloadNotificationId() {
    return DateTime.now().microsecondsSinceEpoch.remainder(2147483647);
  }

  static Future<int?> showDownloadStarted({
    required String fileName,
    int? notificationId,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    await initialize();
    final id = notificationId ?? nextDownloadNotificationId();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        downloadChannelId,
        downloadChannelName,
        channelDescription: downloadChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notification',
        category: AndroidNotificationCategory.progress,
        visibility: NotificationVisibility.public,
        onlyAlertOnce: true,
        showProgress: true,
        indeterminate: true,
        ongoing: true,
        autoCancel: false,
      ),
    );
    await _plugin.show(
      id: id,
      title: 'Downloading...',
      body: fileName,
      notificationDetails: details,
      payload: jsonEncode({'type': _downloadType}),
    );
    return id;
  }

  static Future<void> showDownloadedFile({
    required String filePath,
    required String fileName,
    int? notificationId,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await initialize();
    await _scanDownloadedFile(filePath);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        downloadChannelId,
        downloadChannelName,
        channelDescription: downloadChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notification',
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.public,
        onlyAlertOnce: true,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(
          'Saved in Downloads. Tap to open.',
          contentTitle: fileName,
          summaryText: 'Download complete',
        ),
      ),
    );
    await _plugin.show(
      id: notificationId ?? nextDownloadNotificationId(),
      title: fileName,
      body: 'Saved in Downloads. Tap to open.',
      notificationDetails: details,
      payload: jsonEncode({
        'type': _downloadType,
        'file_path': filePath,
        'file_name': fileName,
      }),
    );
  }

  static Future<void> showDownloadFailed({
    required String fileName,
    required String message,
    int? notificationId,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await initialize();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        downloadChannelId,
        downloadChannelName,
        channelDescription: downloadChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notification',
        visibility: NotificationVisibility.public,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(message),
      ),
    );
    await _plugin.show(
      id: notificationId ?? nextDownloadNotificationId(),
      title: 'Download failed',
      body: fileName,
      notificationDetails: details,
    );
  }

  static Map<String, dynamic>? takePendingLaunchPayload() {
    final payload = _pendingLaunchPayload;
    _pendingLaunchPayload = null;
    return payload;
  }

  static Future<void> showForegroundMessage(RemoteMessage message) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await initialize();

    final notification = message.notification;
    final title =
        notification?.title ??
        message.data['title']?.toString() ??
        'Notification';
    final body = notification?.body ?? message.data['body']?.toString() ?? '';
    if (title.isEmpty && body.isEmpty) {
      return;
    }

    final type = _normalizedType(message.data['type']);
    final accentColor = _accentColor(type);
    final sectionLabel = _sectionLabel(type);
    final logo = await _largeLogo(message.data['institute_logo_url']);
    final instituteName = message.data['institute_name']?.toString().trim();
    final summaryTitle = instituteName == null || instituteName.isEmpty
        ? title
        : '$instituteName • $title';
    final importantLine = _importantLine(message.data, type);
    final displayBody = importantLine.isEmpty ? body : '$importantLine\n$body';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: 'ic_stat_notification',
        largeIcon: logo,
        color: accentColor,
        colorized: false,
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.public,
        subText: sectionLabel,
        ticker: summaryTitle,
        styleInformation: BigTextStyleInformation(
          displayBody,
          contentTitle: summaryTitle,
          summaryText: 'Ultra Coach Matrix | $sectionLabel',
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: summaryTitle,
      body: displayBody,
      notificationDetails: details,
      payload: jsonEncode(_messagePayload(message)),
    );
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    final payload = _decodePayload(response.payload);
    if (payload != null) {
      if (payload['type'] == _downloadType) {
        final path = payload['file_path']?.toString() ?? '';
        if (path.isNotEmpty) {
          unawaited(openDownloadedFile(path));
        }
        return;
      }
      _openedController.add(payload);
    }
  }

  static Future<void> openDownloadedFile(String filePath) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _downloadChannel.invokeMethod<void>('openFile', {
        'path': filePath,
        'mimeType': _mimeTypeFromFileName(filePath),
      });
    } on PlatformException catch (error) {
      debugPrint('Unable to open downloaded file: ${error.message}');
    }
  }

  static Future<void> _scanDownloadedFile(String filePath) async {
    try {
      await _downloadChannel.invokeMethod<void>('scanFile', {'path': filePath});
    } on PlatformException catch (error) {
      debugPrint('Unable to scan downloaded file: ${error.message}');
    }
  }

  static Map<String, dynamic> _messagePayload(RemoteMessage message) {
    return {
      ...message.data,
      'title': ?message.notification?.title,
      'body': ?message.notification?.body,
      if (message.sentTime case final sentTime?)
        'created_at': sentTime.toIso8601String(),
    };
  }

  static Map<String, dynamic>? _decodePayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      return {'type': payload};
    }
    return null;
  }

  static String _normalizedType(Object? value) {
    return (value?.toString() ?? '').trim().toUpperCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
  }

  static Color _accentColor(String type) {
    if (type.contains('FEE') || type.contains('PAYMENT')) {
      return const Color(0xFF16A34A);
    }
    if (type.contains('NOTICE')) {
      return const Color(0xFFE11D48);
    }
    if (type.contains('RESULT') || type.contains('EXAM')) {
      return const Color(0xFF7C3AED);
    }
    return const Color(0xFF0700A8);
  }

  static String _sectionLabel(String type) {
    if (type.contains('FEE') || type.contains('PAYMENT')) {
      return 'Fees and receipts';
    }
    if (type.contains('NOTICE')) {
      return 'Institute notice';
    }
    if (type.contains('RESULT')) {
      return 'Academic result';
    }
    if (type.contains('EXAM')) {
      return 'Examination update';
    }
    return 'Student update';
  }

  static String _mimeTypeFromFileName(String value) {
    final extension = value
        .split('?')
        .first
        .split('#')
        .first
        .split('.')
        .last
        .toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'html' || 'htm' => 'text/html',
      'csv' => 'text/csv',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => '*/*',
    };
  }

  static String _importantLine(Map<String, dynamic> data, String type) {
    if (type.contains('FEE') || type.contains('PAYMENT')) {
      final amount = data['amount']?.toString().trim() ?? '';
      final receipt = data['receipt_number']?.toString().trim() ?? '';
      if (amount.isNotEmpty && receipt.isNotEmpty) {
        return 'Amount: Rs. $amount • Receipt: $receipt';
      }
      if (amount.isNotEmpty) {
        return 'Amount: Rs. $amount';
      }
    }
    if (type.contains('RESULT')) {
      final marks = data['marks_obtained']?.toString().trim() ?? '';
      final total = data['total_marks']?.toString().trim() ?? '';
      if (marks.isNotEmpty && total.isNotEmpty) {
        return 'Marks: $marks / $total';
      }
    }
    return '';
  }

  static Future<ByteArrayAndroidBitmap?> _largeLogo(Object? value) async {
    final url = value?.toString().trim() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return null;
    }
    try {
      final bytes = await NetworkAssetBundle(
        uri,
      ).load(uri.toString()).timeout(const Duration(seconds: 4));
      return ByteArrayAndroidBitmap(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
