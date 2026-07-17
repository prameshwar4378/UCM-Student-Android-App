enum PushNotificationPage {
  dashboard(0),
  attendance(1),
  fees(2),
  homework(3),
  exams(4),
  results(5),
  notices(8),
  profile(9),
  notifications(11),
  documents(12);

  const PushNotificationPage(this.dashboardIndex);

  final int dashboardIndex;
}

PushNotificationPage notificationPageForData(Map<String, dynamic> data) {
  final route = _normalize(data['route'] ?? data['screen'] ?? data['page']);
  final type = _normalize(
    data['type'] ?? data['event_type'] ?? data['notification_type'],
  );
  final value = route.isNotEmpty ? route : type;

  if (const {
    'FEE',
    'FEES',
    'FEE_PAID',
    'FEE_PAYMENT',
    'PAYMENT',
    'PAYMENT_RECEIVED',
    'PAYMENT_UPDATED',
  }.contains(value)) {
    return PushNotificationPage.fees;
  }
  if (const {
    'NOTICE',
    'NOTICES',
    'NOTICE_PUBLISHED',
    'NOTICE_UPDATED',
  }.contains(value)) {
    return PushNotificationPage.notices;
  }
  if (const {
    'RESULT',
    'RESULTS',
    'RESULT_DECLARED',
    'RESULT_UPDATED',
  }.contains(value)) {
    return PushNotificationPage.results;
  }
  if (const {
    'EXAM',
    'EXAMS',
    'EXAM_PUBLISHED',
    'EXAM_UPDATED',
  }.contains(value)) {
    return PushNotificationPage.exams;
  }
  if (const {
    'ATTENDANCE',
    'ATTENDANCE_MARKED',
    'ATTENDANCE_UPDATED',
  }.contains(value)) {
    return PushNotificationPage.attendance;
  }
  if (const {
    'HOMEWORK',
    'HOMEWORK_ASSIGNED',
    'HOMEWORK_UPDATED',
  }.contains(value)) {
    return PushNotificationPage.homework;
  }
  if (const {
    'STUDENT',
    'STUDENT_UPDATED',
    'STUDENT_PROFILE_UPDATED',
    'PROFILE',
    'PROFILE_UPDATED',
    'ENROLLMENT_UPDATED',
    'ACADEMIC_SESSION_UPDATED',
  }.contains(value)) {
    return PushNotificationPage.profile;
  }
  if (const {'DOCUMENT', 'DOCUMENTS', 'DOCUMENT_SHARED'}.contains(value)) {
    return PushNotificationPage.documents;
  }
  if (const {'NOTIFICATION', 'NOTIFICATIONS'}.contains(value)) {
    return PushNotificationPage.notifications;
  }
  return PushNotificationPage.dashboard;
}

String _normalize(Object? value) {
  return (value?.toString() ?? '').trim().toUpperCase().replaceAll(
    RegExp(r'[\s/-]+'),
    '_',
  );
}
