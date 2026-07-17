// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class SecureStorageStore {
  SecureStorageStore();

  static const _prefix = 'ultracoachmatrix.';

  Future<String?> read(String key) async {
    return html.window.localStorage[_prefix + key];
  }

  Future<void> write(String key, String value) async {
    html.window.localStorage[_prefix + key] = value;
  }

  Future<void> delete(String key) async {
    html.window.localStorage.remove(_prefix + key);
  }
}
