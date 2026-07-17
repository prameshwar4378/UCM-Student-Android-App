class NoticeBoardModel {
  const NoticeBoardModel({
    required this.student,
    required this.filters,
    required this.summary,
    required this.categoryChoices,
    required this.priorityChoices,
    required this.categoryCounts,
    required this.notices,
  });

  final NoticeStudentModel student;
  final NoticeFiltersModel filters;
  final NoticeSummaryModel summary;
  final List<NoticeChoiceModel> categoryChoices;
  final List<NoticeChoiceModel> priorityChoices;
  final List<NoticeCategoryCountModel> categoryCounts;
  final List<NoticeItemModel> notices;

  factory NoticeBoardModel.fromJson(Map<String, dynamic> json) {
    return NoticeBoardModel(
      student: NoticeStudentModel.fromJson(_map(json['student'])),
      filters: NoticeFiltersModel.fromJson(_map(json['filters'])),
      summary: NoticeSummaryModel.fromJson(_map(json['summary'])),
      categoryChoices: _list(
        json['category_choices'],
      ).map(NoticeChoiceModel.fromJson).toList(),
      priorityChoices: _list(
        json['priority_choices'],
      ).map(NoticeChoiceModel.fromJson).toList(),
      categoryCounts: _list(
        json['category_counts'],
      ).map(NoticeCategoryCountModel.fromJson).toList(),
      notices: _list(json['notices']).map(NoticeItemModel.fromJson).toList(),
    );
  }
}

class NoticeStudentModel {
  const NoticeStudentModel({
    required this.id,
    required this.admissionNumber,
    required this.name,
    required this.username,
    required this.instituteName,
  });

  final int id;
  final String admissionNumber;
  final String name;
  final String username;
  final String instituteName;

  factory NoticeStudentModel.fromJson(Map<String, dynamic> json) {
    return NoticeStudentModel(
      id: _int(json['id']),
      admissionNumber: json['admission_number'] as String? ?? '',
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      instituteName: _map(json['institute'])['name'] as String? ?? '',
    );
  }
}

class NoticeFiltersModel {
  const NoticeFiltersModel({
    required this.category,
    required this.priority,
    required this.unread,
    required this.search,
    required this.limit,
  });

  final String category;
  final String priority;
  final bool unread;
  final String search;
  final int limit;

  factory NoticeFiltersModel.fromJson(Map<String, dynamic> json) {
    return NoticeFiltersModel(
      category: json['category'] as String? ?? '',
      priority: json['priority'] as String? ?? '',
      unread: json['unread'] == true,
      search: json['search'] as String? ?? '',
      limit: _int(json['limit']),
    );
  }
}

class NoticeSummaryModel {
  const NoticeSummaryModel({
    required this.totalCount,
    required this.unreadCount,
    required this.urgentCount,
    required this.pinnedCount,
  });

  final int totalCount;
  final int unreadCount;
  final int urgentCount;
  final int pinnedCount;

  factory NoticeSummaryModel.fromJson(Map<String, dynamic> json) {
    return NoticeSummaryModel(
      totalCount: _int(json['total_count']),
      unreadCount: _int(json['unread_count']),
      urgentCount: _int(json['urgent_count']),
      pinnedCount: _int(json['pinned_count']),
    );
  }
}

class NoticeChoiceModel {
  const NoticeChoiceModel({required this.value, required this.label});

  final String value;
  final String label;

  factory NoticeChoiceModel.fromJson(Map<String, dynamic> json) {
    return NoticeChoiceModel(
      value: json['value'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class NoticeCategoryCountModel {
  const NoticeCategoryCountModel({
    required this.value,
    required this.label,
    required this.count,
  });

  final String value;
  final String label;
  final int count;

  factory NoticeCategoryCountModel.fromJson(Map<String, dynamic> json) {
    return NoticeCategoryCountModel(
      value: json['value'] as String? ?? '',
      label: json['label'] as String? ?? '',
      count: _int(json['count']),
    );
  }
}

class NoticeItemModel {
  const NoticeItemModel({
    required this.id,
    required this.title,
    required this.message,
    required this.htmlMessage,
    required this.category,
    required this.categoryLabel,
    required this.priority,
    required this.priorityLabel,
    required this.audienceLabel,
    required this.publishAt,
    required this.expiresAt,
    required this.createdAt,
    required this.pinOnTop,
    required this.isRead,
    required this.createdBy,
  });

  final int id;
  final String title;
  final String message;
  final String htmlMessage;
  final String category;
  final String categoryLabel;
  final String priority;
  final String priorityLabel;
  final String audienceLabel;
  final String publishAt;
  final String expiresAt;
  final String createdAt;
  final bool pinOnTop;
  final bool isRead;
  final String createdBy;

  factory NoticeItemModel.fromJson(Map<String, dynamic> json) {
    return NoticeItemModel(
      id: _int(json['id']),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      htmlMessage:
          json['html_message'] as String? ??
          json['message_html'] as String? ??
          '',
      category: json['category'] as String? ?? '',
      categoryLabel: json['category_label'] as String? ?? '',
      priority: json['priority'] as String? ?? '',
      priorityLabel: json['priority_label'] as String? ?? '',
      audienceLabel: json['audience_label'] as String? ?? '',
      publishAt: json['publish_at'] as String? ?? '',
      expiresAt: json['expires_at'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      pinOnTop: json['pin_on_top'] == true,
      isRead: json['is_read'] == true,
      createdBy: json['created_by'] as String? ?? '',
    );
  }

  Map<String, dynamic> get notificationDetailData => {
    'type': 'NOTICE',
    'route': 'notices',
    'notice_id': id.toString(),
    'title': title,
    'body': message,
    'category': category,
    'category_label': categoryLabel,
    'priority': priority,
    'priority_label': priorityLabel,
    'created_at': createdAt,
    'created_by': createdBy,
  };
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const [];
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
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
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
