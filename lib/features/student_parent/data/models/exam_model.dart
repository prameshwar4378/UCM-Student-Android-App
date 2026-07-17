class ExamListModel {
  const ExamListModel({required this.summary, required this.exams});

  final ExamSummaryModel summary;
  final List<ExamModel> exams;

  factory ExamListModel.fromJson(Map<String, dynamic> json) {
    return ExamListModel(
      summary: ExamSummaryModel.fromJson(_map(json['summary'])),
      exams: _list(json['exams']).map(ExamModel.fromJson).toList(),
    );
  }
}

class ExamSummaryModel {
  const ExamSummaryModel({
    required this.examCount,
    required this.submittedCount,
    required this.pendingCount,
  });

  final int examCount;
  final int submittedCount;
  final int pendingCount;

  factory ExamSummaryModel.fromJson(Map<String, dynamic> json) {
    return ExamSummaryModel(
      examCount: _int(json['exam_count']),
      submittedCount: _int(json['submitted_count']),
      pendingCount: _int(json['pending_count']),
    );
  }
}

class ExamModel {
  const ExamModel({
    required this.id,
    required this.title,
    required this.examDate,
    required this.durationMinutes,
    required this.totalMarks,
    required this.questionCount,
    required this.instructions,
    required this.showResultAfterSubmit,
    required this.allowRoughWorkUploads,
    required this.batch,
    required this.subject,
    required this.academicYear,
    required this.attempt,
  });

  final int id;
  final String title;
  final String examDate;
  final int durationMinutes;
  final int totalMarks;
  final int questionCount;
  final String instructions;
  final bool showResultAfterSubmit;
  final bool allowRoughWorkUploads;
  final ExamNamedModel batch;
  final ExamNamedModel subject;
  final ExamNamedModel academicYear;
  final ExamAttemptStatusModel attempt;

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    return ExamModel(
      id: _int(json['id']),
      title: json['title'] as String? ?? '',
      examDate: json['exam_date'] as String? ?? '',
      durationMinutes: _int(json['duration_minutes']),
      totalMarks: _int(json['total_marks']),
      questionCount: _int(json['question_count']),
      instructions: json['instructions'] as String? ?? '',
      showResultAfterSubmit: json['show_result_after_submit'] == true,
      allowRoughWorkUploads: json['allow_rough_work_uploads'] == true,
      batch: ExamNamedModel.fromJson(_map(json['batch'])),
      subject: ExamNamedModel.fromJson(_map(json['subject'])),
      academicYear: ExamNamedModel.fromJson(_map(json['academic_year'])),
      attempt: ExamAttemptStatusModel.fromJson(_map(json['attempt'])),
    );
  }
}

class ExamNamedModel {
  const ExamNamedModel({required this.id, required this.name});

  final int id;
  final String name;

  factory ExamNamedModel.fromJson(Map<String, dynamic> json) {
    return ExamNamedModel(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
    );
  }
}

class ExamAttemptStatusModel {
  const ExamAttemptStatusModel({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.submittedAt,
    required this.score,
    required this.totalMarks,
    required this.canViewResult,
  });

  final int? id;
  final String status;
  final String startedAt;
  final String submittedAt;
  final String score;
  final String totalMarks;
  final bool canViewResult;

  bool get isSubmitted => status == 'submitted';
  bool get isInProgress => status == 'in_progress';

  factory ExamAttemptStatusModel.fromJson(Map<String, dynamic> json) {
    return ExamAttemptStatusModel(
      id: _nullableInt(json['id']),
      status: json['status'] as String? ?? 'not_started',
      startedAt: json['started_at'] as String? ?? '',
      submittedAt: json['submitted_at'] as String? ?? '',
      score: json['score']?.toString() ?? '',
      totalMarks: json['total_marks']?.toString() ?? '',
      canViewResult: json['can_view_result'] == true,
    );
  }
}

class ExamAttemptModel {
  const ExamAttemptModel({
    required this.attemptId,
    required this.exam,
    required this.questions,
  });

  final int attemptId;
  final ExamModel exam;
  final List<ExamQuestionModel> questions;

  factory ExamAttemptModel.fromJson(Map<String, dynamic> json) {
    return ExamAttemptModel(
      attemptId: _int(_map(json['attempt'])['id']),
      exam: ExamModel.fromJson(_map(json['exam'])),
      questions: _list(
        json['questions'],
      ).map(ExamQuestionModel.fromJson).toList(),
    );
  }
}

class ExamQuestionModel {
  const ExamQuestionModel({
    required this.id,
    required this.text,
    required this.imageUrl,
    required this.marks,
    required this.order,
    required this.options,
    required this.roughWorkUploads,
  });

