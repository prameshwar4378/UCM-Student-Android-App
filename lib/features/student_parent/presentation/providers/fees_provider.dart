import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/fee_details_model.dart';
import '../../data/repositories/fees_repository.dart';
import '../../data/services/fees_api_service.dart';
import 'student_profile_provider.dart';

final feesApiServiceProvider = Provider<FeesApiService>((ref) {
  return FeesApiService(ref.watch(apiClientProvider));
});

final feesRepositoryProvider = Provider<FeesRepository>((ref) {
  return FeesRepository(ref.watch(feesApiServiceProvider));
});

final feeDetailsProvider = FutureProvider<FeeDetailsModel>((ref) async {
  final academicSessionId = await ref.watch(
    effectiveAcademicSessionIdProvider.future,
  );
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 3), link.close);
  ref.onDispose(() {
    timer.cancel();
  });
  return ref
      .watch(feesRepositoryProvider)
      .fetchFeeDetails(academicSessionId: academicSessionId)
      .timeout(const Duration(seconds: 12));
});
