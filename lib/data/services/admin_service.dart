import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<Map<String, dynamic>> processYoutubeVideo(
    String url, {
    bool active = true,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_pipelineBase/process-video'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'url': url, 'active': active}),
        )
        .timeout(const Duration(minutes: 12));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 300) {
      throw Exception(body['error'] ?? 'Processing failed (${res.statusCode})');
    }
    return body;
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
}
