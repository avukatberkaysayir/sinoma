// ignore_for_file: avoid_print
// Firestore Emulator Seed Script
// Usage: dart run tool/seed_emulator.dart
//
// Seeds the local Firestore emulator with demo data so the app is fully
// testable without a real Firebase project.
//
// YouTube IDs used below are from Mandarin Corner, ChinesePod, and
// other freely-embeddable Mandarin learning channels.
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
      'definitions': {'tr': 'Merhaba', 'en': 'Hello', 'vi': 'Xin chào'},
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
      'definitions': {'tr': 'Su', 'en': 'Water', 'vi': 'Nước'},
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
      'definitions': {'tr': 'Bugün', 'en': 'Today', 'vi': 'Hôm nay'},
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
      'definitions': {'tr': 'Ben', 'en': 'I / Me', 'vi': 'Tôi'},
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
      'definitions': {'tr': 'Yemek yemek', 'en': 'To eat / Have a meal', 'vi': 'Ăn cơm'},
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
      'definitions': {'tr': 'Mutlu, sevinçli', 'en': 'Happy, glad', 'vi': 'Vui mừng'},
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
      'definitions': {'tr': 'Çevre, ortam', 'en': 'Environment, surroundings', 'vi': 'Môi trường'},
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
      'definitions': {'tr': 'Çince', 'en': 'Chinese language', 'vi': 'Tiếng Trung'},
      'radicals': ['中', '文'],
      'strokeCount': 8,
      'aiContextCache': <String, dynamic>{},
    },
    {
      'wordId': 'xie-xie',
      'simplified': '谢谢',
      'traditional': '謝謝',
      'pinyin': 'xiè xiè',
      'hskLevel': 1,
      'definitions': {'tr': 'Teşekkür ederim', 'en': 'Thank you', 'vi': 'Cảm ơn'},
      'radicals': ['言', '射'],
      'strokeCount': 24,
      'aiContextCache': <String, dynamic>{},
    },
    {
      'wordId': 'dui',
      'simplified': '对',
      'traditional': '對',
      'pinyin': 'duì',
      'hskLevel': 1,
      'definitions': {'tr': 'Doğru, evet', 'en': 'Correct, right', 'vi': 'Đúng'},
      'radicals': ['又', '寸'],
      'strokeCount': 5,
      'aiContextCache': <String, dynamic>{},
    },
    {
      'wordId': 'chun-jie',
      'simplified': '春节',
      'traditional': '春節',
      'pinyin': 'chūn jié',
      'hskLevel': 2,
      'definitions': {'tr': 'Çin Yeni Yılı', 'en': 'Spring Festival / Chinese New Year', 'vi': 'Tết Nguyên Đán'},
      'radicals': ['春', '节'],
      'strokeCount': 17,
      'aiContextCache': <String, dynamic>{},
    },
    {
      'wordId': 'ren-shi',
      'simplified': '认识',
      'traditional': '認識',
      'pinyin': 'rèn shi',
      'hskLevel': 2,
      'definitions': {'tr': 'Tanımak', 'en': 'To know / recognize', 'vi': 'Biết / quen'},
      'radicals': ['言', '心'],
      'strokeCount': 18,
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

  // YouTube IDs: publicly embeddable Mandarin learning videos.
  // Using a set of known Mandarin Corner / ChinesePod / HSK lesson videos.
  // Replace with real content IDs from your chosen channels.
  final videos = [
    // ── CONVERSATION ──────────────────────────────────────────────────────────
    {
      'videoId': 'video-conv-01',
      'sourceType': 'youtube',
      'youtubeId': 'BdXpFvkFsHs', // Mandarin Corner: greetings
      'startTime': 12.0,
      'endTime': 20.0,
      'hskLevel': 1,
      'transcription': '你好，你叫什么名字？',
      'pinyin': 'Nǐ hǎo, nǐ jiào shénme míngzi?',
      'targetWords': ['ni-hao'],
      'quizCategory': 'conversation',
      'quiz': {
        'question': '"你好" means:',
        'correctAnswer': 'Hello',
        'wrongAnswer': 'Goodbye',
      },
      'isActive': true,
      'createdAt': now,
    },
    {
      'videoId': 'video-conv-02',
      'sourceType': 'youtube',
      'youtubeId': 'BdXpFvkFsHs',
      'startTime': 35.0,
      'endTime': 43.0,
      'hskLevel': 1,
      'transcription': '今天你吃饭了吗？',
      'pinyin': 'Jīn tiān nǐ chī fàn le ma?',
      'targetWords': ['jin-tian', 'chi-fan'],
      'quizCategory': 'conversation',
      'quiz': {
        'question': '"今天" means:',
        'correctAnswer': 'Today',
        'wrongAnswer': 'Yesterday',
      },
      'isActive': true,
      'createdAt': now.subtract(const Duration(minutes: 1)),
    },
    {
      'videoId': 'video-conv-03',
      'sourceType': 'youtube',
      'youtubeId': 'TWGSAjpdGQw', // HSK 1 conversation
      'startTime': 8.0,
      'endTime': 15.0,
      'hskLevel': 1,
      'transcription': '谢谢你，对不对？',
      'pinyin': 'Xiè xiè nǐ, duì bu duì?',
      'targetWords': ['xie-xie', 'dui'],
      'quizCategory': 'conversation',
      'quiz': {
        'question': '"谢谢" means:',
        'correctAnswer': 'Thank you',
        'wrongAnswer': 'Sorry',
      },
      'isActive': true,
      'createdAt': now.subtract(const Duration(minutes: 2)),
    },
    // ── VOCABULARY ────────────────────────────────────────────────────────────
    {
      'videoId': 'video-vocab-01',
      'sourceType': 'youtube',
      'youtubeId': 'TWGSAjpdGQw',
      'startTime': 22.0,
      'endTime': 30.0,
      'hskLevel': 1,
      'transcription': '我很高兴认识你。',
      'pinyin': 'Wǒ hěn gāo xìng rèn shi nǐ.',
      'targetWords': ['wo', 'gao-xing', 'ren-shi'],
      'quizCategory': 'vocabulary',
      'quiz': {
        'question': '"高兴" means:',
        'correctAnswer': 'Happy',
        'wrongAnswer': 'Sad',
      },
      'isActive': true,
      'createdAt': now.subtract(const Duration(minutes: 3)),
    },
    {
      'videoId': 'video-vocab-02',
      'sourceType': 'youtube',
      'youtubeId': 'TWGSAjpdGQw',
      'startTime': 45.0,
      'endTime': 52.0,
      'hskLevel': 1,
      'transcription': '请给我一杯水。',
      'pinyin': 'Qǐng gěi wǒ yī bēi shuǐ.',
      'targetWords': ['shui', 'wo'],
      'quizCategory': 'vocabulary',
      'quiz': {
        'question': '"水" means:',
        'correctAnswer': 'Water',
        'wrongAnswer': 'Fire',
      },
      'isActive': true,
      'createdAt': now.subtract(const Duration(minutes: 4)),
    },
    {
      'videoId': 'video-vocab-03',
      'sourceType': 'youtube',
      'youtubeId': 'NwkWfIRi1BY', // HSK 2 vocabulary
      'startTime': 15.0,
      'endTime': 22.0,
      'hskLevel': 2,
      'transcription': '学习中文很有意思。',
      'pinyin': 'Xuéxí zhōngwén hěn yǒu yìsi.',
      'targetWords': ['zhong-wen'],
      'quizCategory': 'vocabulary',
      'quiz': {
        'question': '"中文" means:',
        'correctAnswer': 'Chinese language',
        'wrongAnswer': 'Chinese food',
      },
      'isActive': true,
      'createdAt': now.subtract(const Duration(minutes: 5)),
    },
    // ── GRAMMAR ───────────────────────────────────────────────────────────────
    {
      'videoId': 'video-gram-01',
      'sourceType': 'youtube',
      'youtubeId': 'NwkWfIRi1BY',
      'startTime': 55.0,
      'endTime': 63.0,
      'hskLevel': 2,
      'transcription': '我把书放在桌子上。',
      'pinyin': 'Wǒ bǎ shū fàng zài zhuōzi shàng.',
      'targetWords': ['wo'],
      'quizCategory': 'grammar',
      'quiz': {
        'question': '"把" is used to:',
        'correctAnswer': 'Indicate disposal of an object',
        'wrongAnswer': 'Express duration',
      },
      'isActive': true,
      'createdAt': now.subtract(const Duration(minutes: 6)),
    },
    {
      'videoId': 'video-gram-02',
      'sourceType': 'youtube',
      'youtubeId': 'NwkWfIRi1BY',
      'startTime': 80.0,
      'endTime': 88.0,
      'hskLevel': 3,
      'transcription': '虽然很贵，但是质量很好。',
      'pinyin': 'Suīrán hěn guì, dànshì zhìliàng hěn hǎo.',
      'targetWords': [],
      'quizCategory': 'grammar',
      'quiz': {
        'question': '"虽然…但是" means:',
        'correctAnswer': 'Although… but',
        'wrongAnswer': 'Because… therefore',
      },
      'isActive': true,
      'createdAt': now.subtract(const Duration(minutes: 7)),
    },
    // ── LISTENING ─────────────────────────────────────────────────────────────
    {
      'videoId': 'video-list-01',
      'sourceType': 'youtube',
      'youtubeId': '0yFBH87YLQM', // HSK listening practice
      'startTime': 10.0,
      'endTime': 17.0,
      'hskLevel': 1,
      'transcription': '你去哪里？我去图书馆。',
      'pinyin': 'Nǐ qù nǎlǐ? Wǒ qù túshūguǎn.',
      'targetWords': ['wo'],
      'quizCategory': 'listening',
      'quiz': {
        'question': 'Where is the speaker going?',
        'correctAnswer': 'The library',
        'wrongAnswer': 'The supermarket',
      },
      'isActive': true,
      'createdAt': now.subtract(const Duration(minutes: 8)),
    },
    {
      'videoId': 'video-list-02',
      'sourceType': 'youtube',
      'youtubeId': '0yFBH87YLQM',
      'startTime': 30.0,
      'endTime': 38.0,
      'hskLevel': 2,
      'transcription': '为什么你今天这么开心？',
      'pinyin': 'Wèishéme nǐ jīntiān zhème kāixīn?',
      'targetWords': ['jin-tian'],
      'quizCategory': 'listening',
      'quiz': {
        'question': '"为什么" means:',
        'correctAnswer': 'Why',
        'wrongAnswer': 'How',
      },
      'isActive': true,
      'createdAt': now.subtract(const Duration(minutes: 9)),
    },
    // ── CULTURE ───────────────────────────────────────────────────────────────
    {
      'videoId': 'video-cult-01',
      'sourceType': 'youtube',
      'youtubeId': 'BdXpFvkFsHs',
      'startTime': 90.0,
      'endTime': 98.0,
      'hskLevel': 2,
      'transcription': '春节是中国最重要的节日。',
      'pinyin': 'Chūnjié shì Zhōngguó zuì zhòngyào de jiérì.',
      'targetWords': ['chun-jie'],
      'quizCategory': 'culture',
      'quiz': {
        'question': '"春节" refers to:',
        'correctAnswer': 'Chinese New Year',
        'wrongAnswer': 'Mid-Autumn Festival',
      },
      'isActive': true,
      'createdAt': now.subtract(const Duration(minutes: 10)),
    },
    {
      'videoId': 'video-cult-02',
      'sourceType': 'youtube',
      'youtubeId': 'BdXpFvkFsHs',
      'startTime': 110.0,
      'endTime': 118.0,
      'hskLevel': 3,
      'transcription': '保护环境是我们的责任。',
      'pinyin': 'Bǎohù huánjìng shì wǒmen de zérèn.',
      'targetWords': ['huan-jing'],
      'quizCategory': 'culture',
      'quiz': {
        'question': '"环境" means:',
        'correctAnswer': 'Environment',
        'wrongAnswer': 'Culture',
      },
      'isActive': true,
      'createdAt': now.subtract(const Duration(minutes: 11)),
    },
    // ── CHARACTERS ────────────────────────────────────────────────────────────
    {
      'videoId': 'video-char-01',
      'sourceType': 'youtube',
      'youtubeId': '0yFBH87YLQM',
      'startTime': 60.0,
      'endTime': 67.0,
      'hskLevel': 1,
      'transcription': '水',
      'pinyin': 'shuǐ',
      'targetWords': ['shui'],
      'quizCategory': 'characters',
      'quiz': {
        'question': 'How many strokes does 水 have?',
        'correctAnswer': '4 strokes',
        'wrongAnswer': '6 strokes',
      },
      'isActive': true,
      'createdAt': now.subtract(const Duration(minutes: 12)),
    },
    {
      'videoId': 'video-char-02',
      'sourceType': 'youtube',
      'youtubeId': '0yFBH87YLQM',
      'startTime': 80.0,
      'endTime': 88.0,
      'hskLevel': 1,
      'transcription': '我',
      'pinyin': 'wǒ',
      'targetWords': ['wo'],
      'quizCategory': 'characters',
      'quiz': {
        'question': 'The radical of 我 is:',
        'correctAnswer': '戈 (spear)',
        'wrongAnswer': '手 (hand)',
      },
      'isActive': true,
      'createdAt': now.subtract(const Duration(minutes: 13)),
    },
  ];

  for (final video in videos) {
    final id = video['videoId'] as String;
    await _set('videos', id, video);
  }
}

