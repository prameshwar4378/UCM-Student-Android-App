import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/student_profile_model.dart';
import '../../data/repositories/student_profile_repository.dart';
import '../../data/services/student_profile_api_service.dart';
import 'student_bootstrap_provider.dart';

final studentProfileApiServiceProvider = Provider<StudentProfileApiService>((
  ref,
) {
  return StudentProfileApiService(ref.watch(apiClientProvider));
});

final studentProfileRepositoryProvider = Provider<StudentProfileRepository>((
  ref,
) {
  return StudentProfileRepository(ref.watch(studentProfileApiServiceProvider));
});

final studentProfileProvider = FutureProvider<StudentProfileModel>((ref) async {
  final selectedSessionId = ref.watch(selectedAcademicSessionIdProvider);
  if (selectedSessionId == null) {
    return (await ref.watch(studentBootstrapProvider(null).future)).profile;
  }
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 3), link.close);
  ref.onDispose(timer.cancel);
  return ref
      .watch(studentProfileRepositoryProvider)
      .fetchProfile(academicSessionId: selectedSessionId)
      .timeout(const Duration(seconds: 12));
});

final selectedAcademicSessionIdProvider = StateProvider<int?>((ref) => null);

final effectiveAcademicSessionIdProvider = FutureProvider<int?>((ref) async {
  final selectedId = ref.watch(selectedAcademicSessionIdProvider);
  final profile = await ref.watch(studentProfileProvider.future);
  if (selectedId != null &&
      profile.academicSessions.any((session) => session.id == selectedId)) {
    return selectedId;
  }
  return profile.activeSession?.id ??
      (profile.academicSessions.isNotEmpty
          ? profile.academicSessions.first.id
          : null);
});
