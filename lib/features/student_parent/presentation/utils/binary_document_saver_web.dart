// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as web;
import 'dart:typed_data';

Future<String> saveBinaryDocument({
  required String folderName,
  required String fileName,
  required Uint8List bytes,
  int? notificationId,
  bool autoOpen = false,
}) async {
  final blob = web.Blob([bytes]);
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
