class StudentProfileModel {
  const StudentProfileModel({
    required this.student,
    required this.activeSession,
    required this.academicSessions,
    required this.enrollments,
    required this.guardians,
    required this.documents,
  });

  final StudentInfoModel student;
  final AcademicSessionModel? activeSession;
  final List<AcademicSessionModel> academicSessions;
  final List<StudentEnrollmentModel> enrollments;
  final List<GuardianModel> guardians;
  final List<StudentDocumentModel> documents;

  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    return StudentProfileModel(
      student: StudentInfoModel.fromJson(_map(json['student'])),
      activeSession: json['active_session'] == null
          ? null
          : AcademicSessionModel.fromJson(_map(json['active_session'])),
      academicSessions: _list(
        json['academic_sessions'],
      ).map(AcademicSessionModel.fromJson).toList(),
      enrollments: _list(
        json['enrollments'],
      ).map(StudentEnrollmentModel.fromJson).toList(),
      guardians: _list(json['guardians']).map(GuardianModel.fromJson).toList(),
      documents: _list(
        json['documents'],
      ).map(StudentDocumentModel.fromJson).toList(),
    );
  }
}

class StudentInfoModel {
  const StudentInfoModel({
    required this.id,
    required this.admissionNumber,
    required this.penNo,
    required this.apparId,
    required this.grNumber,
    required this.udiseNumber,
    required this.cast,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.instituteName,
    required this.instituteLogoUrl,
    required this.profileImageUrl,
    required this.dateOfBirth,
    required this.joinedOn,
    required this.address,
    required this.currentSchoolName,
    required this.currentSchoolAddress,
    required this.previousSchoolName,
    required this.previousClass,
    required this.isActive,
  });

  final int id;
  final String admissionNumber;
  final String penNo;
  final String apparId;
  final String grNumber;
  final String udiseNumber;
  final String cast;
  final String name;
  final String username;
  final String email;
  final String phone;
  final String instituteName;
  final String instituteLogoUrl;
  final String profileImageUrl;
  final String dateOfBirth;
  final String joinedOn;
  final String address;
  final String currentSchoolName;
  final String currentSchoolAddress;
  final String previousSchoolName;
  final String previousClass;
  final bool isActive;

  factory StudentInfoModel.fromJson(Map<String, dynamic> json) {
    final institute = _map(json['institute']);
    return StudentInfoModel(
      id: _int(json['id']),
      admissionNumber: json['admission_number'] as String? ?? '',
      penNo: json['pen_no'] as String? ?? '',
      apparId: json['appar_id'] as String? ?? '',
      grNumber: json['gr_number_udise'] as String? ?? '',
      udiseNumber: json['udise_number'] as String? ?? '',
      cast: json['cast'] as String? ?? '',
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      instituteName: institute['name'] as String? ?? '',
      instituteLogoUrl: institute['logo_url'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String? ?? '',
      dateOfBirth: json['date_of_birth'] as String? ?? '',
      joinedOn: json['joined_on'] as String? ?? '',
      address: json['address'] as String? ?? '',
      currentSchoolName: json['current_school_name'] as String? ?? '',
      currentSchoolAddress: json['current_school_address'] as String? ?? '',
      previousSchoolName: json['previous_school_name'] as String? ?? '',
      previousClass: json['previous_class'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}

class AcademicSessionModel {
  const AcademicSessionModel({
    required this.id,
    required this.admissionNumber,
    required this.academicYear,
    required this.status,
    required this.joinedOn,
    required this.currentSchoolName,
    required this.currentSchoolAddress,
    required this.previousSchoolName,
    required this.previousClass,
  });

  final int id;
  final String admissionNumber;
  final String academicYear;
  final String status;
  final String joinedOn;
  final String currentSchoolName;
  final String currentSchoolAddress;
  final String previousSchoolName;
  final String previousClass;

  factory AcademicSessionModel.fromJson(Map<String, dynamic> json) {
    return AcademicSessionModel(
      id: _int(json['id']),
      admissionNumber: json['admission_number'] as String? ?? '',
      academicYear: json['academic_year'] as String? ?? '',
      status: json['status'] as String? ?? '',
      joinedOn: json['joined_on'] as String? ?? '',
      currentSchoolName: json['current_school_name'] as String? ?? '',
      currentSchoolAddress: json['current_school_address'] as String? ?? '',
      previousSchoolName: json['previous_school_name'] as String? ?? '',
      previousClass: json['previous_class'] as String? ?? '',
    );
  }
}

class StudentEnrollmentModel {
  const StudentEnrollmentModel({
    required this.id,
    required this.academicSessionId,
    required this.academicYear,
    required this.batchId,
    required this.batchName,
    required this.weeklyTimetable,
    required this.courses,
    required this.totalCourseFee,
    required this.status,
    required this.enrolledOn,
  });

  final int id;
  final int academicSessionId;
  final String academicYear;
  final int batchId;
  final String batchName;
  final Map<String, TimetableSlotModel> weeklyTimetable;
  final List<String> courses;
  final double totalCourseFee;
  final String status;
  final String enrolledOn;

  factory StudentEnrollmentModel.fromJson(Map<String, dynamic> json) {
    final batch = _map(json['batch']);
    final timetable = _map(batch['weekly_timetable']);
    return StudentEnrollmentModel(
      id: _int(json['id']),
      academicSessionId: _int(json['academic_session_id']),
      academicYear: json['academic_year'] as String? ?? '',
      batchId: _int(batch['id']),
      batchName: batch['name'] as String? ?? '',
      weeklyTimetable: {
        for (final entry in timetable.entries)
          if (_map(entry.value).isNotEmpty)
            entry.key: TimetableSlotModel.fromJson(_map(entry.value)),
      },
      courses: _list(json['courses'])
          .map((course) => course['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList(),
      totalCourseFee: _double(json['total_course_fee']),
      status: json['status'] as String? ?? '',
      enrolledOn: json['enrolled_on'] as String? ?? '',
    );
  }
}

class TimetableSlotModel {
  const TimetableSlotModel({required this.start, required this.end});

  final String start;
  final String end;

  factory TimetableSlotModel.fromJson(Map<String, dynamic> json) {
    return TimetableSlotModel(
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
    );
  }
}

class GuardianModel {
  const GuardianModel({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
    required this.email,
    required this.isPrimary,
  });

  final int id;
  final String name;
  final String relation;
  final String phone;
  final String email;
  final bool isPrimary;

  factory GuardianModel.fromJson(Map<String, dynamic> json) {
    return GuardianModel(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
      relation: json['relation'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}

class StudentDocumentModel {
  const StudentDocumentModel({
    required this.id,
    required this.title,
    required this.documentType,
    required this.documentTypeDisplay,
    required this.fileUrl,
    required this.uploadedAt,
    required this.note,
  });

  final int id;
  final String title;
  final String documentType;
  final String documentTypeDisplay;
  final String fileUrl;
  final String uploadedAt;
  final String note;

  factory StudentDocumentModel.fromJson(Map<String, dynamic> json) {
    return StudentDocumentModel(
      id: _int(json['id']),
      title: json['title'] as String? ?? '',
      documentType: json['document_type'] as String? ?? '',
      documentTypeDisplay: json['document_type_display'] as String? ?? '',
      fileUrl: json['file_url'] as String? ?? '',
      uploadedAt: json['uploaded_at'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const {};
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

double _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '')) ?? 0;
  }
  return 0;
}
