import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultracoachmatrix/features/student_parent/presentation/screens/developer_details_screen.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: DeveloperDetailsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows developer details without overflow on narrow Android', (
    tester,
  ) async {
    await pumpPage(tester, const Size(320, 720));

    expect(find.text('Ultoxy Technologies'), findsOneWidget);
    expect(find.text('Rameshwar Pawar'), findsOneWidget);
    expect(find.text('7776824564'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows responsive developer details on tablet', (tester) async {
    await pumpPage(tester, const Size(900, 1000));

    expect(find.text('www.ultoxy.com'), findsOneWidget);
    expect(find.text('ultoxy.tech@gmail.com'), findsOneWidget);
    expect(find.text('Website'), findsWidgets);
    expect(find.text('Email'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
