class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get isSubscriptionExpired => code == 'subscription_expired';

  @override
  String toString() => message;
}