  final int id;
  final String text;
  final String imageUrl;
  final int marks;
  final int order;
  final List<ExamOptionModel> options;
  final List<ExamRoughWorkUploadModel> roughWorkUploads;

  factory ExamQuestionModel.fromJson(Map<String, dynamic> json) {
    return ExamQuestionModel(
      id: _int(json['id']),
      text: json['text'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      marks: _int(json['marks']),
      order: _int(json['order']),
      options: _list(json['options']).map(ExamOptionModel.fromJson).toList(),
      roughWorkUploads: _list(
        json['rough_work_uploads'],
      ).map(ExamRoughWorkUploadModel.fromJson).toList(),
    );
  }
}

class ExamOptionModel {
  const ExamOptionModel({
    required this.id,
    required this.text,
    required this.order,
  });

  final int id;
  final String text;
  final int order;

  factory ExamOptionModel.fromJson(Map<String, dynamic> json) {
    return ExamOptionModel(
      id: _int(json['id']),
      text: json['text'] as String? ?? '',
      order: _int(json['order']),
    );
  }
}

class ExamActivityEventModel {
  const ExamActivityEventModel({
    required this.eventType,
    required this.detail,
    required this.occurredAt,
  });

  final String eventType;
  final String detail;
  final DateTime occurredAt;

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'detail': detail,
      'occurred_at': occurredAt.toIso8601String(),
    };
  }
}

class ExamSubmitResponseModel {
  const ExamSubmitResponseModel({
    required this.score,
    required this.totalMarks,
    required this.correctCount,
    required this.wrongCount,
    required this.unattemptedCount,
    required this.canViewResult,
  });

  final String score;
  final String totalMarks;
  final int correctCount;
  final int wrongCount;
  final int unattemptedCount;
  final bool canViewResult;

  factory ExamSubmitResponseModel.fromJson(Map<String, dynamic> json) {
    final attempt = _map(json['attempt']);
    return ExamSubmitResponseModel(
      score: attempt['score']?.toString() ?? '0',
      totalMarks: attempt['total_marks']?.toString() ?? '0',
      correctCount: _int(attempt['correct_count']),
      wrongCount: _int(attempt['wrong_count']),
      unattemptedCount: _int(attempt['unattempted_count']),
      canViewResult: attempt['can_view_result'] == true,
    );
  }
}

class ExamResultReviewModel {
  const ExamResultReviewModel({
    required this.exam,
    required this.result,
    required this.questions,
  });

  final ExamModel exam;
  final ExamSubmitResponseModel result;
  final List<ExamReviewQuestionModel> questions;

  factory ExamResultReviewModel.fromJson(Map<String, dynamic> json) {
    return ExamResultReviewModel(
      exam: ExamModel.fromJson(_map(json['exam'])),
      result: ExamSubmitResponseModel.fromJson(json),
      questions: _list(
        json['questions'],
      ).map(ExamReviewQuestionModel.fromJson).toList(),
    );
  }
}

class ExamRoughWorkUploadModel {
  const ExamRoughWorkUploadModel({
    required this.id,
    required this.attemptId,
    required this.questionId,
    required this.imageUrl,
    required this.uploadedAt,
  });

  final int id;
  final int attemptId;
  final int? questionId;
  final String imageUrl;
  final String uploadedAt;

  factory ExamRoughWorkUploadModel.fromJson(Map<String, dynamic> json) {
    return ExamRoughWorkUploadModel(
      id: _int(json['id']),
      attemptId: _int(json['attempt_id']),
      questionId: _nullableInt(json['question_id']),
      imageUrl: json['image_url'] as String? ?? '',
      uploadedAt: json['uploaded_at'] as String? ?? '',
    );
  }
}

class ExamReviewQuestionModel {
  const ExamReviewQuestionModel({
    required this.id,
    required this.text,
    required this.imageUrl,
    required this.marks,
    required this.order,
    required this.selectedOptionId,
    required this.correctOptionId,
    required this.isCorrect,
    required this.marksAwarded,
    required this.options,
  });

  final int id;
  final String text;
  final String imageUrl;
  final int marks;
  final int order;
  final int? selectedOptionId;
  final int? correctOptionId;
  final bool isCorrect;
  final String marksAwarded;
  final List<ExamOptionModel> options;

  factory ExamReviewQuestionModel.fromJson(Map<String, dynamic> json) {
    return ExamReviewQuestionModel(
      id: _int(json['id']),
      text: json['text'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      marks: _int(json['marks']),
      order: _int(json['order']),
      selectedOptionId: _nullableInt(json['selected_option_id']),
      correctOptionId: _nullableInt(json['correct_option_id']),
      isCorrect: json['is_correct'] == true,
      marksAwarded: json['marks_awarded']?.toString() ?? '0',
      options: _list(json['options']).map(ExamOptionModel.fromJson).toList(),
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

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
