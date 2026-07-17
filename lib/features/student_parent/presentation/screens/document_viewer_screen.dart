import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/local_notification_service.dart';
import '../../../../core/widgets/app_notification.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/student_profile_model.dart';
import '../../data/services/student_profile_api_service.dart';
import '../providers/student_profile_provider.dart';
import '../utils/binary_document_saver.dart';
import '../utils/document_preview_cache.dart';

class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({
    super.key,
    required this.document,
    required this.instituteName,
  });

  final StudentDocumentModel document;
  final String instituteName;

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  late Future<_DocumentPreviewData> _previewFuture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreview();
  }

  Future<_DocumentPreviewData> _loadPreview() async {
    final file = await ref
        .read(studentProfileRepositoryProvider)
        .downloadDocument(widget.document.fileUrl);
    final type = _documentPreviewType(
      fileName: file.fileName,
      contentType: file.contentType,
      fallbackUrl: widget.document.fileUrl,
    );
    if (type == _DocumentPreviewType.pdf && !kIsWeb) {
      final path = await cachePreviewDocument(
        fileName: _displayFileName(file),
        bytes: file.bytes,
      );
      return _DocumentPreviewData(file: file, type: type, localPath: path);
    }
    return _DocumentPreviewData(file: file, type: type);
  }

  Future<void> _saveCurrentFile() async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    final fallbackFileName = widget.document.title.isEmpty
        ? 'document-${widget.document.id}'
        : widget.document.title;
    final notificationId = await LocalNotificationService.showDownloadStarted(
      fileName: fallbackFileName,
    );
    try {
      final preview = await _previewFuture;
      final fileName = _displayFileName(preview.file);
      final autoOpenDownloads = await ref
          .read(secureStorageServiceProvider)
          .getAutoOpenDownloadsEnabled();
      final savedPath = await saveBinaryDocument(
        folderName: _downloadFolderName(widget.instituteName),
        fileName: fileName,
        bytes: preview.file.bytes,
        notificationId: notificationId,
        autoOpen: autoOpenDownloads,
      );
      if (!mounted) {
        return;
      }
      await showAppMessageDialog(
        context,
        title: 'Document downloaded',
        message: 'Saved document locally:\n$savedPath',
        type: AppNotificationType.success,
      );
    } catch (error) {
      await LocalNotificationService.showDownloadFailed(
        fileName: fallbackFileName,
        message: error.toString(),
        notificationId: notificationId,
      );
      if (!mounted) {
        return;
      }
      showAppNotification(
        context,
        title: 'Download failed',
        message: error.toString(),
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.document.title.isEmpty
        ? 'Document ${widget.document.id}'
        : widget.document.title;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Download',
            onPressed: _isSaving ? null : _saveCurrentFile,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_DocumentPreviewData>(
        future: _previewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _PreviewMessage(
              icon: Icons.error_outline_rounded,
              title: 'Could not open document',
              message: snapshot.error.toString(),
              actionLabel: 'Try again',
              onAction: () {
                setState(() => _previewFuture = _loadPreview());
              },
            );
          }
          final preview = snapshot.data!;
          return switch (preview.type) {
            _DocumentPreviewType.image => InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Center(
                child: Image.memory(
                  preview.file.bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (context, _, _) => const _PreviewMessage(
                    icon: Icons.broken_image_rounded,
                    title: 'Image unavailable',
                    message: 'This image could not be displayed.',
                  ),
                ),
              ),
            ),
            _DocumentPreviewType.pdf when preview.localPath.isNotEmpty =>
              PDFView(
                filePath: preview.localPath,
                enableSwipe: true,
                swipeHorizontal: false,
                autoSpacing: true,
                pageFling: true,
              ),
            _ => _PreviewMessage(
              icon: Icons.insert_drive_file_rounded,
              title: 'Preview unavailable',
              message:
                  'This file type cannot be previewed here. Use download to save it.',
              actionLabel: 'Download',
              onAction: _saveCurrentFile,
            ),
          };
        },
      ),
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: const Color(0xFF64748B)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111640),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF68738E),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.download_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DocumentPreviewData {
  const _DocumentPreviewData({
    required this.file,
    required this.type,
    this.localPath = '',
  });

  final StudentDocumentFile file;
  final _DocumentPreviewType type;
  final String localPath;
}

enum _DocumentPreviewType { image, pdf, unsupported }

_DocumentPreviewType _documentPreviewType({
  required String fileName,
  required String contentType,
  required String fallbackUrl,
}) {
  final normalizedType = contentType.toLowerCase();
  final extension = _extension(fileName).isEmpty
      ? _extension(Uri.tryParse(fallbackUrl)?.path ?? '')
      : _extension(fileName);
  if (normalizedType.startsWith('image/') ||
      const {'jpg', 'jpeg', 'png'}.contains(extension)) {
    return _DocumentPreviewType.image;
  }
  if (normalizedType.contains('pdf') || extension == 'pdf') {
    return _DocumentPreviewType.pdf;
  }
  return _DocumentPreviewType.unsupported;
}

bool canPreviewDocumentUrl(String url) {
  final extension = _extension(Uri.tryParse(url)?.path ?? url);
  return const {'jpg', 'jpeg', 'png', 'pdf'}.contains(extension);
}

String _displayFileName(StudentDocumentFile file) {
  if (_extension(file.fileName).isNotEmpty) {
    return file.fileName;
  }
  final type = _documentPreviewType(
    fileName: file.fileName,
    contentType: file.contentType,
    fallbackUrl: '',
  );
  final extension = switch (type) {
    _DocumentPreviewType.image => 'jpg',
    _DocumentPreviewType.pdf => 'pdf',
    _DocumentPreviewType.unsupported => '',
  };
  return extension.isEmpty ? file.fileName : '${file.fileName}.$extension';
}

String _downloadFolderName(String instituteName) {
  final safeInstitute = instituteName
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
      .replaceAll(RegExp(r'\s+'), '_');
  return '${safeInstitute.isEmpty ? 'Institute' : safeInstitute}_Document';
}

String _extension(String value) {
  final path = value.split('?').first.split('#').first;
  final index = path.lastIndexOf('.');
  if (index < 0 || index == path.length - 1) {
    return '';
  }
  return path.substring(index + 1).toLowerCase();
}
