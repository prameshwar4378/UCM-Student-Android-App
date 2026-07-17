class AttendanceModel {
  const AttendanceModel({
    required this.student,
    required this.filters,
    required this.summary,
    required this.statusChoices,
    required this.batchWise,
    required this.records,
  });

  final AttendanceStudentModel student;
  final AttendanceFiltersModel filters;
  final AttendanceSummaryModel summary;
  final List<AttendanceStatusChoiceModel> statusChoices;
  final List<AttendanceBatchSummaryModel> batchWise;
  final List<AttendanceRecordModel> records;

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      student: AttendanceStudentModel.fromJson(_map(json['student'])),
      filters: AttendanceFiltersModel.fromJson(_map(json['filters'])),
      summary: AttendanceSummaryModel.fromJson(_map(json['summary'])),
      statusChoices: _list(
        json['status_choices'],
      ).map(AttendanceStatusChoiceModel.fromJson).toList(),
      batchWise: _list(
        json['batch_wise'],
      ).map(AttendanceBatchSummaryModel.fromJson).toList(),
      records: _list(
        json['records'],
      ).map(AttendanceRecordModel.fromJson).toList(),
    );
  }
}

class AttendanceStudentModel {
  const AttendanceStudentModel({
    required this.id,
    required this.username,
    required this.name,
    required this.admissionNumber,
  });

  final int id;
  final String username;
  final String name;
  final String admissionNumber;

  factory AttendanceStudentModel.fromJson(Map<String, dynamic> json) {
    return AttendanceStudentModel(
      id: _int(json['id']),
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      admissionNumber: json['admission_number'] as String? ?? '',
    );
  }
}

class AttendanceFiltersModel {
  const AttendanceFiltersModel({
    required this.dateFrom,
    required this.dateTo,
    required this.status,
    required this.batchId,
    required this.limit,
  });

  final String dateFrom;
  final String dateTo;
  final String status;
  final String batchId;
  final int limit;

  factory AttendanceFiltersModel.fromJson(Map<String, dynamic> json) {
    return AttendanceFiltersModel(
      dateFrom: json['date_from'] as String? ?? '',
      dateTo: json['date_to'] as String? ?? '',
      status: json['status'] as String? ?? '',
      batchId: json['batch_id']?.toString() ?? '',
      limit: _int(json['limit']),
    );
  }
}

class AttendanceSummaryModel {
  const AttendanceSummaryModel({
    required this.totalCount,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.attendedCount,
    required this.attendanceRate,
    required this.presentRate,
  });

  final int totalCount;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int attendedCount;
  final double attendanceRate;
  final double presentRate;

  factory AttendanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSummaryModel(
      totalCount: _int(json['total_count']),
      presentCount: _int(json['present_count']),
      absentCount: _int(json['absent_count']),
      lateCount: _int(json['late_count']),
      attendedCount: _int(json['attended_count']),
      attendanceRate: _double(json['attendance_rate']),
      presentRate: _double(json['present_rate']),
    );
  }
}

class AttendanceStatusChoiceModel {
  const AttendanceStatusChoiceModel({required this.value, required this.label});

  final String value;
  final String label;

  factory AttendanceStatusChoiceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceStatusChoiceModel(
      value: json['value'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class AttendanceBatchSummaryModel {
  const AttendanceBatchSummaryModel({
    required this.id,
    required this.name,
    required this.academicYear,
    required this.totalCount,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.attendanceRate,
  });

  final int id;
  final String name;
  final String academicYear;
  final int totalCount;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final double attendanceRate;

  factory AttendanceBatchSummaryModel.fromJson(Map<String, dynamic> json) {
    return AttendanceBatchSummaryModel(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
      academicYear: json['academic_year'] as String? ?? '',
      totalCount: _int(json['total_count']),
      presentCount: _int(json['present_count']),
      absentCount: _int(json['absent_count']),
      lateCount: _int(json['late_count']),
      attendanceRate: _double(json['attendance_rate']),
    );
  }
}

class AttendanceRecordModel {
  const AttendanceRecordModel({
    required this.id,
    required this.date,
    required this.status,
    required this.statusLabel,
    required this.note,
    required this.batch,
    required this.academicSession,
    required this.markedBy,
  });

  final int id;
  final String date;
  final String status;
  final String statusLabel;
  final String note;
  final AttendanceRecordBatchModel batch;
  final AttendanceAcademicSessionModel academicSession;
  final String markedBy;

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: _int(json['id']),
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusLabel: json['status_label'] as String? ?? '',
      note: json['note'] as String? ?? '',
      batch: AttendanceRecordBatchModel.fromJson(_map(json['batch'])),
      academicSession: AttendanceAcademicSessionModel.fromJson(
        _map(json['academic_session']),
      ),
      markedBy: json['marked_by'] as String? ?? '',
    );
  }
}

class AttendanceRecordBatchModel {
  const AttendanceRecordBatchModel({
    required this.id,
    required this.name,
    required this.academicYear,
  });

  final int id;
  final String name;
  final String academicYear;

  factory AttendanceRecordBatchModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordBatchModel(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
      academicYear: json['academic_year'] as String? ?? '',
    );
  }
}

class AttendanceAcademicSessionModel {
  const AttendanceAcademicSessionModel({
    required this.id,
    required this.admissionNumber,
    required this.academicYear,
  });

  final int id;
  final String admissionNumber;
  final String academicYear;

  factory AttendanceAcademicSessionModel.fromJson(Map<String, dynamic> json) {
    return AttendanceAcademicSessionModel(
      id: _int(json['id']),
      admissionNumber: json['admission_number'] as String? ?? '',
      academicYear: json['academic_year'] as String? ?? '',
    );
  }
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
