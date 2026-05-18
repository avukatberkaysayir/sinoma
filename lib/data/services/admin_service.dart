import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/hsk1_words.dart';
import '../../core/constants/hsk2_words.dart';
import '../../core/constants/hsk3_words.dart';

class AdminService {
  SupabaseClient get _db => Supabase.instance.client;

  static const _pipelineBase = 'http://localhost:9302';

  // ── Pipeline server (local dev tool) ───────────────────────────────────────

  Future<bool> isPipelineServerRunning() async {
    try {
      final res = await http
          .get(Uri.parse('$_pipelineBase/health'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isFfmpegAvailable() async {
    try {
      final res = await http
          .get(Uri.parse('$_pipelineBase/ffmpeg-check'))
          .timeout(const Duration(seconds: 3));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['available'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> processMovieFile(
    String videoPath, {
    String? subPath,
    int maxClips = 0,
    int offset = 0,
    bool active = false,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_pipelineBase/process-movie'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'video_path': videoPath,
            if (subPath != null && subPath.isNotEmpty) 'sub_path': subPath,
            'max_clips': maxClips,
            'offset': offset,
            'active': active,
          }),
        )
        .timeout(const Duration(minutes: 35));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 300) {
      throw Exception(
          body['error'] ?? 'Movie processing failed (${res.statusCode})');
    }
    return body;
  }

  Future<String> createYoutubeAsrJob(String url, {bool active = false}) async {
    final res = await _db
        .from('pipeline_jobs')
        .insert({'job_type': 'youtube_asr', 'payload': {'url': url, 'active': active}})
        .select('id')
        .single();
    return res['id'] as String;
  }

  Future<Map<String, dynamic>> getJob(String jobId) async {
    final res = await _db
        .from('pipeline_jobs')
        .select()
        .eq('id', jobId)
        .single();
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> processYoutubeVideo(
    String url, {
    bool active = true,
  }) async {
    final res = await _db.functions.invoke(
      'process-youtube',
      body: {'url': url, 'active': active},
    );
    if (res.status >= 300) {
      final err = (res.data as Map<String, dynamic>?)?['error']
          ?? 'İşlem başarısız (${res.status})';
      throw Exception(err);
    }
    return res.data as Map<String, dynamic>;
  }

  // ── Supabase CRUD ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listVideos() async {
    final data = await _db
        .from('videos')
        .select()
        .order('hsk_level')
        .limit(200);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> listVideosByStatus(String status) async {
    final data = await _db
        .from('videos')
        .select()
        .eq('status', status)
        .order('created_at', ascending: false)
        .limit(500);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> approveVideos(List<String> ids) async {
    await _db
        .from('videos')
        .update({'status': 'active', 'is_active': true})
        .inFilter('id', ids);
  }

  Future<void> softDeleteVideos(List<String> ids) async {
    await _db
        .from('videos')
        .update({'status': 'deleted', 'is_active': false})
        .inFilter('id', ids);
  }

  Future<void> restoreVideos(List<String> ids) async {
    await _db
        .from('videos')
        .update({'status': 'pending', 'is_active': false})
        .inFilter('id', ids);
  }

  Future<void> setVideo(String docId, Map<String, dynamic> data) async {
    await _db.from('videos').upsert({'id': docId, ...data});
  }

  Future<void> updateField(String docId, String field, dynamic value) async {
    await _db.from('videos').update({field: value}).eq('id', docId);
  }

  Future<void> deleteVideo(String docId) async {
    await _db.from('videos').delete().eq('id', docId);
  }

  Future<int> deleteSeedVideos() async {
    final all = await listVideos();
    final seedIds = all
        .map((v) => v['id'] as String)
        .where((id) => id.startsWith('video-'))
        .toList();
    for (final id in seedIds) {
      await deleteVideo(id);
    }
    return seedIds.length;
  }

  Future<void> patchVideoFields(
      String docId, Map<String, dynamic> fields) async {
    await _db.from('videos').update(fields).eq('id', docId);
  }

  Future<Map<String, dynamic>> processMovieFileBytes(
    Uint8List bytes, {
    required String fileName,
    int maxClips = 50,
    bool active = false,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_pipelineBase/process-movie-upload'),
    );
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
    ));
    request.fields['max_clips'] = '$maxClips';
    request.fields['active'] = '$active';

    final streamed = await request.send().timeout(const Duration(minutes: 35));
    final response = await http.Response.fromStream(streamed);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 300) {
      throw Exception(body['error'] ?? 'Movie processing failed (${response.statusCode})');
    }
    return body;
  }

  Future<List<Map<String, dynamic>>> searchDictionary(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final data = await _db
          .from('dictionary')
          .select('id, simplified, pinyin, hsk_level')
          .or('simplified.ilike.%$q%,pinyin.ilike.%$q%,pinyin_ascii.ilike.%$q%')
          .order('hsk_level')
          .limit(8);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  /// Seeds all 300 HSK Level 1 words into the dictionary table.
  /// Returns the number of words upserted.
  Future<int> seedHsk1Dictionary() async {
    const batchSize = 50;
    var total = 0;
    for (var i = 0; i < kHsk1Words.length; i += batchSize) {
      final batch = kHsk1Words.sublist(
        i,
        (i + batchSize).clamp(0, kHsk1Words.length),
      );
      final rows = batch.map((w) => {
        'id': w[0],
        'simplified': w[0],
        'traditional': w[0],
        'pinyin': w[1],
        'pinyin_ascii': _stripAccents(w[1]),
        'hsk_level': 1,
        'definitions': {'en': w[3], 'tr': w[4], 'vi': '', 'pos': w[2]},
        'ai_context_cache': <String, dynamic>{},
        'radicals': <String>[],
        'stroke_count': 0,
      }).toList();
      await _db.from('dictionary').upsert(rows);
      total += rows.length;
    }
    return total;
  }

  /// Seeds all 198 HSK Level 2 words into the dictionary table.
  Future<int> seedHsk2Dictionary() async {
    const batchSize = 50;
    var total = 0;
    for (var i = 0; i < kHsk2Words.length; i += batchSize) {
      final batch = kHsk2Words.sublist(
        i,
        (i + batchSize).clamp(0, kHsk2Words.length),
      );
      final rows = batch.map((w) => {
        'id': w[0],
        'simplified': w[0],
        'traditional': w[0],
        'pinyin': w[1],
        'pinyin_ascii': _stripAccents(w[1]),
        'hsk_level': 2,
        'definitions': {'en': w[3], 'tr': w[4], 'vi': '', 'pos': w[2]},
        'ai_context_cache': <String, dynamic>{},
        'radicals': <String>[],
        'stroke_count': 0,
      }).toList();
      await _db.from('dictionary').upsert(rows);
      total += rows.length;
    }
    return total;
  }

  /// Seeds HSK Level 3 words into the dictionary table.
  Future<int> seedHsk3Dictionary() async {
    const batchSize = 50;
    var total = 0;
    final seen = <String>{};
    final allRows = kHsk3Words
        .where((w) => seen.add(w[0]))
        .map((w) => {
              'id': w[0],
              'simplified': w[0],
              'traditional': w[0],
              'pinyin': w[1],
              'pinyin_ascii': _stripAccents(w[1]),
              'hsk_level': 3,
              'definitions': {'en': w[3], 'tr': w[4], 'vi': '', 'pos': w[2]},
              'ai_context_cache': <String, dynamic>{},
              'radicals': <String>[],
              'stroke_count': 0,
            })
        .toList();
    for (var i = 0; i < allRows.length; i += batchSize) {
      final batch = allRows.sublist(i, (i + batchSize).clamp(0, allRows.length));
      await _db.from('dictionary').upsert(batch);
      total += batch.length;
    }
    return total;
  }

  static String _stripAccents(String pinyin) {
    const accentMap = {
      'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
      'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
      'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
      'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
      'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
      'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v', 'ü': 'v',
    };
    var result = pinyin.toLowerCase();
    for (final entry in accentMap.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }
}
