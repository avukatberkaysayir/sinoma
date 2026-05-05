// ignore_for_file: avoid_print
// Firestore Emulator Seed Script
// Usage: dart run tool/seed_emulator.dart
//
// Seeds the local Firestore emulator with demo data so the app is fully
// testable without a real Firebase project.
//
// Requires:
//   - Firebase Emulator running: firebase emulators:start --project demo-mandarin-academy
//   - dart pub get

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const _projectId = 'demo-mandarin-academy';
const _firestorePort = 9299;
const _firestoreBase =
    'http://localhost:$_firestorePort/v1/projects/$_projectId/databases/(default)/documents';

// --------------------------------------------------------------------------
// Helpers
// --------------------------------------------------------------------------

Future<void> _set(String collection, String docId, Map<String, dynamic> data) async {
  final url = Uri.parse('$_firestoreBase/$collection/$docId');
  final body = jsonEncode(_toFirestore(data));
  final res = await http.patch(
    url,
    headers: {
      'Content-Type': 'application/json',
      // Emulator-only: bypasses Firestore security rules entirely.
      'Authorization': 'Bearer owner',
    },
    body: body,
  );
  if (res.statusCode >= 300) {
    print('ERROR $collection/$docId: ${res.statusCode} ${res.body}');
  } else {
    print('  ✓ $collection/$docId');
  }
}

/// Converts a plain Dart map to Firestore REST document format.
Map<String, dynamic> _toFirestore(Map<String, dynamic> data) {
  final fields = <String, dynamic>{};
  for (final entry in data.entries) {
    fields[entry.key] = _encodeValue(entry.value);
  }
  return {'fields': fields};
}

dynamic _encodeValue(dynamic value) {
  if (value == null) return {'nullValue': null};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': value.toString()};
  if (value is double) return {'doubleValue': value};
  if (value is String) return {'stringValue': value};
  if (value is DateTime) return {'timestampValue': value.toUtc().toIso8601String()};
  if (value is List) {
    return {
      'arrayValue': {
        'values': value.map(_encodeValue).toList(),
      },
    };
  }
  if (value is Map<String, dynamic>) {
    return {
      'mapValue': {
        'fields': value.map((k, v) => MapEntry(k, _encodeValue(v))),
      },
    };
  }
  return {'stringValue': value.toString()};
}

// --------------------------------------------------------------------------
// Seed data
// --------------------------------------------------------------------------

Future<void> _seedDictionary() async {
  print('\n📖 Seeding dictionary...');

  final words = [
    {
      'wordId': 'ni-hao',
      'simplified': '你好',
      'traditional': '你好',
      'pinyin': 'nǐ hǎo',
      'hskLevel': 1,
      'definitions': {
        'tr': 'Merhaba',
        'en': 'Hello',
        'vi': 'Xin chào',
      },
      'radicals': ['你', '好'],
      'strokeCount': 11,
      'aiContextCache': <String, dynamic>{},
    },
    {
      'wordId': 'shui',
      'simplified': '水',
      'traditional': '水',
      'pinyin': 'shuǐ',
      'hskLevel': 1,
      'definitions': {
        'tr': 'Su',
        'en': 'Water',
        'vi': 'Nước',
      },
      'radicals': ['水'],
      'strokeCount': 4,
      'aiContextCache': <String, dynamic>{},
    },
    {
      'wordId': 'jin-tian',
      'simplified': '今天',
      'traditional': '今天',
      'pinyin': 'jīn tiān',
      'hskLevel': 1,
      'definitions': {
        'tr': 'Bugün',
        'en': 'Today',
        'vi': 'Hôm nay',
      },
      'radicals': ['今', '天'],
      'strokeCount': 8,
      'aiContextCache': <String, dynamic>{},
    },
    {
      'wordId': 'wo',
      'simplified': '我',
      'traditional': '我',
      'pinyin': 'wǒ',
      'hskLevel': 1,
      'definitions': {
        'tr': 'Ben',
        'en': 'I / Me',
        'vi': 'Tôi',
      },
      'radicals': ['我'],
      'strokeCount': 7,
      'aiContextCache': <String, dynamic>{},
    },
    {
      'wordId': 'chi-fan',
      'simplified': '吃饭',
      'traditional': '吃飯',
      'pinyin': 'chī fàn',
      'hskLevel': 1,
      'definitions': {
        'tr': 'Yemek yemek',
        'en': 'To eat / Have a meal',
        'vi': 'Ăn cơm',
      },
      'radicals': ['口', '食'],
      'strokeCount': 13,
      'aiContextCache': <String, dynamic>{},
    },
    {
      'wordId': 'gao-xing',
      'simplified': '高兴',
      'traditional': '高興',
      'pinyin': 'gāo xìng',
      'hskLevel': 2,
      'definitions': {
        'tr': 'Mutlu, sevinçli',
        'en': 'Happy, glad',
        'vi': 'Vui mừng',
      },
      'radicals': ['高', '兴'],
      'strokeCount': 14,
      'aiContextCache': <String, dynamic>{},
    },
    {
      'wordId': 'huan-jing',
      'simplified': '环境',
      'traditional': '環境',
      'pinyin': 'huán jìng',
      'hskLevel': 3,
      'definitions': {
        'tr': 'Çevre, ortam',
        'en': 'Environment, surroundings',
        'vi': 'Môi trường',
      },
      'radicals': ['玨', '土'],
      'strokeCount': 15,
      'aiContextCache': <String, dynamic>{},
    },
    {
      'wordId': 'zhong-wen',
      'simplified': '中文',
      'traditional': '中文',
      'pinyin': 'zhōng wén',
      'hskLevel': 1,
      'definitions': {
        'tr': 'Çince',
        'en': 'Chinese language',
        'vi': 'Tiếng Trung',
      },
      'radicals': ['中', '文'],
      'strokeCount': 8,
      'aiContextCache': <String, dynamic>{},
    },
  ];

  for (final word in words) {
    final id = word['wordId'] as String;
    await _set('dictionary', id, word);
  }
}

