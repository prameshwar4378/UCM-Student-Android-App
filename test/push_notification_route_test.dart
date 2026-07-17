import 'package:flutter_test/flutter_test.dart';
import 'package:ultracoachmatrix/core/notifications/push_notification_route.dart';

void main() {
  test('routes fee notifications to the fees page', () {
    expect(
      notificationPageForData({'type': 'FEE_PAID'}),
      PushNotificationPage.fees,
    );
    expect(
      notificationPageForData({'route': 'fees'}),
      PushNotificationPage.fees,
    );
  });

  test('routes notices and results to their particular pages', () {
    expect(
      notificationPageForData({'type': 'NOTICE', 'notice_id': '12'}),
      PushNotificationPage.notices,
    );
    expect(
      notificationPageForData({'type': 'RESULT_DECLARED', 'result_id': '7'}),
      PushNotificationPage.results,
    );
  });

  test('uses the dashboard as a safe fallback', () {
    expect(
      notificationPageForData({'type': 'UNKNOWN_EVENT'}),
      PushNotificationPage.dashboard,
    );
  });
}
