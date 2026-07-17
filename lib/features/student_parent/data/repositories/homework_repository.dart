import '../models/homework_planner_model.dart';
import '../services/homework_api_service.dart';

class HomeworkRepository {
  const HomeworkRepository(this._homeworkApiService);

  final HomeworkApiService _homeworkApiService;

  Future<HomeworkPlannerModel> fetchHomeworkPlanner({int? academicSessionId}) {
    return _homeworkApiService.fetchHomeworkPlanner(
      academicSessionId: academicSessionId,
    );
  }

  Future<String> downloadPlannerDocument(String url) {
    return _homeworkApiService.downloadPlannerDocument(url);
  }
}
