import 'dart:typed_data';

Future<String> cachePreviewDocument({
  required String fileName,
  required Uint8List bytes,
}) {
  throw UnsupportedError('PDF preview is not available on web.');
}
