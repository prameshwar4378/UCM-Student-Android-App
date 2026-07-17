import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/student_profile_model.dart';

class StudentProfileApiService {
  const StudentProfileApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<StudentProfileModel> fetchProfile({int? academicSessionId}) async {
    DioException? lastError;
    for (final url in AppConfig.studentProfileUrls) {
      try {
        final data = await _apiClient.getCachedJsonMap(
          url,
          queryParameters: {'academic_session_id': ?academicSessionId},
          options: Options(
            extra: {'requiresAuth': true},
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 8),
          ),
          ttl: const Duration(seconds: 45),
        );
        return StudentProfileModel.fromJson(data);
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
    throw const ApiException('Unable to connect to the server.');
  }

  Future<StudentDocumentFile> downloadDocument(String url) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        url,
        options: Options(
          extra: {'requiresAuth': true},
          responseType: ResponseType.bytes,
          headers: const {'Accept': '*/*'},
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw const ApiException('The document file is empty.');
      }
      return StudentDocumentFile(
        bytes: Uint8List.fromList(data),
        fileName: _fileNameFromResponse(response, url),
        contentType: response.headers.value('content-type') ?? '',
      );
    } on DioException catch (error) {
      throw _apiClient.handleDioException(error);
    }
  }

  bool _shouldTryNextHost(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError;
  }
}

class StudentDocumentFile {
  const StudentDocumentFile({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

String _fileNameFromResponse(Response<dynamic> response, String url) {
  final disposition = response.headers.value('content-disposition') ?? '';
  final match = RegExp(
    r'''filename\*?=(?:UTF-8'')?["']?([^"';]+)''',
    caseSensitive: false,
  ).firstMatch(disposition);
  final fromHeader = match == null ? '' : Uri.decodeComponent(match.group(1)!);
  if (fromHeader.trim().isNotEmpty) {
    return _safeFileName(fromHeader);
  }

  final parsed = Uri.tryParse(url);
  final segment = parsed?.pathSegments.isEmpty == false
      ? parsed!.pathSegments.last
      : '';
  if (segment.trim().isNotEmpty) {
    return _safeFileName(Uri.decodeComponent(segment));
  }

  return 'document';
}

String _safeFileName(String value) {
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
      .replaceAll(RegExp(r'\s+'), ' ');
  return cleaned.isEmpty ? 'document' : cleaned;
}