Future<void> _seedUsers() async {
  print('\n👤 Seeding users...');

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
    'following': ['demo-user-002'],
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
    'createdAt': now.subtract(const Duration(days: 30)),
  });

  await _set('users', 'demo-user-003', {
    'uid': 'demo-user-003',
    'displayName': 'Yuki Tanaka',
    'email': 'yuki@mandarinacademy.test',
    'photoUrl': '',
    'hskLevel': 2,
    'isPremium': false,
    'aiCredits': 3,
    'followers': <String>[],
    'following': ['demo-user-002'],
    'learnedWords': ['ni-hao', 'shui', 'wo'],
    'isOnline': true,
    'stats': {
      'totalScore': 1100,
      'videosWatched': 18,
      'questionsAnswered': 30,
      'currentStreak': 7,
    },
    'createdAt': now.subtract(const Duration(days: 14)),
  });
}

Future<void> _seedPosts() async {
  print('\n📝 Seeding posts...');

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

  await _set('posts', 'post-003', {
    'postId': 'post-003',
    'authorId': 'demo-user-003',
    'content': '春节快乐！🧧 Just learned about Chinese New Year traditions.',
    'attachmentUrl': null,
    'likes': ['demo-user-002'],
    'postType': 'text',
    'metadata': <String, dynamic>{},
    'timestamp': now.subtract(const Duration(hours: 8)),
  });
}

// --------------------------------------------------------------------------
// Main
// --------------------------------------------------------------------------

Future<void> main() async {
  print('🌱 Mandarin Academy — Firestore Emulator Seed');
  print('   Project: $_projectId');
  print('   Firestore: http://localhost:$_firestorePort');
  print('');

  try {
    await http
        .get(Uri.parse('http://localhost:$_firestorePort'))
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    print('❌ Cannot reach Firestore emulator at localhost:$_firestorePort');
    print('   Run first: start_dev.bat');
    exit(1);
  }

  await _seedDictionary();
  await _seedVideos();
  await _seedUsers();
  await _seedPosts();

  print('\n✅ Seed complete!');
  print('   App:         http://localhost:9300');
  print('   Emulator UI: http://localhost:4001');
}
