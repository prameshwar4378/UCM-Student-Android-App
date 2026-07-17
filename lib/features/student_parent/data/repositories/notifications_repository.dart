import '../models/push_notification_model.dart';
import '../services/notifications_api_service.dart';

class NotificationsRepository {
  const NotificationsRepository(this._apiService);

  final NotificationsApiService _apiService;

  Future<PushNotificationFeedModel> fetchNotifications() {
    return _apiService.fetchNotifications();
  }

  Future<void> markRead(Map<String, dynamic> notificationData) {
    return _apiService.markRead(notificationData);
  }
}
