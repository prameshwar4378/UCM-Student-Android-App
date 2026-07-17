import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultracoachmatrix/core/widgets/app_notification.dart';

void main() {
  testWidgets('notification card stays readable on a narrow Android screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showAppNotification(
                  context,
                  title: 'Password updated',
                  message: 'Your password was updated successfully.',
                  type: AppNotificationType.success,
                ),
                child: const Text('Show notification'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show notification'));
    await tester.pump();

    expect(find.text('Password updated'), findsOneWidget);
    expect(
      find.text('Your password was updated successfully.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('message dialog presents long download details responsively', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppMessageDialog(
                context,
                title: 'Receipt downloaded',
                message: 'Saved locally in a long device download folder path.',
                type: AppNotificationType.success,
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Receipt downloaded'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