Future<void> _seedVideos() async {
  print('\n🎬 Seeding videos...');

  final now = DateTime.now();

  final videos = [
    {
      'videoId': 'video-hsk1-01',
      'sourceType': 'youtube',
      'youtubeId': 'dQw4w9WgXcQ', // placeholder — will be replaced with real content
      'startTime': 0.0,
      'endTime': 8.0,
      'hskLevel': 1,
      'transcription': '你好，今天你吃饭了吗？',
      'pinyin': 'Nǐ hǎo, jīn tiān nǐ chī fàn le ma?',
      'targetWords': ['ni-hao', 'jin-tian', 'chi-fan'],
      'quizCategory': 'conversation',
      'quiz': {
        'question': '"今天" means:',
        'correctAnswer': 'Today',
        'wrongAnswer': 'Yesterday',
      },
      'isActive': true,
      'createdAt': now,
    },
    {
      'videoId': 'video-hsk1-02',
      'sourceType': 'youtube',
      'youtubeId': 'dQw4w9WgXcQ',
      'startTime': 10.0,
      'endTime': 17.0,
      'hskLevel': 1,
      'transcription': '我很高兴认识你。',
      'pinyin': 'Wǒ hěn gāo xìng rèn shi nǐ.',
      'targetWords': ['wo', 'gao-xing'],
      'quizCategory': 'vocabulary',
      'quiz': {
        'question': '"高兴" means:',
        'correctAnswer': 'Happy',
        'wrongAnswer': 'Sad',
      },
      'isActive': true,
      'createdAt': now,
    },
    {
      'videoId': 'video-hsk1-03',
      'sourceType': 'youtube',
      'youtubeId': 'dQw4w9WgXcQ',
      'startTime': 20.0,
      'endTime': 27.0,
      'hskLevel': 1,
      'transcription': '请给我一杯水。',
      'pinyin': 'Qǐng gěi wǒ yī bēi shuǐ.',
      'targetWords': ['shui', 'wo'],
      'quizCategory': 'listening',
      'quiz': {
        'question': '"水" means:',
        'correctAnswer': 'Water',
        'wrongAnswer': 'Fire',
      },
      'isActive': true,
      'createdAt': now,
    },
    {
      'videoId': 'video-hsk2-01',
      'sourceType': 'youtube',
      'youtubeId': 'dQw4w9WgXcQ',
      'startTime': 30.0,
      'endTime': 38.0,
      'hskLevel': 2,
      'transcription': '学习中文很有意思。',
      'pinyin': 'Xuéxí zhōngwén hěn yǒu yìsi.',
      'targetWords': ['zhong-wen'],
      'quizCategory': 'grammar',
      'quiz': {
        'question': '"中文" means:',
        'correctAnswer': 'Chinese language',
        'wrongAnswer': 'Chinese food',
      },
      'isActive': true,
      'createdAt': now,
    },
    {
      'videoId': 'video-hsk3-01',
      'sourceType': 'youtube',
      'youtubeId': 'dQw4w9WgXcQ',
      'startTime': 40.0,
      'endTime': 48.0,
      'hskLevel': 3,
      'transcription': '保护环境是我们的责任。',
      'pinyin': 'Bǎohù huánjìng shì wǒmen de zérèn.',
      'targetWords': ['huan-jing'],
      'quizCategory': 'culture',
      'quiz': {
        'question': '"环境" means:',
        'correctAnswer': 'Environment',
        'wrongAnswer': 'Society',
      },
      'isActive': true,
      'createdAt': now,
    },
  ];

  for (final video in videos) {
    final id = video['videoId'] as String;
    await _set('videos', id, video);
  }
}

