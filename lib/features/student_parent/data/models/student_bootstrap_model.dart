import 'attendance_model.dart';
import 'exam_model.dart';
import 'fee_details_model.dart';
import 'homework_planner_model.dart';
import 'notice_model.dart';
import 'student_profile_model.dart';

class StudentBootstrapModel {
  const StudentBootstrapModel({
    required this.profile,
    required this.dashboardSummary,
    required this.recentAttendance,
    required this.feeSummary,
    required this.recentHomework,
    required this.notices,
    required this.upcomingExams,
  });

  final StudentProfileModel profile;
  final Map<String, dynamic> dashboardSummary;
  final AttendanceModel recentAttendance;
  final FeeDetailsModel feeSummary;
  final HomeworkPlannerModel recentHomework;
  final NoticeBoardModel notices;
  final ExamListModel upcomingExams;

  factory StudentBootstrapModel.fromJson(Map<String, dynamic> json) {
    return StudentBootstrapModel(
      profile: StudentProfileModel.fromJson(_map(json['profile'])),
      dashboardSummary: _map(json['dashboard_summary']),
      recentAttendance: AttendanceModel.fromJson(
        _map(json['recent_attendance']),
      ),
      feeSummary: FeeDetailsModel.fromJson(_map(json['fee_summary'])),
      recentHomework: HomeworkPlannerModel.fromJson(
        _map(json['recent_homework']),
      ),
      notices: NoticeBoardModel.fromJson(_map(json['notices'])),
      upcomingExams: ExamListModel.fromJson(_map(json['upcoming_exams'])),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  return value is Map<String, dynamic>
      ? value
      : Map<String, dynamic>.from(value as Map? ?? const {});
}
