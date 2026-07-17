import '../models/notice_model.dart';
import '../services/notices_api_service.dart';

class NoticesRepository {
  const NoticesRepository(this._noticesApiService);

  final NoticesApiService _noticesApiService;

  Future<NoticeBoardModel> fetchNotices({
    int? academicSessionId,
    String category = '',
    String priority = '',
    bool unread = false,
    String search = '',
    int limit = 50,
  }) {
    return _noticesApiService.fetchNotices(
      academicSessionId: academicSessionId,
      category: category,
      priority: priority,
      unread: unread,
      search: search,
      limit: limit,
    );
  }

  Future<void> markRead(int noticeId) {
    return _noticesApiService.markRead(noticeId);
  }

  Future<NoticeItemModel> fetchNotice(int noticeId) {
    return _noticesApiService.fetchNotice(noticeId);
  }
}