Future<void> _seedUsers() async {
  print('\n👤 Seeding demo user...');

  final now = DateTime.now();
  await _set('users', 'demo-user-001', {
    'uid': 'demo-user-001',
    'displayName': 'Demo User',
    'email': 'demo@mandarinacademy.test',
    'photoUrl': '',
    'hskLevel': 1,
    'isPremium': false,
    'aiCredits': 10,
    'followers': <String>[],
    'following': <String>[],
    'learnedWords': ['ni-hao', 'shui'],
    'isOnline': false,
    'stats': {
      'totalScore': 250,
      'videosWatched': 5,
      'questionsAnswered': 8,
      'currentStreak': 3,
    },
    'createdAt': now,
  });

  // Second user for social/leaderboard testing
  await _set('users', 'demo-user-002', {
    'uid': 'demo-user-002',
    'displayName': 'Li Wei',
    'email': 'liwei@mandarinacademy.test',
    'photoUrl': '',
    'hskLevel': 3,
    'isPremium': true,
    'aiCredits': 50,
    'followers': ['demo-user-001'],
    'following': <String>[],
    'learnedWords': ['ni-hao', 'shui', 'jin-tian', 'wo', 'chi-fan', 'gao-xing', 'huan-jing', 'zhong-wen'],
    'isOnline': true,
    'stats': {
      'totalScore': 4200,
      'videosWatched': 42,
      'questionsAnswered': 85,
      'currentStreak': 14,
    },
    'createdAt': DateTime.now().subtract(const Duration(days: 30)),
  });
}

Future<void> _seedPosts() async {
  print('\n📝 Seeding social posts...');

  final now = DateTime.now();
  await _set('posts', 'post-001', {
    'postId': 'post-001',
    'authorId': 'demo-user-002',
    'content': '今天学了10个新词！学中文真的很有趣 🎉',
    'attachmentUrl': null,
    'likes': ['demo-user-001'],
    'postType': 'achievement',
    'metadata': {'hskLevel': 3, 'wordsLearned': 10},
    'timestamp': now.subtract(const Duration(hours: 2)),
  });

  await _set('posts', 'post-002', {
    'postId': 'post-002',
    'authorId': 'demo-user-002',
    'content': 'Mandarin Duel\'de 8/10 yaptım! 加油！',
    'attachmentUrl': null,
    'likes': <String>[],
    'postType': 'score',
    'metadata': {'score': 800, 'totalRounds': 10, 'correctRounds': 8},
    'timestamp': now.subtract(const Duration(hours: 5)),
  });
}

// --------------------------------------------------------------------------
// Main
// --------------------------------------------------------------------------

Future<void> main() async {
  print('🌱 Mandarin Academy — Firestore Emulator Seed');
  print('   Project: $_projectId');
  print('   Firestore: http://localhost:8080');
  print('');

  // Quick connectivity check
  try {
    await http
        .get(Uri.parse('http://localhost:$_firestorePort'))
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    print('❌ Cannot reach Firestore emulator at localhost:$_firestorePort');
    print('   Run first: start_emulator.bat');
    exit(1);
  }

  await _seedDictionary();
  await _seedVideos();
  await _seedUsers();
  await _seedPosts();

  print('\n✅ Seed complete! Open http://localhost:9300 to test the app.');
}
