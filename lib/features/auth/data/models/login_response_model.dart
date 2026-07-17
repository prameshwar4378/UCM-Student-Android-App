import 'user_model.dart';

class LoginResponseModel {
  const LoginResponseModel({
    required this.access,
    required this.refresh,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  final String access;
  final String refresh;
  final String tokenType;
  final int expiresIn;
  final UserModel user;

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      access: json['access'] as String? ?? '',
      refresh: json['refresh'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresIn: _parseInt(json['expires_in']),
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  static int _parseInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
