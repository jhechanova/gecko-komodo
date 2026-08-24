class AppUser {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String username;
  final String fcmToken;

  const AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.username,
    this.fcmToken = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
      'fcm_token': fcmToken,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      firstName: map['first_name']?.toString() ?? '',
      lastName: map['last_name']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      fcmToken: map['fcm_token']?.toString() ?? '',
    );
  }

  factory AppUser.fromLoginJson(Map<String, dynamic> json, String username) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      username: username,
      // Device FCM token is registered separately; not taken from login.
      fcmToken: '',
    );
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? username,
    String? fcmToken,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? username : name;
  }
}
