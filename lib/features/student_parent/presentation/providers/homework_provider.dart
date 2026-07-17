import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/homework_planner_model.dart';
import '../../data/repositories/homework_repository.dart';
import '../../data/services/homework_api_service.dart';
import 'student_profile_provider.dart';

final homeworkApiServiceProvider = Provider<HomeworkApiService>((ref) {
  return HomeworkApiService(ref.watch(apiClientProvider));
});

final homeworkRepositoryProvider = Provider<HomeworkRepository>((ref) {
  return HomeworkRepository(ref.watch(homeworkApiServiceProvider));
});

final homeworkPlannerProvider = FutureProvider<HomeworkPlannerModel>((
  ref,
) async {
  final academicSessionId = await ref.watch(
    effectiveAcademicSessionIdProvider.future,
  );
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 3), link.close);
  ref.onDispose(() {
    timer.cancel();
  });
  return ref
      .watch(homeworkRepositoryProvider)
      .fetchHomeworkPlanner(academicSessionId: academicSessionId)
      .timeout(const Duration(seconds: 12));
});

Future<void> refreshHomeworkPlanner(WidgetRef ref) async {
  ref.read(apiClientProvider).clearGetCache(contains: '/api/mobile/homework/');
  final refreshed = ref.refresh(homeworkPlannerProvider.future);
  await refreshed;
}
