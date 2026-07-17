class UserModel {
  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.name,
    required this.role,
    required this.instituteId,
    this.subscriptionAccessAllowed = true,
    this.subscriptionAccessMessage = '',
  });

  final int id;
  final String username;
  final String email;
  final String name;
  final String role;
  final int instituteId;
  final bool subscriptionAccessAllowed;
  final String subscriptionAccessMessage;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _parseInt(json['id']),
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      instituteId: _parseInt(json['institute_id']),
      subscriptionAccessAllowed:
          json['subscription_access_allowed'] as bool? ?? true,
      subscriptionAccessMessage:
          json['subscription_access_message'] as String? ?? '',
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
