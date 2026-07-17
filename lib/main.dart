import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/notifications/local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await _initializeFirebase();
  } catch (_) {
    // Firebase may already be initialized by the native layer.
  }
}

Future<bool> _initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) {
    return true;
  }
  if (!kIsWeb) {
    await Firebase.initializeApp();
    return true;
  }
  if (!AppConfig.hasFirebaseWebConfig) {
    debugPrint(
      'Firebase Web config is not set; push notifications are disabled for this build.',
    );
    return false;
  }
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: AppConfig.firebaseWebApiKey,
      appId: AppConfig.firebaseWebAppId,
      messagingSenderId: AppConfig.firebaseWebMessagingSenderId,
      projectId: AppConfig.firebaseWebProjectId,
      authDomain: AppConfig.firebaseWebAuthDomain,
      storageBucket: AppConfig.firebaseWebStorageBucket,
    ),
  );
  return true;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final firebaseReady = await _initializeFirebase();
    if (firebaseReady) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      await LocalNotificationService.initialize();
    }
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
    // Firebase is configured per environment; the app can still run without push.
  }
  runApp(const ProviderScope(child: UltraCoachMatrixApp()));
}
