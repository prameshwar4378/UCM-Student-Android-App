import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/services/attendance_api_service.dart';
import 'student_profile_provider.dart';

class AttendanceQuery {
  const AttendanceQuery({
    this.status = '',
    this.batchId = '',
    this.dateFrom = '',
    this.dateTo = '',
    this.limit = 180,
  });

  factory AttendanceQuery.recent30Days() {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 29));
    return AttendanceQuery(
      dateFrom: _attendanceDateParam(start),
      dateTo: _attendanceDateParam(today),
      limit: 180,
    );
  }

  final String status;
  final String batchId;
  final String dateFrom;
  final String dateTo;
  final int limit;

  AttendanceQuery copyWith({
    String? status,
    String? batchId,
    String? dateFrom,
    String? dateTo,
    int? limit,
  }) {
    return AttendanceQuery(
      status: status ?? this.status,
      batchId: batchId ?? this.batchId,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AttendanceQuery &&
        other.status == status &&
        other.batchId == batchId &&
        other.dateFrom == dateFrom &&
        other.dateTo == dateTo &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(status, batchId, dateFrom, dateTo, limit);
}

final attendanceApiServiceProvider = Provider<AttendanceApiService>((ref) {
  return AttendanceApiService(ref.watch(apiClientProvider));
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(attendanceApiServiceProvider));
});

final attendanceQueryProvider = StateProvider<AttendanceQuery>((ref) {
  return AttendanceQuery.recent30Days();
});

final attendanceProvider = FutureProvider<AttendanceModel>((ref) async {
  final query = ref.watch(attendanceQueryProvider);
  final academicSessionId = await ref.watch(
    effectiveAcademicSessionIdProvider.future,
  );
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 3), link.close);
  ref.onDispose(() {
    timer.cancel();
  });
  return ref
      .watch(attendanceRepositoryProvider)
      .fetchAttendance(
        academicSessionId: academicSessionId,
        status: query.status,
        batchId: query.batchId,
        dateFrom: query.dateFrom,
        dateTo: query.dateTo,
        limit: query.limit,
      )
      .timeout(const Duration(seconds: 12));
});

String _attendanceDateParam(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
