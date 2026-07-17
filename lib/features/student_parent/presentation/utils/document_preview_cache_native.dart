import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> cachePreviewDocument({
  required String fileName,
  required Uint8List bytes,
}) async {
  final directory = await getTemporaryDirectory();
  final previews = Directory(
    '${directory.path}${Platform.pathSeparator}document_previews',
  );
  if (!await previews.exists()) {
    await previews.create(recursive: true);
  }
  final file = File(
    '${previews.path}${Platform.pathSeparator}${_safeFileName(fileName)}',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

String _safeFileName(String value) {
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
      .replaceAll(RegExp(r'\s+'), ' ');
  return cleaned.isEmpty ? 'document' : cleaned;
}
