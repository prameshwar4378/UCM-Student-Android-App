import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/exam_model.dart';

class ExamApiService {
  const ExamApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<ExamListModel> fetchExams({int? academicSessionId}) async {
    DioException? lastError;
    for (final url in AppConfig.examsUrls) {
      try {
        final data = await _apiClient.getCachedJsonMap(
          url,
          queryParameters: {'academic_session_id': ?academicSessionId},
          options: _jsonOptions(),
          ttl: const Duration(minutes: 1),
        );
        return ExamListModel.fromJson(data);
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldTryNextHost(error)) {
          throw _apiClient.handleDioException(error);
        }
      }
    }
    if (lastError != null) {
      throw _apiClient.handleDioException(lastError);
    }
    throw const ApiException('Unable to load exams.');
  }

  Future<ExamAttemptModel> startExam(
    int examId, {
    int? academicSessionId,
  }) async {
    DioException? lastError;
    for (final url in AppConfig.examStartUrls(examId)) {
      try {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          url,
          data: {'academic_session_id': ?academicSessionId},
          options: _jsonOptions(),
        );
        return ExamAttemptModel.fromJson(response.data ?? const {});
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldTryNextHost(error)) {
          throw _apiClient.handleDioException(error);
        }
      }
    }
    if (lastError != null) {
      throw _apiClient.handleDioException(lastError);
    }
    throw const ApiException('Unable to start exam.');
  }

  Future<ExamSubmitResponseModel> submitExam({
    required int attemptId,
    required Map<int, int> answers,
    required List<ExamActivityEventModel> activities,
  }) async {
    DioException? lastError;
    final data = {
      'answers': answers.entries
          .map((entry) => {'question_id': entry.key, 'option_id': entry.value})
          .toList(),
      'activities': activities.map((event) => event.toJson()).toList(),
    };
    for (final url in AppConfig.examSubmitUrls(attemptId)) {
      try {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          url,
          data: data,
          options: _jsonOptions(),
        );
        _apiClient.clearGetCache(contains: '/api/mobile/exams/');
        return ExamSubmitResponseModel.fromJson(response.data ?? const {});
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldTryNextHost(error)) {
          throw _apiClient.handleDioException(error);
        }
      }
    }
    if (lastError != null) {
      throw _apiClient.handleDioException(lastError);
    }
    throw const ApiException('Unable to submit exam.');
  }

  Future<ExamRoughWorkUploadModel> uploadRoughWork({
    required int attemptId,
    required int questionId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    DioException? lastError;
    for (final url in AppConfig.examRoughWorkUploadUrls(attemptId)) {
      try {
        final formData = FormData.fromMap({
          'question_id': questionId.toString(),
          'image': MultipartFile.fromBytes(
            bytes,
            filename: fileName.trim().isEmpty ? 'rough-work.jpg' : fileName,
            contentType: _imageMediaType(fileName),
          ),
        });
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          url,
          data: formData,
          options: _multipartOptions(),
        );
        return ExamRoughWorkUploadModel.fromJson(response.data ?? const {});
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldTryNextHost(error)) {
          throw _apiClient.handleDioException(error);
        }
      }
    }
    if (lastError != null) {
      throw _apiClient.handleDioException(lastError);
    }
    throw const ApiException('Unable to upload rough-work image.');
  }

  Future<void> deleteRoughWork({
    required int attemptId,
    required int uploadId,
  }) async {
    DioException? lastError;
    for (final url in AppConfig.examRoughWorkDeleteUrls(
      attemptId: attemptId,
      uploadId: uploadId,
    )) {
      try {
        await _apiClient.dio.delete<Map<String, dynamic>>(
          url,
          options: _jsonOptions(),
        );
        return;
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldTryNextHost(error)) {
          throw _apiClient.handleDioException(error);
        }
      }
    }
    if (lastError != null) {
      throw _apiClient.handleDioException(lastError);
    }
    throw const ApiException('Unable to delete rough-work image.');
  }

  Future<ExamResultReviewModel> fetchResultReview(int attemptId) async {
    DioException? lastError;
    for (final url in AppConfig.examResultUrls(attemptId)) {
      try {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          url,
          options: _jsonOptions(),
        );
        return ExamResultReviewModel.fromJson(response.data ?? const {});
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldTryNextHost(error)) {
          throw _apiClient.handleDioException(error);
        }
      }
    }
    if (lastError != null) {
      throw _apiClient.handleDioException(lastError);
    }
    throw const ApiException('Unable to load result.');
  }

  Options _jsonOptions() {
    return Options(
      extra: {'requiresAuth': true},
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
    );
  }

  Options _multipartOptions() {
    return Options(
      contentType: Headers.multipartFormDataContentType,
      extra: {'requiresAuth': true},
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    );
  }

  MediaType _imageMediaType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return switch (extension) {
      'png' => MediaType('image', 'png'),
      'gif' => MediaType('image', 'gif'),
      'webp' => MediaType('image', 'webp'),
      'bmp' => MediaType('image', 'bmp'),
      'heic' => MediaType('image', 'heic'),
      'heif' => MediaType('image', 'heif'),
      _ => MediaType('image', 'jpeg'),
    };
  }

  bool _shouldTryNextHost(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError;
  }
}
