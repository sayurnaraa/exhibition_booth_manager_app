class LoginUser {
  final int? id;
  final String email;
  final String password;
  final String? fullName;
  final String? role;
  final DateTime? createdAt;

  LoginUser({
    this.id,
    required this.email,
    required this.password,
    this.fullName,
    this.role,
    this.createdAt,
  });

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'fullName': fullName,
      'role': role,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  // Create from Map (database retrieval)
  factory LoginUser.fromMap(Map<String, dynamic> map) {
    return LoginUser(
      id: map['id'],
      email: map['email'],
      password: map['password'],
      fullName: map['fullName'],
      role: map['role'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
    );
  }

  @override
  String toString() => 'LoginUser(id: $id, email: $email, fullName: $fullName, role: $role)';
}
