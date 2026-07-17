import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/exam_model.dart';
import '../../data/repositories/exam_repository.dart';
import '../../data/services/exam_api_service.dart';
import 'student_profile_provider.dart';

final examApiServiceProvider = Provider<ExamApiService>((ref) {
  return ExamApiService(ref.watch(apiClientProvider));
});

final examRepositoryProvider = Provider<ExamRepository>((ref) {
  return ExamRepository(ref.watch(examApiServiceProvider));
});

final examsProvider = FutureProvider<ExamListModel>((ref) async {
  final academicSessionId = await ref.watch(
    effectiveAcademicSessionIdProvider.future,
  );
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 2), link.close);
  ref.onDispose(timer.cancel);
  return ref
      .watch(examRepositoryProvider)
      .fetchExams(academicSessionId: academicSessionId)
      .timeout(const Duration(seconds: 12));
});

Future<void> refreshPublishedExams(WidgetRef ref) async {
  ref.read(apiClientProvider).clearGetCache(contains: '/api/mobile/exams/');
  final refreshed = ref.refresh(examsProvider.future);
  await refreshed;
}
