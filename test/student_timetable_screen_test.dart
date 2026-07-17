import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultracoachmatrix/features/student_parent/data/models/student_profile_model.dart';
import 'package:ultracoachmatrix/features/student_parent/presentation/providers/student_profile_provider.dart';
import 'package:ultracoachmatrix/features/student_parent/presentation/screens/student_timetable_screen.dart';

void main() {
  final profile = StudentProfileModel.fromJson({
    'student': {
      'id': 1,
      'name': 'Student One',
      'username': 'student',
      'institute': {'name': 'Ultra Institute'},
      'is_active': true,
    },
    'active_session': {
      'id': 10,
      'academic_year': '2026-27',
      'status': 'ACTIVE',
    },
    'academic_sessions': [
      {'id': 10, 'academic_year': '2026-27', 'status': 'ACTIVE'},
    ],
    'enrollments': [
      {
        'id': 100,
        'academic_session_id': 10,
        'academic_year': '2026-27',
        'batch': {
          'id': 20,
          'name': 'Morning Science Foundation Batch',
          'weekly_timetable': {
            'monday': {'start': '09:00', 'end': '11:00'},
            'wednesday': {'start': '13:30', 'end': '15:00'},
          },
        },
        'courses': [
          {'id': 1, 'name': 'Mathematics'},
          {'id': 2, 'name': 'Science'},
        ],
        'status': 'ACTIVE',
      },
      {
        'id': 101,
        'academic_session_id': 10,
        'academic_year': '2026-27',
        'batch': {
          'id': 21,
          'name': 'Weekend Communication Skills',
          'weekly_timetable': {
            'saturday': {'start': '16:00', 'end': '18:00'},
          },
        },
        'courses': [
          {'id': 3, 'name': 'English Communication'},
        ],
        'status': 'ACTIVE',
      },
    ],
    'guardians': [],
    'documents': [],
  });

  Future<void> pumpTimetable(WidgetTester tester, {required Size size}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentProfileProvider.overrideWith((ref) async => profile),
          selectedAcademicSessionIdProvider.overrideWith((ref) => 10),
        ],
        child: const MaterialApp(
          home: Scaffold(
            backgroundColor: Color(0xFFEAF0FF),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: StudentTimetableScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows every enrolled batch on a narrow Android screen', (
    tester,
  ) async {
    await pumpTimetable(tester, size: const Size(320, 800));

    expect(find.text('Morning Science Foundation Batch'), findsOneWidget);
    expect(find.text('Weekend Communication Skills'), findsOneWidget);
    expect(find.text('9:00 AM – 11:00 AM'), findsOneWidget);
    expect(find.text('4:00 PM – 6:00 PM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out multiple batch schedules on a tablet', (tester) async {
    await pumpTimetable(tester, size: const Size(900, 1000));

    expect(find.text('2 of 2 scheduled'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('Saturday'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
