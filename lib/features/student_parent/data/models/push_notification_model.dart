class PushNotificationFeedModel {
  const PushNotificationFeedModel({
    required this.totalCount,
    required this.unreadCount,
    required this.notifications,
  });

  final int totalCount;
  final int unreadCount;
  final List<PushNotificationItemModel> notifications;

  factory PushNotificationFeedModel.fromJson(Map<String, dynamic> json) {
    final rows = json['notifications'];
    final summary = json['summary'];
    final summaryMap = summary is Map
        ? Map<String, dynamic>.from(summary)
        : const <String, dynamic>{};
    return PushNotificationFeedModel(
      totalCount: _int(summaryMap['total_count']),
      unreadCount: _int(summaryMap['unread_count']),
      notifications: rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) => PushNotificationItemModel.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class PushNotificationItemModel {
  const PushNotificationItemModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.status,
    required this.createdAt,
    required this.sentAt,
    required this.isRead,
    required this.readAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String status;
  final String createdAt;
  final String sentAt;
  final bool isRead;
  final String readAt;

  factory PushNotificationItemModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return PushNotificationItemModel(
      id: _int(json['id']),
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      data: rawData is Map ? Map<String, dynamic>.from(rawData) : const {},
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      sentAt: json['sent_at']?.toString() ?? '',
      isRead: json['is_read'] == true,
      readAt: json['read_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> get detailData => {
    ...data,
    'notification_id': id.toString(),
    'type': type,
    'title': title,
    'body': body,
    'created_at': createdAt,
  };
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
