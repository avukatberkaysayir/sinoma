import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/hsk1_words.dart';
import '../../core/constants/hsk2_words.dart';
import '../../core/constants/hsk3_words.dart';
import '../../core/constants/hsk4_words.dart';
import '../../core/constants/hsk5_words.dart';
import '../../core/constants/hsk6_words.dart';

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

  Future<String> createYoutubeAsrJob(
    String url, {
    bool active = false,
    List<int>? hskFilter,
  }) async {
    final res = await _db
        .from('pipeline_jobs')
        .insert({
          'job_type': 'youtube_asr',
          'payload': {
            'url': url,
            'active': active,
            if (hskFilter != null && hskFilter.isNotEmpty)
              'hsk_filter': hskFilter,
          },
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  // Enqueue a movie job. The local poller reads videoPath (a path on the
  // machine running the worker) from disk, extracts clips, uploads them to
  // Supabase Storage and inserts self_hosted rows. No localhost call, no
  // GB browser upload — the deployed admin only writes a pipeline_jobs row.
  Future<String> createMovieJob(
    String videoPath, {
    String? subPath,
    bool active = false,
    List<int>? hskFilter,
  }) async {
    final res = await _db
        .from('pipeline_jobs')
        .insert({
          'job_type': 'movie',
          'payload': {
            'video_path': videoPath,
            if (subPath != null && subPath.trim().isNotEmpty)
              'sub_path': subPath.trim(),
            'active': active,
            if (hskFilter != null && hskFilter.isNotEmpty)
              'hsk_filter': hskFilter,
          },
        })
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

  // Enqueue a Whisper job: the local worker transcribes the whole video once and
  // fills videos.whisper_text for every clip of that youtube_id, so the admin can
  // compare the auto-caption transcription with the Whisper draft and pick.
  Future<String> createWhisperJob(
    String url, {
    required double start,
    required double end,
    required String rowId,
  }) async {
    final res = await _db
        .from('pipeline_jobs')
        .insert({
          'job_type': 'whisper_clip',
          'payload': {'url': url, 'start': start, 'end': end, 'row_id': rowId},
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  // Re-read one video row (to pick up whisper_text after the job completes).
  Future<Map<String, dynamic>?> getVideo(String id) async {
    final data = await _db.from('videos').select().eq('id', id).maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> processYoutubeVideo(
    String url, {
    bool active = true,
    List<int>? hskFilter,
  }) async {
    try {
      final res = await _db.functions.invoke(
        'process-youtube',
        body: {
          'url': url,
          'active': active,
          if (hskFilter != null && hskFilter.isNotEmpty)
            'hsk_filter': hskFilter,
        },
      );
      if (res.status >= 300) {
        final err = (res.data as Map<String, dynamic>?)?['error']
            ?? 'İşlem başarısız (${res.status})';
        throw Exception(err);
      }
      return res.data as Map<String, dynamic>;
    } on FunctionException catch (e) {
      final details = e.details;
      String msg;
      if (details is Map) {
        msg = details['error'] as String? ?? 'İşlem başarısız (${e.status})';
      } else if (details is String) {
        try {
          final parsed = jsonDecode(details) as Map<String, dynamic>;
          msg = parsed['error'] as String? ?? details;
        } catch (_) {
          msg = details;
        }
      } else {
        msg = 'İşlem başarısız (${e.status})';
      }
      throw Exception(msg);
    }
  }

  // Generate quiz options (correct + close-wrong translation) via Gemini.
  // Used once, in the admin panel; the result is saved on the video and served
  // from the DB afterwards, so Gemini is never needed at playback time.
  Future<Map<String, String>> generateQuiz({
    required String transcription,
    String pinyin = '',
    String lang = 'tr',
    List<String> targetWords = const [],
  }) async {
    final res = await _db.functions.invoke(
      'generate-quiz',
      body: {
        'transcription': transcription,
        'pinyin': pinyin,
        'lang': lang,
        if (targetWords.isNotEmpty) 'targetWords': targetWords,
      },
    );
    if (res.status >= 300) {
      final err = (res.data as Map<String, dynamic>?)?['error']
          ?? 'Şık üretimi başarısız (${res.status})';
      throw Exception(err);
    }
    final d = res.data as Map<String, dynamic>;
    return {
      'question': d['question'] as String? ?? '',
      'correctAnswer': d['correctAnswer'] as String? ?? '',
      'wrongAnswer': d['wrongAnswer'] as String? ?? '',
    };
  }

  // Faithful translation (default Turkish) of a Chinese sentence — lets the
  // admin sanity-check that an ASR/Whisper transcription makes sense.
  Future<String> translateText(String text, {String lang = 'tr'}) async {
    final t = text.trim();
    if (t.isEmpty) return '';
    final res = await _db.functions.invoke(
      'translate',
      body: {'text': t, 'lang': lang},
    );
    if (res.status >= 300) {
      throw Exception((res.data as Map<String, dynamic>?)?['error']
          ?? 'Çeviri başarısız (${res.status})');
    }
    return (res.data as Map<String, dynamic>)['translation'] as String? ?? '';
  }

  // Pinyin for a whole sentence: segment it against the dictionary, then join
  // each word's dictionary pinyin. Used to refresh the pinyin field after the
  // sentence text changes (e.g. applying a Whisper transcription).
  Future<String> pinyinForText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return '';
    final words = await segmentSentence(t);
    final map = await pinyinForWords(words);
    final parts = words.map((w) => map[w] ?? '').where((p) => p.isNotEmpty);
    return parts.join(' ');
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
        .order('hsk_level', ascending: true)
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

  Future<void> hardDeleteVideos(List<String> ids) async {
    await _db.from('videos').delete().inFilter('id', ids);
  }

  Future<List<Map<String, dynamic>>> listVideosByYoutubeId(String ytId) async {
    final data = await _db
        .from('videos')
        .select()
        .eq('youtube_id', ytId)
        .order('start_time', ascending: true)
        .limit(200);
    return List<Map<String, dynamic>>.from(data);
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

  /// After an auto-import, deletes pending segments for [youtubeId] that either
  /// have no dictionary match (hsk_level = 0) or fall outside [hskFilter].
  /// Safe to call regardless of whether the edge function already filtered.
  Future<int> deleteNonMatchingPendingVideos(
    String youtubeId,
    List<int>? hskFilter,
  ) async {
    final data = await _db
        .from('videos')
        .select('id, hsk_level')
        .eq('youtube_id', youtubeId)
        .eq('status', 'pending');

    final rows = List<Map<String, dynamic>>.from(data as List);
    final idsToDelete = rows
        .where((r) {
          final level = (r['hsk_level'] as num?)?.toInt() ?? 0;
          if (level == 0) return true; // no dictionary match — always purge
          if (hskFilter != null && hskFilter.isNotEmpty) {
            return !hskFilter.contains(level);
          }
          return false;
        })
        .map((r) => r['id'] as String)
        .toList();

    if (idsToDelete.isEmpty) return 0;
    await _db.from('videos').delete().inFilter('id', idsToDelete);
    return idsToDelete.length;
  }

  // Which of these candidate strings exist in the dictionary (any HSK level).
  Future<Set<String>> existingDictionaryWords(List<String> words) async {
    if (words.isEmpty) return {};
    try {
      final data = await _db
          .from('dictionary')
          .select('simplified')
          .inFilter('simplified', words);
      return List<Map<String, dynamic>>.from(data)
          .map((e) => e['simplified'] as String)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  // Split a Chinese sentence into words via greedy longest-match against the
  // dictionary (max word length 4). Characters with no dictionary match stay as
  // single-char segments, so the segments always reconstruct the sentence.
  Future<List<String>> segmentSentence(String sentence) async {
    final s = sentence.trim();
    if (s.isEmpty) return [];
    const maxLen = 4;
    final cands = <String>{};
    for (var i = 0; i < s.length; i++) {
      for (var l = 2; l <= maxLen && i + l <= s.length; l++) {
        cands.add(s.substring(i, i + l));
      }
    }
    final valid = await existingDictionaryWords(cands.toList());
    final result = <String>[];
    var i = 0;
    while (i < s.length) {
      var chosen = s[i]; // fallback: single character
      for (var l = maxLen; l >= 2; l--) {
        if (i + l <= s.length && valid.contains(s.substring(i, i + l))) {
          chosen = s.substring(i, i + l);
          break;
        }
      }
      result.add(chosen);
      i += chosen.length;
    }
    return result;
  }

  // Dictionary pinyin for each of these words (for display when the edited
  // sentence differs from the original ASR pinyin). Missing words are omitted.
  Future<Map<String, String>> pinyinForWords(List<String> words) async {
    if (words.isEmpty) return {};
    try {
      final data = await _db
          .from('dictionary')
          .select('simplified,pinyin')
          .inFilter('simplified', words);
      return {
        for (final m in List<Map<String, dynamic>>.from(data))
          m['simplified'] as String: (m['pinyin'] as String? ?? ''),
      };
    } catch (_) {
      return {};
    }
  }

  // Which of these are in an HSK list (hsk_level 1-6) → green chips.
  // Words absent or with no HSK level count as "not in the list" → red.
  Future<Set<String>> wordsInDictionary(List<String> words) async {
    if (words.isEmpty) return {};
    try {
      final data = await _db
          .from('dictionary')
          .select('simplified')
          .gte('hsk_level', 1)
          .inFilter('simplified', words);
      return List<Map<String, dynamic>>.from(data)
          .map((e) => e['simplified'] as String)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> searchDictionary(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      // Insertion order is preserved → the exact match is always first, so a
      // word that exists never falls off the list (no spurious "add anyway").
      final byWord = <String, Map<String, dynamic>>{};

      final exact = await _db
          .from('dictionary')
          .select('id, simplified, pinyin, hsk_level')
          .eq('simplified', q)
          .limit(1);
      for (final m in List<Map<String, dynamic>>.from(exact)) {
        byWord[m['simplified'] as String] = m;
      }

      final fuzzy = await _db
          .from('dictionary')
          .select('id, simplified, pinyin, hsk_level')
          .or('simplified.ilike.%$q%,pinyin.ilike.%$q%,pinyin_ascii.ilike.%$q%')
          .limit(40);
      final list = List<Map<String, dynamic>>.from(fuzzy);
      // Rank: prefix matches first, then shorter words, then lower HSK level.
      int rank(Map<String, dynamic> m) {
        final s = m['simplified'] as String? ?? '';
        if (s == q) return 0;
        if (s.startsWith(q)) return 1;
        return 2;
      }
      list.sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        final la = (a['simplified'] as String? ?? '').length;
        final lb = (b['simplified'] as String? ?? '').length;
        if (la != lb) return la.compareTo(lb);
        final ha = (a['hsk_level'] as int?) ?? 99;
        final hb = (b['hsk_level'] as int?) ?? 99;
        return ha.compareTo(hb);
      });
      for (final m in list) {
        byWord.putIfAbsent(m['simplified'] as String, () => m);
      }

      return byWord.values.take(12).toList();
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

  /// Applies targeted definition corrections to the dictionary table.
  /// Called automatically on admin screen open. Add new corrections here
  /// whenever a constant file definition is updated.
  Future<void> applyDefinitionPatches() async {
    const patches = [
      // 草地: "grassland" — added ot/çimen so it appears in grass-related searches
      {
        'id': '草地', 'simplified': '草地', 'traditional': '草地',
        'pinyin': 'cǎodì', 'pinyin_ascii': 'caodi', 'hsk_level': 3,
        'definitions': {'en': 'grassland', 'tr': 'çayırlık, ot, çimen', 'vi': '', 'pos': 'noun'},
        'ai_context_cache': <String, dynamic>{}, 'radicals': <String>[], 'stroke_count': 0,
      },
    ];
    await _db.from('dictionary').upsert(patches);
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

  // ── Dictionary CRUD ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listDictionaryWords({
    List<int> hskLevels = const [],
    int offset = 0,
    int limit = 100,
  }) async {
    var base = _db
        .from('dictionary')
        .select('id,simplified,pinyin,hsk_level,definitions');
    final filtered = hskLevels.isNotEmpty
        ? base.inFilter('hsk_level', hskLevels)
        : base;
    final data = await filtered
        .order('hsk_level')
        .order('simplified')
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> saveDictionaryWord(Map<String, dynamic> word) async {
    final simplified = word['simplified'] as String;
    await _db.from('dictionary').upsert({
      'id': simplified,
      'simplified': simplified,
      'traditional': simplified,
      'pinyin': word['pinyin'] as String? ?? '',
      'pinyin_ascii': _stripAccents(word['pinyin'] as String? ?? ''),
      'hsk_level': (word['hsk_level'] as num?)?.toInt() ?? 1,
      'definitions': word['definitions'] ?? {'en': '', 'tr': '', 'vi': '', 'pos': ''},
      'ai_context_cache': <String, dynamic>{},
      'radicals': <String>[],
      'stroke_count': 0,
    });
  }

  Future<void> deleteDictionaryWord(String id) async {
    await _db.from('dictionary').delete().eq('id', id);
  }

  Future<void> updateDictionaryWord(String id, Map<String, dynamic> fields) async {
    if (fields.containsKey('pinyin')) {
      fields['pinyin_ascii'] = _stripAccents(fields['pinyin'] as String);
    }
    await _db.from('dictionary').update(fields).eq('id', id);
  }

  // ─────────────────────────────────────────────────────────────────────────

  /// Seeds HSK Level 4 words into the dictionary table.
  Future<int> seedHsk4Dictionary() async {
    const batchSize = 50;
    var total = 0;
    final seen = <String>{};
    final allRows = kHsk4Words
        .where((w) => seen.add(w[0]))
        .map((w) => {
              'id': w[0],
              'simplified': w[0],
              'traditional': w[0],
              'pinyin': w[1],
              'pinyin_ascii': _stripAccents(w[1]),
              'hsk_level': 4,
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

  /// Seeds HSK Level 5 words into the dictionary table.
  Future<int> seedHsk5Dictionary() async {
    const batchSize = 50;
    var total = 0;
    final seen = <String>{};
    final allRows = kHsk5Words
        .where((w) => seen.add(w[0]))
        .map((w) => {
              'id': w[0],
              'simplified': w[0],
              'traditional': w[0],
              'pinyin': w[1],
              'pinyin_ascii': _stripAccents(w[1]),
              'hsk_level': 5,
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

  /// Seeds HSK Level 6 words into the dictionary table.
  Future<int> seedHsk6Dictionary() async {
    const batchSize = 50;
    var total = 0;
    final seen = <String>{};
    final allRows = kHsk6Words
        .where((w) => seen.add(w[0]))
        .map((w) => {
              'id': w[0],
              'simplified': w[0],
              'traditional': w[0],
              'pinyin': w[1],
              'pinyin_ascii': _stripAccents(w[1]),
              'hsk_level': 6,
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

  // Word suggestions are stored as posts with post_type='text' and
  // metadata.is_word_suggestion=true. The posts table allows authenticated
  // INSERT; admin can SELECT all and DELETE via their RLS policy.
  Future<List<Map<String, dynamic>>> listWordSuggestions() async {
    final data = await _db
        .from('posts')
        .select('id, content, metadata, timestamp')
        .filter('metadata->>is_word_suggestion', 'eq', 'true')
        .order('timestamp', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> deleteWordSuggestion(String id) async {
    await _db.from('posts').delete().eq('id', id);
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
