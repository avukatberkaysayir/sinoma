class UserModel {
  final String uid;
  final String displayName;
  final String username; // public handle, derived from the name at signup
  final String email;
  final String photoUrl;
  final int hskLevel;
  final bool isPremium;
  final int aiCredits;
  final List<String> followers;
  final List<String> following;
  final List<String> learnedWords;
  final UserStats stats;
  final bool isOnline;
  final DateTime createdAt;
  final String lastName;
  final DateTime? birthday;
  final String gender;
  final String motherTongue;
  final bool notificationsEnabled;

  const UserModel({
    required this.uid,
    required this.displayName,
    this.username = '',
    this.lastName = '',
    required this.email,
    required this.photoUrl,
    required this.hskLevel,
    required this.isPremium,
    required this.aiCredits,
    required this.followers,
    required this.following,
    required this.learnedWords,
    required this.stats,
    this.isOnline = false,
    required this.createdAt,
    this.birthday,
    this.gender = '',
    this.motherTongue = 'tr',
    this.notificationsEnabled = true,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) => UserModel(
        uid: data['id'] as String? ?? '',
        displayName: data['display_name'] as String? ?? '',
        username: data['username'] as String? ?? '',
        email: data['email'] as String? ?? '',
        photoUrl: data['photo_url'] as String? ?? '',
        hskLevel: (data['hsk_level'] as num?)?.toInt() ?? 1,
        isPremium: data['is_premium'] as bool? ?? false,
        aiCredits: (data['ai_credits'] as num?)?.toInt() ?? 0,
        followers: List<String>.from(data['followers'] ?? []),
        following: List<String>.from(data['following'] ?? []),
        learnedWords: List<String>.from(data['learned_words'] ?? []),
        stats: UserStats.fromMap(data['stats'] as Map<String, dynamic>? ?? {}),
        isOnline: data['is_online'] as bool? ?? false,
        createdAt: data['created_at'] != null
            ? DateTime.parse(data['created_at'] as String)
            : DateTime.now(),
        lastName: data['last_name'] as String? ?? '',
        birthday: data['birthday'] != null
            ? DateTime.parse(data['birthday'] as String)
            : null,
        gender: data['gender'] as String? ?? '',
        motherTongue: data['mother_tongue'] as String? ?? 'tr',
        notificationsEnabled: data['notifications_enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'id': uid,
        'display_name': displayName,
        if (username.isNotEmpty) 'username': username,
        'email': email,
        'photo_url': photoUrl,
        'hsk_level': hskLevel,
        'is_premium': isPremium,
        'ai_credits': aiCredits,
        'followers': followers,
        'following': following,
        'learned_words': learnedWords,
        'stats': stats.toMap(),
        'is_online': isOnline,
        'created_at': createdAt.toIso8601String(),
        'last_name': lastName,
        if (birthday != null) 'birthday': birthday!.toIso8601String(),
        'gender': gender,
        'mother_tongue': motherTongue,
        'notifications_enabled': notificationsEnabled,
      };

  static const _unset = Object();

  UserModel copyWith({
    String? displayName,
    String? username,
    String? lastName,
    String? email,
    String? photoUrl,
    int? hskLevel,
    bool? isPremium,
    int? aiCredits,
    List<String>? followers,
    List<String>? following,
    List<String>? learnedWords,
    UserStats? stats,
    bool? isOnline,
    DateTime? createdAt,
    Object? birthday = _unset,
    String? gender,
    String? motherTongue,
    bool? notificationsEnabled,
  }) => UserModel(
        uid: uid,
        displayName: displayName ?? this.displayName,
        username: username ?? this.username,
        lastName: lastName ?? this.lastName,
        email: email ?? this.email,
        photoUrl: photoUrl ?? this.photoUrl,
        hskLevel: hskLevel ?? this.hskLevel,
        isPremium: isPremium ?? this.isPremium,
        aiCredits: aiCredits ?? this.aiCredits,
        followers: followers ?? this.followers,
        following: following ?? this.following,
        learnedWords: learnedWords ?? this.learnedWords,
        stats: stats ?? this.stats,
        isOnline: isOnline ?? this.isOnline,
        createdAt: createdAt ?? this.createdAt,
        birthday: identical(birthday, _unset) ? this.birthday : birthday as DateTime?,
        gender: gender ?? this.gender,
        motherTongue: motherTongue ?? this.motherTongue,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      );

  bool get canUseAiDictionary => isPremium || aiCredits > 0;
  int get stretchLevel => (hskLevel + 1).clamp(1, 6);
}

class UserStats {
  final int totalScore;
  final int videosWatched;
  final int questionsAnswered;
  final int currentStreak;

  const UserStats({
    this.totalScore = 0,
    this.videosWatched = 0,
    this.questionsAnswered = 0,
    this.currentStreak = 0,
  });

  factory UserStats.fromMap(Map<String, dynamic> map) => UserStats(
        totalScore: (map['totalScore'] as num?)?.toInt() ?? 0,
        videosWatched: (map['videosWatched'] as num?)?.toInt() ?? 0,
        questionsAnswered: (map['questionsAnswered'] as num?)?.toInt() ?? 0,
        currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'totalScore': totalScore,
        'videosWatched': videosWatched,
        'questionsAnswered': questionsAnswered,
        'currentStreak': currentStreak,
      };

  UserStats copyWith({
    int? totalScore,
    int? videosWatched,
    int? questionsAnswered,
    int? currentStreak,
  }) => UserStats(
        totalScore: totalScore ?? this.totalScore,
        videosWatched: videosWatched ?? this.videosWatched,
        questionsAnswered: questionsAnswered ?? this.questionsAnswered,
        currentStreak: currentStreak ?? this.currentStreak,
      );
}
