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
import '../../core/constants/diger_words.dart';

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
    List<String>? wordFilter,
    List<String>? grammarFilter,
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
            if (wordFilter != null && wordFilter.isNotEmpty)
              'word_filter': wordFilter,
            if (grammarFilter != null && grammarFilter.isNotEmpty)
              'grammar_filter': grammarFilter,
          },
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  // ── Home (path) design assets — banner / landmark photos / phase icons ──────
  static const _paBucket = 'path-assets';

  Future<List<Map<String, dynamic>>> loadPathAssets(int level, int unit) async {
    final data = await _db
        .from('path_assets')
        .select()
        .eq('level', level)
        .eq('unit', unit);
    return List<Map<String, dynamic>>.from(data);
  }

  // Storage object path embedded in a public URL (…/path-assets/<path>?v=…).
  String? _paPathFromUrl(String? url) {
    if (url == null) return null;
    final m = RegExp(r'/path-assets/([^?]+)').firstMatch(url);
    return m?.group(1);
  }

  Future<String> uploadPathAsset(
    int level,
    int unit,
    String kind,
    int slot,
    Uint8List bytes,
    String ext,
  ) async {
    // Remove the previous file (it may have a different extension) to avoid
    // orphans, then upload the new one and upsert the row.
    final existing = await _db
        .from('path_assets')
        .select('url')
        .eq('level', level)
        .eq('unit', unit)
        .eq('kind', kind)
        .eq('slot', slot)
        .maybeSingle();
    final oldPath = _paPathFromUrl(existing?['url'] as String?);
    if (oldPath != null) {
      try {
        await _db.storage.from(_paBucket).remove([oldPath]);
      } catch (_) {}
    }
    final path = 'L$level/U$unit/${kind}_$slot.$ext';
    await _db.storage.from(_paBucket).uploadBinary(path, bytes,
        fileOptions: const FileOptions(upsert: true));
    final url = '${_db.storage.from(_paBucket).getPublicUrl(path)}'
        '?v=${DateTime.now().millisecondsSinceEpoch}';
    await _db.from('path_assets').upsert({
      'level': level,
      'unit': unit,
      'kind': kind,
      'slot': slot,
      'url': url,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'level,unit,kind,slot');
    return url;
  }

  Future<void> deletePathAsset(
      int level, int unit, String kind, int slot) async {
    final row = await _db
        .from('path_assets')
        .select('url')
        .eq('level', level)
        .eq('unit', unit)
        .eq('kind', kind)
        .eq('slot', slot)
        .maybeSingle();
    final path = _paPathFromUrl(row?['url'] as String?);
    if (path != null) {
      try {
        await _db.storage.from(_paBucket).remove([path]);
      } catch (_) {}
    }
    // Keep a photo row if it still has a description; otherwise drop the row.
    await _db
        .from('path_assets')
        .update({'url': null}).match({
      'level': level,
      'unit': unit,
      'kind': kind,
      'slot': slot,
    });
  }

  Future<void> savePathAssetScale(
      int level, int unit, String kind, int slot, double scale) async {
    await _db.from('path_assets').upsert({
      'level': level,
      'unit': unit,
      'kind': kind,
      'slot': slot,
      'scale': scale,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'level,unit,kind,slot');
  }

  // Per-language description overrides for one landmark photo. Stores the full
  // {lang: text} map in desc_i18n and mirrors TR/EN into the legacy columns.
  Future<void> savePathPhotoDesc(
      int level, int unit, int slot, Map<String, String> desc) async {
    final clean = <String, String>{
      for (final e in desc.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
    };
    await _db.from('path_assets').upsert({
      'level': level,
      'unit': unit,
      'kind': 'photo',
      'slot': slot,
      'desc_tr': clean['tr'] ?? '',
      'desc_en': clean['en'] ?? '',
      'desc_i18n': clean,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'level,unit,kind,slot');
  }

  // ── Import history ─────────────────────────────────────────────────────────

  // Record (or refresh) that this YouTube video was segmented. Upsert by
  // youtube_id so a re-import updates the row instead of duplicating it.
  Future<void> recordImport(
    String youtubeId,
    String url, {
    int clipCount = 0,
    List<int>? hskFilter,
    List<String>? grammarFilter,
    List<String>? wordFilter,
  }) async {
    await _db.from('import_history').upsert({
      'youtube_id': youtubeId,
      'url': url,
      'clip_count': clipCount,
      'hsk_filter': hskFilter,
      'grammar_filter': grammarFilter,
      'word_filter': wordFilter,
      'segmented_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'youtube_id');
  }

  // The prior import of this video, or null — drives the re-import warning.
  Future<Map<String, dynamic>?> findImport(String youtubeId) async {
    final data = await _db
        .from('import_history')
        .select()
        .eq('youtube_id', youtubeId)
        .maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  // How many active / backup clips each source video currently has — the library
  // list shows only videos with at least one (pending-only imports are hidden).
  Future<Map<String, ({int active, int backup})>>
      loadActiveBackupCounts() async {
    final data = await _db
        .from('videos')
        .select('youtube_id, status')
        .inFilter('status', ['active', 'backup']);
    final rows = List<Map<String, dynamic>>.from(data);
    final m = <String, ({int active, int backup})>{};
    for (final r in rows) {
      final id = r['youtube_id'] as String?;
      if (id == null || id.isEmpty) continue;
      final cur = m[id] ?? (active: 0, backup: 0);
      m[id] = r['status'] == 'active'
          ? (active: cur.active + 1, backup: cur.backup)
          : (active: cur.active, backup: cur.backup + 1);
    }
    return m;
  }

  // Full segmentation history, newest first.
  Future<List<Map<String, dynamic>>> loadImportHistory() async {
    final data = await _db
        .from('import_history')
        .select()
        .order('segmented_at', ascending: false)
        .limit(500);
    return List<Map<String, dynamic>>.from(data);
  }

  // Ask the local worker to fetch channel/title/year for this video (yt-dlp) and
  // fill them into import_history. Fire-and-forget; works only while the worker
  // runs, but history + the warning don't depend on it.
  Future<void> enqueueVideoMeta(String youtubeId, String url) async {
    await _db.from('pipeline_jobs').insert({
      'job_type': 'video_meta',
      'payload': {'url': url, 'youtube_id': youtubeId},
    });
  }

  // Clips with their placement + source, for the history placement view. When
  // [backup] is true, reads the backup_* slot and returns it under the same keys
  // (level/unit/phase/slot_grammar/slot_word) so the view code is identical.
  Future<List<Map<String, dynamic>>> loadPlacements(
      {bool backup = false}) async {
    if (backup) {
      final data = await _db
          .from('videos')
          .select('youtube_id, source_type, video_url, start_time, end_time, '
              'backup_level, backup_unit, backup_phase, backup_grammar, '
              'backup_word, transcription, hsk_level')
          .eq('status', 'backup')
          .order('backup_level')
          .order('backup_unit')
          .order('backup_phase');
      return List<Map<String, dynamic>>.from(data)
          .map((r) => {
                ...r,
                'level': r['backup_level'],
                'unit': r['backup_unit'],
                'phase': r['backup_phase'],
                'slot_grammar': r['backup_grammar'],
                'slot_word': r['backup_word'],
              })
          .toList();
    }
    final data = await _db
        .from('videos')
        .select('youtube_id, source_type, video_url, start_time, end_time, '
            'level, unit, phase, slot_grammar, slot_word, transcription, hsk_level')
        .eq('status', 'active')
        .order('level')
        .order('unit')
        .order('phase');
    return List<Map<String, dynamic>>.from(data);
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

  // True if the local worker is mid-job (any pipeline_jobs row 'processing').
  // Lets the UI tell "worker busy with a long split" apart from "worker down"
  // so a queued Whisper job isn't falsely reported as a dead worker.
  Future<bool> anyJobProcessing() async {
    final res = await _db
        .from('pipeline_jobs')
        .select('id')
        .eq('status', 'processing')
        .limit(1);
    return (res as List).isNotEmpty;
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

  // Per (level,unit,phase) slot-fill stats for the Aktif/Yedek cascade colouring
  // (red = no video, yellow = partial, green = every slot filled).
  Future<List<Map<String, dynamic>>> loadPathFillStats() async {
    final res = await _db.rpc('path_fill_stats');
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
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
  Future<Map<String, dynamic>> generateQuiz({
    required String transcription,
    String pinyin = '',
    String lang = 'tr',
    List<String> targetWords = const [],
    String sourceEn = '',
    String sourceEnWrong = '',
    List<String> targetLangs = const [],
  }) async {
    final res = await _db.functions.invoke(
      'generate-quiz',
      body: {
        'transcription': transcription,
        'pinyin': pinyin,
        'lang': lang,
        if (targetWords.isNotEmpty) 'targetWords': targetWords,
        // Pivot: non-English options translate BOTH approved English options
        // (correct + the chosen wrong distractor) instead of inventing a new one.
        if (sourceEn.trim().isNotEmpty) 'sourceEn': sourceEn.trim(),
        if (sourceEnWrong.trim().isNotEmpty) 'sourceEnWrong': sourceEnWrong.trim(),
        // Batch: generate English + these languages in one call (fewer Gemini hits).
        if (targetLangs.isNotEmpty) 'targetLangs': targetLangs,
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
      // Batch extras: {'tr': {'correctAnswer':..,'wrongAnswer':..}, ...}
      'extra': d['extra'],
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

  // All requested languages in ONE Gemini call (e.g. ['tr','ko'] for the
  // Önerilen editor) — single words come back as dictionary glosses.
  Future<Map<String, String>> translateMulti(
      String text, List<String> langs) async {
    final t = text.trim();
    if (t.isEmpty) return {};
    final res = await _db.functions.invoke(
      'translate',
      body: {'text': t, 'langs': langs},
    );
    if (res.status >= 300) {
      throw Exception((res.data as Map<String, dynamic>?)?['error'] ??
          'Çeviri başarısız (${res.status})');
    }
    final raw = (res.data as Map<String, dynamic>)['translations']
            as Map<String, dynamic>? ??
        {};
    return raw.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  // Pinyin for a whole sentence: segment it against the dictionary, then join
  // each word's dictionary pinyin. Used to refresh the pinyin field after the
  // sentence text changes (e.g. applying a Whisper transcription).
  // Polyphonic entries store ALL readings comma-separated ('xíng, háng');
  // sentence pinyin uses only the first (most common) one.
  static String firstReading(String p) => p.split(',').first.trim();

  Future<String> pinyinForText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return '';
    final words = await segmentSentence(t);
    final map = await pinyinForWords(words);
    final parts = words
        .map((w) => firstReading(map[w] ?? ''))
        .where((p) => p.isNotEmpty);
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

  // Backup ("Yedek") store: active/pending clips that couldn't become an active
  // slot occupant (one-clip-per-item) but carry a would-be slot (backup_*).
  Future<List<Map<String, dynamic>>> listBackupVideos() async {
    final data = await _db
        .from('videos')
        .select()
        .inFilter('status', ['active', 'pending'])
        .not('backup_kind', 'is', null)
        .order('backup_level')
        .order('backup_unit')
        .order('backup_phase')
        .limit(5000);
    return List<Map<String, dynamic>>.from(data);
  }

  // User-submitted "Sorun Bildir" notes, newest first, with reporter + clip.
  Future<List<Map<String, dynamic>>> loadReports() async {
    final data = await _db
        .from('video_reports')
        .select('id, message, created_at, video_id, '
            'users(display_name, username, email), '
            'videos(transcription, status, hsk_level, level, unit, phase, '
            'backup_level, backup_unit, backup_phase)')
        .order('created_at', ascending: false)
        .limit(300);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> deleteReport(String id) async {
    await _db.from('video_reports').delete().eq('id', id);
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

  // Move clips into the backup ("Yedek") store (kept out of the active feed).
  Future<void> moveVideosToBackup(List<String> ids) async {
    await _db
        .from('videos')
        .update({'status': 'backup', 'is_active': false}).inFilter('id', ids);
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

  // Returns the updated row so callers can read values the DB trigger derived
  // (level/unit/phase, pruned quiz_categories, …).
  Future<Map<String, dynamic>?> patchVideoFields(
      String docId, Map<String, dynamic> fields) async {
    final row = await _db
        .from('videos')
        .update(fields)
        .eq('id', docId)
        .select()
        .maybeSingle();
    return row;
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
  /// have no dictionary match (hsk_level = 0), fall outside [hskFilter], or — when
  /// [grammarFilter]/[wordFilter] is set — aren't taught THROUGH one of the
  /// selected items. The criterion is what the assign_video_path trigger pinned
  /// the clip on: slot_word/slot_grammar (placed) or backup_word/backup_grammar
  /// (backup). Matching the criterion (not mere target-word containment) means
  /// picking some HSK-1 words keeps only clips whose teaching item is one of those
  /// words — a clip that merely mentions the word but teaches a higher-level
  /// criterion is dropped. Safe to call regardless of whether the edge function /
  /// pipeline already filtered.
  Future<int> deleteNonMatchingPendingVideos(
    String youtubeId,
    List<int>? hskFilter, {
    List<String>? grammarFilter,
    List<String>? wordFilter,
  }) async {
    final data = await _db
        .from('videos')
        .select('id, hsk_level, slot_word, slot_grammar, '
            'backup_word, backup_grammar')
        .eq('youtube_id', youtubeId)
        .eq('status', 'pending');

    final gf = (grammarFilter == null || grammarFilter.isEmpty)
        ? null
        : grammarFilter.toSet();
    final wf = (wordFilter == null || wordFilter.isEmpty)
        ? null
        : wordFilter.toSet();
    final rows = List<Map<String, dynamic>>.from(data as List);
    final idsToDelete = rows
        .where((r) {
          final level = (r['hsk_level'] as num?)?.toInt() ?? 0;
          if (level == 0) return true; // no dictionary match — always purge
          if (hskFilter != null &&
              hskFilter.isNotEmpty &&
              !hskFilter.contains(level)) {
            return true;
          }
          // Criterion filter: keep only clips whose assigned teaching item (slot
          // or backup word/grammar) is one of the selected words/grammars.
          if (gf != null || wf != null) {
            final word =
                (r['slot_word'] ?? r['backup_word']) as String?;
            final gram =
                (r['slot_grammar'] ?? r['backup_grammar']) as String?;
            final wordOk = wf != null && word != null && wf.contains(word);
            final grammarOk = gf != null && gram != null && gf.contains(gram);
            if (!wordOk && !grammarOk) return true;
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
    // Proper nouns (people/places/brands, e.g. 巴塞罗那) must survive as ONE
    // word even when the dictionary doesn't know them — otherwise they break
    // into meaningless single characters. Gemini lists them; treated as valid
    // words with priority over dictionary matches.
    final nouns = await properNounsIn(s);
    final result = <String>[];
    var i = 0;
    while (i < s.length) {
      var chosen = s[i]; // fallback: single character
      // Longest proper noun starting here wins.
      for (final n in nouns) {
        if (n.length > chosen.length && s.startsWith(n, i)) chosen = n;
      }
      if (chosen.length == 1) {
        for (var l = maxLen; l >= 2; l--) {
          if (i + l <= s.length && valid.contains(s.substring(i, i + l))) {
            chosen = s.substring(i, i + l);
            break;
          }
        }
      }
      result.add(chosen);
      i += chosen.length;
    }
    return result;
  }

  // Proper nouns appearing verbatim in the text (best-effort; empty on error).
  Future<List<String>> properNounsIn(String text) async {
    try {
      final res = await _db.functions.invoke(
        'translate',
        body: {'text': text, 'mode': 'proper-nouns'},
      );
      if (res.status >= 300) return [];
      final list =
          (res.data as Map<String, dynamic>)['nouns'] as List<dynamic>? ?? [];
      final nouns = list.map((e) => e.toString()).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      return nouns;
    } catch (_) {
      return [];
    }
  }

  // Dictionary pinyin for each of these words (for display when the edited
  // sentence differs from the original ASR pinyin). Missing words are omitted.
  Future<Map<String, String>> pinyinForWords(List<String> words) async {
    // Drop the multi-sentence line-break sentinel + blanks — a literal newline
    // in the PostgREST `in.()` filter makes the request hang (admin pending tab
    // stuck spinning).
    final clean =
        words.where((w) => w != '\n' && w.trim().isNotEmpty).toSet().toList();
    if (clean.isEmpty) return {};
    try {
      final data = await _db
          .from('dictionary')
          .select('simplified,pinyin')
          .inFilter('simplified', clean);
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
    final clean =
        words.where((w) => w != '\n' && w.trim().isNotEmpty).toSet().toList();
    if (clean.isEmpty) return {};
    try {
      final data = await _db
          .from('dictionary')
          .select('simplified')
          .gte('hsk_level', 1)
          .inFilter('simplified', clean);
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
        'definitions': {
          'en': w[3],
          'tr': w[4],
          'ko': w.length > 5 ? w[5] : '',
          'ja': w.length > 6 ? w[6] : '',
          'id': w.length > 7 ? w[7] : '',
          'vi': w.length > 8 ? w[8] : '',
          'th': w.length > 9 ? w[9] : '',
          'ru': w.length > 10 ? w[10] : '',
          'es': w.length > 11 ? w[11] : '',
          'pt': w.length > 12 ? w[12] : '',
          'fr': w.length > 13 ? w[13] : '',
          'ar': w.length > 14 ? w[14] : '',
          'pos': w[2],
        },
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
        'definitions': {
          'en': w[3],
          'tr': w[4],
          'ko': w.length > 5 ? w[5] : '',
          'ja': w.length > 6 ? w[6] : '',
          'id': w.length > 7 ? w[7] : '',
          'vi': w.length > 8 ? w[8] : '',
          'th': w.length > 9 ? w[9] : '',
          'ru': w.length > 10 ? w[10] : '',
          'es': w.length > 11 ? w[11] : '',
          'pt': w.length > 12 ? w[12] : '',
          'fr': w.length > 13 ? w[13] : '',
          'ar': w.length > 14 ? w[14] : '',
          'pos': w[2],
        },
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
              'definitions': {
          'en': w[3],
          'tr': w[4],
          'ko': w.length > 5 ? w[5] : '',
          'ja': w.length > 6 ? w[6] : '',
          'id': w.length > 7 ? w[7] : '',
          'vi': w.length > 8 ? w[8] : '',
          'th': w.length > 9 ? w[9] : '',
          'ru': w.length > 10 ? w[10] : '',
          'es': w.length > 11 ? w[11] : '',
          'pt': w.length > 12 ? w[12] : '',
          'fr': w.length > 13 ? w[13] : '',
          'ar': w.length > 14 ? w[14] : '',
          'pos': w[2],
        },
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
              'definitions': {
          'en': w[3],
          'tr': w[4],
          'ko': w.length > 5 ? w[5] : '',
          'ja': w.length > 6 ? w[6] : '',
          'id': w.length > 7 ? w[7] : '',
          'vi': w.length > 8 ? w[8] : '',
          'th': w.length > 9 ? w[9] : '',
          'ru': w.length > 10 ? w[10] : '',
          'es': w.length > 11 ? w[11] : '',
          'pt': w.length > 12 ? w[12] : '',
          'fr': w.length > 13 ? w[13] : '',
          'ar': w.length > 14 ? w[14] : '',
          'pos': w[2],
        },
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
              'definitions': {
          'en': w[3],
          'tr': w[4],
          'ko': w.length > 5 ? w[5] : '',
          'ja': w.length > 6 ? w[6] : '',
          'id': w.length > 7 ? w[7] : '',
          'vi': w.length > 8 ? w[8] : '',
          'th': w.length > 9 ? w[9] : '',
          'ru': w.length > 10 ? w[10] : '',
          'es': w.length > 11 ? w[11] : '',
          'pt': w.length > 12 ? w[12] : '',
          'fr': w.length > 13 ? w[13] : '',
          'ar': w.length > 14 ? w[14] : '',
          'pos': w[2],
        },
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
              'definitions': {
          'en': w[3],
          'tr': w[4],
          'ko': w.length > 5 ? w[5] : '',
          'ja': w.length > 6 ? w[6] : '',
          'id': w.length > 7 ? w[7] : '',
          'vi': w.length > 8 ? w[8] : '',
          'th': w.length > 9 ? w[9] : '',
          'ru': w.length > 10 ? w[10] : '',
          'es': w.length > 11 ? w[11] : '',
          'pt': w.length > 12 ? w[12] : '',
          'fr': w.length > 13 ? w[13] : '',
          'ar': w.length > 14 ? w[14] : '',
          'pos': w[2],
        },
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

  // Auto-suggest dictionary entries for clip words NOT in the dictionary (the
  // red chips) — fired when a pending clip is saved/approved or backed up.
  static final _cjkRe = RegExp(r'[一-鿿]');

  Future<void> suggestMissingWords(List<String> words) async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return;
      final clean = words
          .map((w) => w.trim())
          .where((w) => w != '\n' && _cjkRe.hasMatch(w))
          .toSet()
          .toList();
      if (clean.isEmpty) return;
      final known = await wordsInDictionary(clean);
      final missing = clean.where((w) => !known.contains(w)).toList();
      if (missing.isEmpty) return;
      // Skip words that already sit in the suggestion queue.
      final existing = await _db
          .from('posts')
          .select('content')
          .filter('metadata->>is_word_suggestion', 'eq', 'true')
          .inFilter('content', missing);
      final dup = List<Map<String, dynamic>>.from(existing)
          .map((r) => r['content'] as String)
          .toSet();
      for (final w in missing.where((w) => !dup.contains(w))) {
        await _db.from('posts').insert({
          'author_id': uid,
          'content': w,
          'post_type': 'text',
          'likes': [],
          'metadata': {
            'is_word_suggestion': true,
            'word': w,
            'suggested_by_email': _db.auth.currentUser?.email ?? '',
            'source': 'clip_save',
          },
        });
      }
    } catch (_) {/* suggestions are best-effort, never block a save */}
  }

  // Mirror lib/core/constants/diger_words.dart (the canonical "Diğer" list,
  // regenerated by tools/sync_diger_words.py) back into the dictionary —
  // same pattern as the HSK seeders, so a fresh DB gets the words back.
  Future<int> seedDigerDictionary() async {
    if (kDigerWords.isEmpty) return 0;
    const batchSize = 50;
    var total = 0;
    for (var i = 0; i < kDigerWords.length; i += batchSize) {
      final rows = kDigerWords
          .sublist(i, (i + batchSize).clamp(0, kDigerWords.length))
          .map((w) => {
                'id': w[0],
                'simplified': w[0],
                'traditional': w[0],
                'pinyin': w[1],
                'pinyin_ascii': _stripAccents(w[1]),
                'hsk_level': 7,
                'definitions': {
          'en': w[3],
          'tr': w[4],
          'ko': w.length > 5 ? w[5] : '',
          'ja': w.length > 6 ? w[6] : '',
          'id': w.length > 7 ? w[7] : '',
          'vi': w.length > 8 ? w[8] : '',
          'th': w.length > 9 ? w[9] : '',
          'ru': w.length > 10 ? w[10] : '',
          'es': w.length > 11 ? w[11] : '',
          'pt': w.length > 12 ? w[12] : '',
          'fr': w.length > 13 ? w[13] : '',
          'ar': w.length > 14 ? w[14] : '',
          'pos': w[2],
        },
                'ai_context_cache': <String, dynamic>{},
                'radicals': <String>[],
                'stroke_count': 0,
              })
          .toList();
      await _db.from('dictionary').upsert(rows, onConflict: 'id');
      total += rows.length;
    }
    return total;
  }

  // Save a non-HSK word into the dictionary as level 7 ("Diğer"): it appears
  // in the sözlük, turns the admin chips green and powers the player word
  // popup — but is NEVER a path criterion (the placement trigger reads only
  // path_word_slots / grammar_levels, which stay untouched).
  Future<void> saveOtherWord({
    required String word,
    required String pinyin,
    required String en,
    required String tr,
    String ko = '',
    String ja = '',
    String id = '',
    String vi = '',
    String th = '',
    String ru = '',
    String es = '',
    String pt = '',
    String fr = '',
    String ar = '',
  }) async {
    await _db.from('dictionary').upsert({
      'id': word,
      'simplified': word,
      'traditional': word,
      'pinyin': pinyin.trim(),
      'pinyin_ascii': _stripAccents(pinyin.trim()),
      'hsk_level': 7,
      'definitions': {
        'en': en.trim(),
        'tr': tr.trim(),
        'ko': ko.trim(),
        'ja': ja.trim(),
        'id': id.trim(),
        'vi': vi.trim(),
        'th': th.trim(),
        'ru': ru.trim(),
        'es': es.trim(),
        'pt': pt.trim(),
        'fr': fr.trim(),
        'ar': ar.trim(),
        'pos': '',
      },
      'ai_context_cache': <String, dynamic>{},
      'radicals': <String>[],
      'stroke_count': 0,
    }, onConflict: 'id');
    // A new dictionary word can green-light clips that were waiting on it:
    // re-derive placements for unplaced pending/backup clips and drop
    // pointless pending duplicates of already-active ones.
    try {
      await _db.rpc('reevaluate_unplaced_videos');
    } catch (_) {/* best-effort */}
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
