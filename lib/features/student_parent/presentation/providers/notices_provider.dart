import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/notice_model.dart';
import '../../data/repositories/notices_repository.dart';
import '../../data/services/notices_api_service.dart';
import 'student_profile_provider.dart';

class NoticesQuery {
  const NoticesQuery({
    this.category = '',
    this.priority = '',
    this.unread = false,
    this.search = '',
    this.limit = 50,
  });

  final String category;
  final String priority;
  final bool unread;
  final String search;
  final int limit;

  NoticesQuery copyWith({
    String? category,
    String? priority,
    bool? unread,
    String? search,
    int? limit,
  }) {
    return NoticesQuery(
      category: category ?? this.category,
      priority: priority ?? this.priority,
      unread: unread ?? this.unread,
      search: search ?? this.search,
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NoticesQuery &&
        other.category == category &&
        other.priority == priority &&
        other.unread == unread &&
        other.search == search &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(category, priority, unread, search, limit);
}

final noticesApiServiceProvider = Provider<NoticesApiService>((ref) {
  return NoticesApiService(ref.watch(apiClientProvider));
});

final noticesRepositoryProvider = Provider<NoticesRepository>((ref) {
  return NoticesRepository(ref.watch(noticesApiServiceProvider));
});

final noticesQueryProvider = StateProvider<NoticesQuery>((ref) {
  return const NoticesQuery();
});

final noticesProvider = FutureProvider<NoticeBoardModel>((ref) async {
  final query = ref.watch(noticesQueryProvider);
  final academicSessionId = await ref.watch(
    effectiveAcademicSessionIdProvider.future,
  );
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 3), link.close);
  ref.onDispose(() {
    timer.cancel();
  });
  return ref
      .watch(noticesRepositoryProvider)
      .fetchNotices(
        academicSessionId: academicSessionId,
        category: query.category,
        priority: query.priority,
        unread: query.unread,
        search: query.search,
        limit: query.limit,
      )
      .timeout(const Duration(seconds: 12));
});
