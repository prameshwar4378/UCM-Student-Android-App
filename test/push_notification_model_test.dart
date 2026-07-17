import 'package:flutter_test/flutter_test.dart';
import 'package:ultracoachmatrix/features/student_parent/data/models/push_notification_model.dart';

void main() {
  test('notification feed merges top-level content into detail payload', () {
    final feed = PushNotificationFeedModel.fromJson({
      'summary': {'total_count': 1, 'unread_count': 1},
      'notifications': [
        {
          'id': 9,
          'type': 'NOTICE',
          'title': 'Holiday notice',
          'body': 'Institute is closed tomorrow.',
          'status': 'SENT',
          'created_at': '2026-06-15T10:00:00Z',
          'sent_at': '2026-06-15T10:00:01Z',
          'is_read': false,
          'read_at': null,
          'data': {'notice_id': '41', 'route': 'notices'},
        },
      ],
    });

    final detail = feed.notifications.single.detailData;
    expect(detail['notice_id'], '41');
    expect(detail['title'], 'Holiday notice');
    expect(detail['body'], 'Institute is closed tomorrow.');
    expect(detail['type'], 'NOTICE');
    expect(feed.totalCount, 1);
    expect(feed.unreadCount, 1);
    expect(feed.notifications.single.isRead, isFalse);
  });
}
