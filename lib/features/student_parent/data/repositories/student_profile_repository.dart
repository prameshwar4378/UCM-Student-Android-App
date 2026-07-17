import '../models/student_profile_model.dart';
import '../services/student_profile_api_service.dart';

class StudentProfileRepository {
  const StudentProfileRepository(this._profileApiService);

  final StudentProfileApiService _profileApiService;

  Future<StudentProfileModel> fetchProfile({int? academicSessionId}) {
    return _profileApiService.fetchProfile(
      academicSessionId: academicSessionId,
    );
  }

  Future<StudentDocumentFile> downloadDocument(String url) {
    return _profileApiService.downloadDocument(url);
  }
}
