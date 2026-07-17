import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/auth_api_service.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(secureStorageServiceProvider));
});

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(authApiServiceProvider),
    ref.watch(secureStorageServiceProvider),
  );
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(apiClientProvider),
  );
});

class AuthState {
  const AuthState({this.isLoading = false, this.errorMessage, this.user});

  final bool isLoading;
  final String? errorMessage;
  final UserModel? user;

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    UserModel? user,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authRepository, this._apiClient)
    : super(const AuthState());

  final AuthRepository _authRepository;
  final ApiClient _apiClient;

  Future<UserModel?> restoreSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final user = await _authRepository.restoreSession();
    if (user != null) {
      _apiClient.setSubscriptionAccess(
        allowed: user.subscriptionAccessAllowed,
        message: user.subscriptionAccessMessage,
      );
    }
    state = state.copyWith(isLoading: false, user: user);
    return user;
  }

  Future<UserModel?> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _authRepository.login(
        username: username,
        password: password,
      );
      state = state.copyWith(isLoading: false, user: response.user);
      _apiClient.setSubscriptionAccess(
        allowed: response.user.subscriptionAccessAllowed,
        message: response.user.subscriptionAccessMessage,
      );
      return response.user;
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _authRepository.logout();
    } finally {
      _apiClient
        ..clearGetCache()
        ..setSubscriptionAccess(allowed: true);
      state = const AuthState();
    }
  }
}
