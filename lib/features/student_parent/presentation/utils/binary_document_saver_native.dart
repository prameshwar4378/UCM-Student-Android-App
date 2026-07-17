import 'dart:io';
import 'dart:typed_data';

import '../../../../core/notifications/local_notification_service.dart';

Future<String> saveBinaryDocument({
  required String folderName,
  required String fileName,
  required Uint8List bytes,
  int? notificationId,
  bool autoOpen = false,
}) async {
  final directory = await _localDownloadDirectory(folderName: folderName);
  final file = await _uniqueFile(directory: directory, fileName: fileName);
  await file.writeAsBytes(bytes, flush: true);
  await LocalNotificationService.showDownloadedFile(
    filePath: file.path,
    fileName: file.uri.pathSegments.last,
    notificationId: notificationId,
  );
  if (autoOpen) {
    await LocalNotificationService.openDownloadedFile(file.path);
  }
  return file.path;
}

Future<Directory> _localDownloadDirectory({required String folderName}) async {
  final baseDirectory = _platformDownloadDirectory();
  final directory = Directory(
    '${baseDirectory.path}${Platform.pathSeparator}$folderName',
  );
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return directory;
}

Directory _platformDownloadDirectory() {
  if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) {
      return Directory('$userProfile${Platform.pathSeparator}Downloads');
    }
  }

  if (Platform.isMacOS || Platform.isLinux) {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory('$home${Platform.pathSeparator}Downloads');
    }
  }

  if (Platform.isAndroid) {
    return Directory('/storage/emulated/0/Download');
  }

  return Directory.systemTemp;
}

Future<File> _uniqueFile({
  required Directory directory,
  required String fileName,
}) async {
  final safeName = _safeFileName(fileName);
  final dotIndex = safeName.lastIndexOf('.');
  final baseName = dotIndex <= 0 ? safeName : safeName.substring(0, dotIndex);
  final extension = dotIndex <= 0 ? '' : safeName.substring(dotIndex);

  var candidate = File('${directory.path}${Platform.pathSeparator}$safeName');
  var index = 2;
  while (await candidate.exists()) {
    candidate = File(
      '${directory.path}${Platform.pathSeparator}$baseName-$index$extension',
    );
    index += 1;
  }
  return candidate;
}

String _safeFileName(String value) {
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
      .replaceAll(RegExp(r'\s+'), ' ');
  return cleaned.isEmpty ? 'document' : cleaned;
}
