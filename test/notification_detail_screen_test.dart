import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultracoachmatrix/core/notifications/notification_detail_screen.dart';

void main() {
  testWidgets('notice notification renders details and destination action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationDetailScreen(
          data: const {
            'type': 'NOTICE',
            'title': 'Holiday schedule',
            'body': 'The institute will remain closed tomorrow.',
            'category_label': 'Announcement',
            'priority_label': 'High',
          },
          onOpenSection: () {},
        ),
      ),
    );

    expect(find.text('Notification details'), findsOneWidget);
    expect(find.text('Holiday schedule'), findsOneWidget);
    expect(
      find.text('The institute will remain closed tomorrow.'),
      findsOneWidget,
    );
    expect(find.text('Announcement'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Open Notice Board'), findsOneWidget);
  });

  testWidgets('notice notification hydrates the full server message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationDetailScreen(
          data: const {
            'type': 'NOTICE',
            'notice_id': '12',
            'title': 'Preview title',
          },
          loadDetails: () async => {
            'title': 'Complete notice',
            'body': 'This is the complete notice body from the API.',
          },
          onOpenSection: () {},
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Complete notice'), findsOneWidget);
    expect(
      find.text('This is the complete notice body from the API.'),
      findsOneWidget,
    );
  });
}
