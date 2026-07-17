import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/push_notification_model.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../data/services/notifications_api_service.dart';

final notificationsApiServiceProvider = Provider<NotificationsApiService>((
  ref,
) {
  return NotificationsApiService(ref.watch(apiClientProvider));
});

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.watch(notificationsApiServiceProvider));
});

final notificationsProvider = FutureProvider<PushNotificationFeedModel>((
  ref,
) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 3), link.close);
  ref.onDispose(timer.cancel);
  return ref
      .watch(notificationsRepositoryProvider)
      .fetchNotifications()
      .timeout(const Duration(seconds: 12));
});

final optimisticallyReadNotificationIdsProvider = StateProvider<Set<int>>((
  ref,
) {
  return const {};
});
