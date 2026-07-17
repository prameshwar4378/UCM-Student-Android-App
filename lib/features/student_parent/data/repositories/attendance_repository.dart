import '../models/attendance_model.dart';
import '../services/attendance_api_service.dart';

class AttendanceRepository {
  const AttendanceRepository(this._attendanceApiService);

  final AttendanceApiService _attendanceApiService;

  Future<AttendanceModel> fetchAttendance({
    int? academicSessionId,
    String? status,
    String? batchId,
    String? dateFrom,
    String? dateTo,
    int limit = 180,
  }) {
    return _attendanceApiService.fetchAttendance(
      academicSessionId: academicSessionId,
      status: status,
      batchId: batchId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      limit: limit,
    );
  }
}
