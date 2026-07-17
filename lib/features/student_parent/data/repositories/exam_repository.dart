import 'dart:typed_data';

import '../models/exam_model.dart';
import '../services/exam_api_service.dart';

class ExamRepository {
  const ExamRepository(this._examApiService);

  final ExamApiService _examApiService;

  Future<ExamListModel> fetchExams({int? academicSessionId}) {
    return _examApiService.fetchExams(academicSessionId: academicSessionId);
  }

  Future<ExamAttemptModel> startExam(int examId, {int? academicSessionId}) {
    return _examApiService.startExam(
      examId,
      academicSessionId: academicSessionId,
    );
  }

  Future<ExamSubmitResponseModel> submitExam({
    required int attemptId,
    required Map<int, int> answers,
    required List<ExamActivityEventModel> activities,
  }) {
    return _examApiService.submitExam(
      attemptId: attemptId,
      answers: answers,
      activities: activities,
    );
  }

  Future<ExamRoughWorkUploadModel> uploadRoughWork({
    required int attemptId,
    required int questionId,
    required Uint8List bytes,
    required String fileName,
  }) {
    return _examApiService.uploadRoughWork(
      attemptId: attemptId,
      questionId: questionId,
      bytes: bytes,
      fileName: fileName,
    );
  }

  Future<void> deleteRoughWork({
    required int attemptId,
    required int uploadId,
  }) {
    return _examApiService.deleteRoughWork(
      attemptId: attemptId,
      uploadId: uploadId,
    );
  }

  Future<ExamResultReviewModel> fetchResultReview(int attemptId) {
    return _examApiService.fetchResultReview(attemptId);
  }
}
