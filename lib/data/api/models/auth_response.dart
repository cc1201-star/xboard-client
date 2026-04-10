class AuthResponse {
  final String token;
  final String authData;
  final bool isAdmin;

  AuthResponse({
    required this.token,
    required this.authData,
    required this.isAdmin,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String? ?? '',
      authData: json['auth_data'] as String? ?? '',
      isAdmin: json['is_admin'] as bool? ?? false,
    );
  }
}
