class HomeworkPlannerModel {
  const HomeworkPlannerModel({
    required this.student,
    required this.summary,
    required this.documentDownloadUrl,
    required this.subjectWise,
    required this.batchWise,
    required this.homework,
  });

  final HomeworkStudentModel student;
  final HomeworkSummaryModel summary;
  final String documentDownloadUrl;
  final List<HomeworkSubjectGroupModel> subjectWise;
  final List<HomeworkBatchGroupModel> batchWise;
  final List<HomeworkItemModel> homework;

  int get courseCount {
    return homework
        .where((item) => item.course.id != 0 && item.course.name.isNotEmpty)
        .map((item) => item.course.id)
        .toSet()
        .length;
  }

  factory HomeworkPlannerModel.fromJson(Map<String, dynamic> json) {
    return HomeworkPlannerModel(
      student: HomeworkStudentModel.fromJson(_map(json['student'])),
      summary: HomeworkSummaryModel.fromJson(_map(json['summary'])),
      documentDownloadUrl: json['document_download_url'] as String? ?? '',
      subjectWise: _list(
        json['subject_wise'],
      ).map(HomeworkSubjectGroupModel.fromJson).toList(),
      batchWise: _list(
        json['batch_wise'],
      ).map(HomeworkBatchGroupModel.fromJson).toList(),
      homework: _list(
        json['homework'],
      ).map(HomeworkItemModel.fromJson).toList(),
    );
  }
}

class HomeworkStudentModel {
  const HomeworkStudentModel({
    required this.id,
    required this.admissionNumber,
    required this.name,
    required this.username,
    required this.instituteName,
  });

  final int id;
  final String admissionNumber;
  final String name;
  final String username;
  final String instituteName;

  factory HomeworkStudentModel.fromJson(Map<String, dynamic> json) {
    return HomeworkStudentModel(
      id: _int(json['id']),
      admissionNumber: json['admission_number'] as String? ?? '',
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      instituteName: _map(json['institute'])['name'] as String? ?? '',
    );
  }
}

class HomeworkSummaryModel {
  const HomeworkSummaryModel({
    required this.homeworkCount,
    required this.subjectCount,
    required this.batchCount,
  });

  final int homeworkCount;
  final int subjectCount;
  final int batchCount;

  factory HomeworkSummaryModel.fromJson(Map<String, dynamic> json) {
    return HomeworkSummaryModel(
      homeworkCount: _int(json['homework_count']),
      subjectCount: _int(json['subject_count']),
      batchCount: _int(json['batch_count']),
    );
  }
}

class HomeworkSubjectGroupModel {
  const HomeworkSubjectGroupModel({
    required this.id,
    required this.name,
    required this.homeworkCount,
    required this.items,
  });

  final int id;
  final String name;
  final int homeworkCount;
  final List<HomeworkItemModel> items;

  factory HomeworkSubjectGroupModel.fromJson(Map<String, dynamic> json) {
    return HomeworkSubjectGroupModel(
      id: _int(json['id']),
      name: json['name'] as String? ?? 'General',
      homeworkCount: _int(json['homework_count']),
      items: _list(json['items']).map(HomeworkItemModel.fromJson).toList(),
    );
  }
}

class HomeworkBatchGroupModel {
  const HomeworkBatchGroupModel({
    required this.id,
    required this.name,
    required this.academicYear,
    required this.homeworkCount,
  });

  final int id;
  final String name;
  final String academicYear;
  final int homeworkCount;

  factory HomeworkBatchGroupModel.fromJson(Map<String, dynamic> json) {
    return HomeworkBatchGroupModel(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
      academicYear: json['academic_year'] as String? ?? '',
      homeworkCount: _int(json['homework_count']),
    );
  }
}

class HomeworkItemModel {
  const HomeworkItemModel({
    required this.id,
    required this.title,
    required this.instructions,
    required this.dueDate,
    required this.createdAt,
    required this.teacherName,
    required this.batch,
    required this.subject,
    required this.course,
    required this.attachments,
  });

  final int id;
  final String title;
  final String instructions;
  final String dueDate;
  final String createdAt;
  final String teacherName;
  final HomeworkBatchModel batch;
  final HomeworkSubjectModel subject;
  final HomeworkCourseModel course;
  final List<HomeworkAttachmentModel> attachments;

  factory HomeworkItemModel.fromJson(Map<String, dynamic> json) {
    return HomeworkItemModel(
      id: _int(json['id']),
      title: json['title'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      dueDate: json['due_date'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      batch: HomeworkBatchModel.fromJson(_map(json['batch'])),
      subject: HomeworkSubjectModel.fromJson(_map(json['subject'])),
      course: HomeworkCourseModel.fromJson(_map(json['course'])),
      attachments: _list(
        json['attachments'],
      ).map(HomeworkAttachmentModel.fromJson).toList(),
    );
  }
}

class HomeworkBatchModel {
  const HomeworkBatchModel({
    required this.id,
    required this.name,
    required this.academicYear,
  });

  final int id;
  final String name;
  final String academicYear;

  factory HomeworkBatchModel.fromJson(Map<String, dynamic> json) {
    return HomeworkBatchModel(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
      academicYear: json['academic_year'] as String? ?? '',
    );
  }
}

class HomeworkSubjectModel {
  const HomeworkSubjectModel({required this.id, required this.name});

  final int id;
  final String name;

  factory HomeworkSubjectModel.fromJson(Map<String, dynamic> json) {
    return HomeworkSubjectModel(
      id: _int(json['id']),
      name: json['name'] as String? ?? 'General',
    );
  }
}

class HomeworkCourseModel {
  const HomeworkCourseModel({required this.id, required this.name});

  final int id;
  final String name;

  factory HomeworkCourseModel.fromJson(Map<String, dynamic> json) {
    return HomeworkCourseModel(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
    );
  }
}

class HomeworkAttachmentModel {
  const HomeworkAttachmentModel({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedAt,
  });

  final int id;
  final String fileName;
  final String fileUrl;
  final String uploadedAt;

  factory HomeworkAttachmentModel.fromJson(Map<String, dynamic> json) {
    return HomeworkAttachmentModel(
      id: _int(json['id']),
      fileName: json['file_name'] as String? ?? '',
      fileUrl: json['file_url'] as String? ?? '',
      uploadedAt: json['uploaded_at'] as String? ?? '',
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
