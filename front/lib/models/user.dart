class User {
  final int id;
  final String username;
  final String email;
  final String? nickname;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.nickname,
    this.createdAt,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      nickname: json['nickname'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'nickname': nickname,
      'created_at': createdAt?.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  // copyWith 메서드 추가 (닉네임 수정용)
  User copyWith({
    int? id,
    String? username,
    String? email,
    String? nickname,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}

class Progress {
  final int id;
  final int userId;
  final String language;
  final int level;
  final List<dynamic> completedLessons;
  final int totalScore;
  final DateTime? updatedAt;

  Progress({
    required this.id,
    required this.userId,
    required this.language,
    required this.level,
    required this.completedLessons,
    required this.totalScore,
    this.updatedAt,
  });

  factory Progress.fromJson(Map<String, dynamic> json) {
    return Progress(
      id: json['id'],
      userId: json['user_id'],
      language: json['language'],
      level: json['level'],
      completedLessons: json['completed_lessons'] ?? [],
      totalScore: json['total_score'],
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}
