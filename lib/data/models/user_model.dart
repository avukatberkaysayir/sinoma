import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
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
  final String? fcmToken;
  final DateTime createdAt;
  final String lastName;
  final DateTime? birthday;
  final String gender;
  final String motherTongue;
  final bool notificationsEnabled;

  const UserModel({
    required this.uid,
    required this.displayName,
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
    this.fcmToken,
    required this.createdAt,
    this.birthday,
    this.gender = '',
    this.motherTongue = 'tr',
    this.notificationsEnabled = true,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
      hskLevel: (data['hskLevel'] as num?)?.toInt() ?? 1,
      isPremium: data['isPremium'] as bool? ?? false,
      aiCredits: (data['aiCredits'] as num?)?.toInt() ?? 0,
      followers: List<String>.from(data['followers'] ?? []),
      following: List<String>.from(data['following'] ?? []),
      learnedWords: List<String>.from(data['learnedWords'] ?? []),
      stats: UserStats.fromMap(data['stats'] as Map<String, dynamic>? ?? {}),
      isOnline: data['isOnline'] as bool? ?? false,
      fcmToken: data['fcmToken'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastName: data['lastName'] as String? ?? '',
      birthday: (data['birthday'] as Timestamp?)?.toDate(),
      gender: data['gender'] as String? ?? '',
      motherTongue: data['motherTongue'] as String? ?? 'tr',
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'hskLevel': hskLevel,
        'isPremium': isPremium,
        'aiCredits': aiCredits,
        'followers': followers,
        'following': following,
        'learnedWords': learnedWords,
        'stats': stats.toMap(),
        'isOnline': isOnline,
        if (fcmToken != null) 'fcmToken': fcmToken!,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastName': lastName,
        if (birthday != null) 'birthday': Timestamp.fromDate(birthday!),
        'gender': gender,
        'motherTongue': motherTongue,
        'notificationsEnabled': notificationsEnabled,
      };

  static const _unset = Object();

  UserModel copyWith({
    String? displayName,
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
    Object? fcmToken = _unset,
    DateTime? createdAt,
    Object? birthday = _unset,
    String? gender,
    String? motherTongue,
    bool? notificationsEnabled,
  }) => UserModel(
        uid: uid,
        displayName: displayName ?? this.displayName,
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
        fcmToken: identical(fcmToken, _unset) ? this.fcmToken : fcmToken as String?,
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
