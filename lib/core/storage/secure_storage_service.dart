import 'secure_storage_store.dart';

class SecureStorageService {
  SecureStorageService({SecureStorageStore? store})
    : _store = store ?? SecureStorageStore();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _usernameKey = 'username';
  static const _userRoleKey = 'user_role';
  static const _instituteIdKey = 'institute_id';
  static const _pushNotificationsEnabledKey = 'push_notifications_enabled';
  static const _autoOpenDownloadsKey = 'auto_open_downloads';

  final SecureStorageStore _store;

  Future<String?> getAccessToken() => _store.read(_accessTokenKey);

  Future<String?> getRefreshToken() => _store.read(_refreshTokenKey);

  Future<void> saveAccessToken(String accessToken) {
    return _store.write(_accessTokenKey, accessToken);
  }

  Future<bool> getPushNotificationsEnabled() async {
    final value = await _store.read(_pushNotificationsEnabledKey);
    return value == null || value == 'true';
  }

  Future<void> savePushNotificationsEnabled(bool enabled) {
    return _store.write(_pushNotificationsEnabledKey, enabled.toString());
  }

  Future<bool> getAutoOpenDownloadsEnabled() async {
    final value = await _store.read(_autoOpenDownloadsKey);
    return value == null || value == 'true';
  }

  Future<void> saveAutoOpenDownloadsEnabled(bool enabled) {
    return _store.write(_autoOpenDownloadsKey, enabled.toString());
  }

  Future<void> saveAuthSession({
    required String accessToken,
    required String refreshToken,
    required int userId,
    required String username,
    required String role,
    required int instituteId,
  }) async {
    await Future.wait([
      _store.write(_accessTokenKey, accessToken),
      _store.write(_refreshTokenKey, refreshToken),
      _store.write(_userIdKey, userId.toString()),
      _store.write(_usernameKey, username),
      _store.write(_userRoleKey, role),
      _store.write(_instituteIdKey, instituteId.toString()),
    ]);
  }

  Future<void> clearAuthSession() async {
    await Future.wait([
      _store.delete(_accessTokenKey),
      _store.delete(_refreshTokenKey),
      _store.delete(_userIdKey),
      _store.delete(_usernameKey),
      _store.delete(_userRoleKey),
      _store.delete(_instituteIdKey),
    ]);
  }
}
