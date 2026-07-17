// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as web;

Future<String> saveHtmlDocument({
  required String folderName,
  required String fileName,
  required String htmlContent,
  int? notificationId,
  bool autoOpen = false,
}) async {
  final bytes = utf8.encode(htmlContent);
  final blob = web.Blob([bytes], 'text/html;charset=utf-8');
  final url = web.Url.createObjectUrlFromBlob(blob);
  final anchor = web.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  web.Url.revokeObjectUrl(url);

  return 'Browser downloads/$fileName';
}
