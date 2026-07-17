import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/student_bootstrap_model.dart';
import '../../data/services/student_bootstrap_api_service.dart';

final studentBootstrapApiServiceProvider = Provider<StudentBootstrapApiService>(
  (ref) {
    return StudentBootstrapApiService(ref.watch(apiClientProvider));
  },
);

final studentBootstrapProvider =
    FutureProvider.family<StudentBootstrapModel, int?>((ref, sessionId) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 3), link.close);
      ref.onDispose(timer.cancel);
      return ref
          .watch(studentBootstrapApiServiceProvider)
          .fetchBootstrap(academicSessionId: sessionId)
          .timeout(const Duration(seconds: 14));
    });
