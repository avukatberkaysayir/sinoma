import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/video_segment_model.dart';
import '../../../data/services/admin_service.dart';

// ── Admin Screen ──────────────────────────────────────────────────────────────

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final _service = AdminService();
  late final TabController _tabs;

  List<Map<String, dynamic>> _videos = [];
  bool _loadingVideos = true;
  String? _videosError;
  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: 0);
    _loadVideos();
    // Auto-seed dictionary on every admin panel open if < 150 words exist.
    _service.seedHsk1Dictionary();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    setState(() { _loadingVideos = true; _videosError = null; });
    try {
      final videos = await _service.listVideos();
      videos.sort((a, b) =>
          ((a['hsk_level'] as int?) ?? 1)
              .compareTo((b['hsk_level'] as int?) ?? 1));
      if (mounted) setState(() { _videos = videos; _loadingVideos = false; });
    } catch (e) {
      if (mounted) setState(() { _videosError = e.toString(); _loadingVideos = false; });
    }
  }

  Future<void> _toggleActive(String videoId, bool current) async {
    try {
      await _service.updateField(videoId, 'is_active', !current);
      await _loadVideos();
    } catch (e) {
      _snack('Error: $e');
    }
  }

  Future<void> _deleteVideo(String videoId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: const Text('Delete video?',
            style: TextStyle(color: AppColors.onSurface)),
        content: Text(videoId,
            style: const TextStyle(color: AppColors.onSurfaceMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.wrongAnswer)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _service.deleteVideo(videoId);
        await _loadVideos();
      } catch (e) {
        _snack('Error: $e');
      }
    }
  }

  Future<void> _deleteSeedVideos() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: const Text('Delete all seed videos?',
            style: TextStyle(color: AppColors.onSurface)),
        content: const Text(
            'Deletes all videos with IDs starting with "video-". '
            'Real imported videos won\'t be affected.',
            style: TextStyle(color: AppColors.onSurfaceMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all',
                style: TextStyle(color: AppColors.wrongAnswer)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        final count = await _service.deleteSeedVideos();
        _snack('Deleted $count seed videos');
        await _loadVideos();
      } catch (e) {
        _snack('Error: $e');
      }
    }
  }

  Future<void> _seedDictionary() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: const Text('Seed HSK 1 Dictionary?',
            style: TextStyle(color: AppColors.onSurface)),
        content: const Text(
            '300 HSK Level 1 kelimesi dictionary tablosuna eklenir. '
            'Mevcut kayıtlar güncellenir.',
            style: TextStyle(color: AppColors.onSurfaceMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ekle',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _seeding = true);
    try {
      final count = await _service.seedHsk1Dictionary();
      _snack('✓ $count kelime eklendi');
    } catch (e) {
      _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Admin — ${_videos.length} videos'),
        actions: [
          if (_seeding)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary)),
            )
          else
            IconButton(
              icon: const Icon(Icons.book_outlined, color: AppColors.primary),
              tooltip: 'Seed HSK 1 Dictionary (300 words)',
              onPressed: _seedDictionary,
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined,
                color: AppColors.wrongAnswer),
            tooltip: 'Clear seed data',
            onPressed: _deleteSeedVideos,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadVideos),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceMuted,
          tabs: const [
            Tab(icon: Icon(Icons.smart_display_outlined, size: 18),
                text: 'YouTube'),
            Tab(icon: Icon(Icons.movie_outlined, size: 18),
                text: 'Movie / File'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: TabBarView(
              controller: _tabs,
              children: [
                _YouTubeTab(onVideosChanged: _loadVideos),
                _MovieImportTab(onVideosChanged: _loadVideos),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceVariant),
          Expanded(child: _buildVideoList()),
        ],
      ),
    );
  }

  Widget _buildVideoList() {
    if (_loadingVideos) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_videosError != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: AppColors.wrongAnswer, size: 40),
          const SizedBox(height: 12),
          Text(_videosError!,
              style: const TextStyle(color: AppColors.onSurfaceMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _loadVideos,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: const Text('Retry')),
        ]),
      );
    }
    if (_videos.isEmpty) {
      return const Center(
        child: Text('No videos yet.',
            style: TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: _videos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _VideoCard(
        data: _videos[i],
        service: _service,
        onToggleActive: _toggleActive,
        onDelete: _deleteVideo,
        onSaved: _loadVideos,
      ),
    );
  }
}

// ── Video card ────────────────────────────────────────────────────────────────

class _VideoCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final AdminService service;
  final Future<void> Function(String, bool) onToggleActive;
  final Future<void> Function(String) onDelete;
  final VoidCallback onSaved;

  const _VideoCard({
    required this.data,
    required this.service,
    required this.onToggleActive,
    required this.onDelete,
    required this.onSaved,
  });

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  bool _expanded = false;
  late int _hskLevel;
  late QuizCategory _category;
  late final TextEditingController _questionCtrl;
  late final TextEditingController _correctCtrl;
  late final TextEditingController _wrongCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.data;
    _hskLevel = (v['hsk_level'] as int?) ?? 1;
    _category = QuizCategory.fromString(
        v['quiz_category'] as String? ?? 'general');
    final quiz = v['quiz'] as Map<String, dynamic>? ?? {};
    _questionCtrl = TextEditingController(
        text: quiz['question'] as String? ?? '');
    _correctCtrl = TextEditingController(
        text: quiz['correctAnswer'] as String? ?? '');
    _wrongCtrl = TextEditingController(
        text: quiz['wrongAnswer'] as String? ?? '');
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _correctCtrl.dispose();
    _wrongCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.patchVideoFields(widget.data['id'] as String, {
        'hsk_level': _hskLevel,
        'quiz_category': _category.name,
        'quiz': {
          'question': _questionCtrl.text.trim(),
          'correctAnswer': _correctCtrl.text.trim(),
          'wrongAnswer': _wrongCtrl.text.trim(),
        },
      });
      if (mounted) {
        setState(() { _saving = false; _expanded = false; });
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openPreview() {
    final ytId = widget.data['youtube_id'] as String?;
    final start = (widget.data['start_time'] as num?)?.toInt() ?? 0;
    if (ytId == null || ytId.isEmpty) return;
    launchUrl(Uri.parse('https://youtu.be/$ytId?t=$start'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.data;
    final isActive = v['is_active'] as bool? ?? false;
    final hsk = (v['hsk_level'] as int?) ?? 1;
    final qc = QuizCategory.fromString(
        v['quiz_category'] as String? ?? 'general');
    final ytId = v['youtube_id'] as String?;
    final id = v['id'] as String;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.forHskLevel(hsk),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('HSK $hsk',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Text(qc.emoji, style: const TextStyle(fontSize: 14)),
              ],
            ),
            title: Text(
              v['transcription'] as String? ?? id,
              style: TextStyle(
                  color: isActive
                      ? AppColors.onSurface
                      : AppColors.onSurfaceMuted,
                  fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v['pinyin'] as String? ?? '',
                    style: const TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('YouTube: ${ytId ?? "—"}',
                    style: const TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 11)),
              ],
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Switch(
                value: isActive,
                activeTrackColor: AppColors.primary,
                onChanged: (_) => widget.onToggleActive(id, isActive),
              ),
              IconButton(
                icon: Icon(
                  _expanded ? Icons.edit : Icons.edit_outlined,
                  color: _expanded
                      ? AppColors.primary
                      : AppColors.onSurfaceMuted,
                  size: 20,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.wrongAnswer, size: 20),
                onPressed: () => widget.onDelete(id),
              ),
            ]),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.surface),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ytId != null && ytId.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _openPreview,
                      icon: const Icon(Icons.play_circle_outline, size: 16),
                      label: Text(
                          'YouTube\'da Oynat (t=${(v['start_time'] as num?)?.toInt() ?? 0}s)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text('HSK Seviye: $_hskLevel',
                      style: const TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Slider(
                    value: _hskLevel.toDouble(),
                    min: 1, max: 6, divisions: 5,
                    activeColor: AppColors.forHskLevel(_hskLevel),
                    label: 'HSK $_hskLevel',
                    onChanged: (v) => setState(() => _hskLevel = v.round()),
                  ),
                  const Text('Kategori',
                      style: TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 4,
                    children: QuizCategory.values.map((cat) {
                      final sel = _category == cat;
                      return ChoiceChip(
                        label: Text('${cat.emoji} ${cat.displayName}',
                            style: TextStyle(
                                fontSize: 11,
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.onSurfaceMuted)),
                        selected: sel,
                        selectedColor:
                            AppColors.primary.withValues(alpha: 0.15),
                        onSelected: (_) => setState(() => _category = cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Quiz',
                      style: TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  _editField(_questionCtrl, 'Soru'),
                  _editField(_correctCtrl, 'Doğru cevap'),
                  _editField(_wrongCtrl, 'Yanlış cevap (tuzak)'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12)),
                      child: _saving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Kaydet'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _editField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: AppColors.onSurface, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              color: AppColors.onSurfaceMuted, fontSize: 12),
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary)),
        ),
      ),
    );
  }
}

// ── Tab 1: YouTube — Pipeline + YouGlish segment builder ─────────────────────

class _YouTubeTab extends StatefulWidget {
  final VoidCallback onVideosChanged;
  const _YouTubeTab({required this.onVideosChanged});

  @override
  State<_YouTubeTab> createState() => _YouTubeTabState();
}

class _YouTubeTabState extends State<_YouTubeTab> {
  final _service = AdminService();
  final _urlCtrl = TextEditingController();

  // Cloud processing
  bool _processing = false;
  String? _resultMsg;
  bool _resultSuccess = false;

  // Segment builder
  String _ytId = '';
  YoutubePlayerController? _ytCtrl;
  final _startCtrl = TextEditingController(text: '0');
  final _endCtrl = TextEditingController(text: '10');
  final _transcriptionCtrl = TextEditingController();
  final _pinyinCtrl = TextEditingController();
  int _hskLevel = 1;
  QuizCategory _category = QuizCategory.general;
  bool _saving = false;
  bool _playerReady = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _transcriptionCtrl.dispose();
    _pinyinCtrl.dispose();
    _ytCtrl?.close();
    super.dispose();
  }

  static String _extractYtId(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri != null) {
      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : input;
      }
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;
    }
    return input.trim();
  }

  void _loadVideo() {
    final id = _extractYtId(_urlCtrl.text);
    if (id.isEmpty || id.length < 4) return;
    _ytCtrl?.close();
    final ctrl = YoutubePlayerController.fromVideoId(
      videoId: id,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: false,
        mute: false,
      ),
    );
    setState(() {
      _ytId = id;
      _ytCtrl = ctrl;
      _playerReady = true;
    });
  }

  Future<void> _playSegment() async {
    if (_ytCtrl == null) return;
    final start = double.tryParse(_startCtrl.text) ?? 0;
    final end = double.tryParse(_endCtrl.text) ?? 10;
    await _ytCtrl!.seekTo(seconds: start, allowSeekAhead: true);
    await _ytCtrl!.playVideo();
    // Stop at endTime
    Future.delayed(Duration(milliseconds: ((end - start) * 1000).round()), () {
      if (mounted) _ytCtrl?.pauseVideo();
    });
  }

  Future<void> _setStartToCurrent() async {
    if (_ytCtrl == null) return;
    final pos = await _ytCtrl!.currentTime;
    setState(() => _startCtrl.text = pos.toStringAsFixed(1));
  }

  Future<void> _setEndToCurrent() async {
    if (_ytCtrl == null) return;
    final pos = await _ytCtrl!.currentTime;
    setState(() => _endCtrl.text = pos.toStringAsFixed(1));
  }

  Future<void> _process() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() { _processing = true; _resultMsg = null; });
    try {
      final result = await _service.processYoutubeVideo(url, active: false);
      final count = result['segmentsWritten'] as int? ?? 0;
      if (mounted) {
        setState(() {
          _processing = false;
          _resultSuccess = true;
          _resultMsg = '✓ $count klip içe aktarıldı (pasif). Aşağıdan aktifleştirin.';
        });
        widget.onVideosChanged();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _resultSuccess = false;
          _resultMsg = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _saveSegment() async {
    final start = double.tryParse(_startCtrl.text) ?? 0;
    final end = double.tryParse(_endCtrl.text) ?? 10;
    if (_ytId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Önce videoyu yükleyin')));
      return;
    }
    setState(() => _saving = true);
    final id =
        'video-hsk$_hskLevel-${_ytId.substring(0, 4).toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _service.setVideo(id, {
        'id': id,
        'source_type': 'youtube',
        'youtube_id': _ytId,
        'start_time': start,
        'end_time': end,
        'hsk_level': _hskLevel,
        'transcription': _transcriptionCtrl.text.trim(),
        'pinyin': _pinyinCtrl.text.trim(),
        'target_words': <String>[],
        'quiz_category': _category.name,
        'quiz': <String, dynamic>{
          'question': '',
          'correctAnswer': '',
          'wrongAnswer': '',
        },
        'is_active': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) {
        _transcriptionCtrl.clear();
        _pinyinCtrl.clear();
        setState(() {
          _hskLevel = 1;
          _category = QuizCategory.general;
          _saving = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('✓ Segment kaydedildi!')));
        widget.onVideosChanged();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'),
                backgroundColor: AppColors.wrongAnswer));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cloud status ──────────────────────────────────────────────────
          Row(children: [
            const Icon(Icons.cloud_done_outlined,
                size: 14, color: AppColors.correctAnswer),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Bulut işleme aktif — altyazılı videolar otomatik parçalanır',
                style: TextStyle(color: AppColors.correctAnswer, fontSize: 12),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // ── URL field ────────────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: TextField(
                controller: _urlCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'https://www.youtube.com/watch?v=...',
                  hintStyle: const TextStyle(
                      color: AppColors.onSurfaceMuted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.link,
                      color: AppColors.onSurfaceMuted, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _loadVideo,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Yükle'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // ── Cloud process button ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  (_urlCtrl.text.trim().isNotEmpty && !_processing)
                      ? _process
                      : null,
              icon: _processing
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_processing
                  ? 'İşleniyor…'
                  : 'Otomatik Parçala — Tüm Klipleri İçe Aktar'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          if (_resultMsg != null) ...[
            const SizedBox(height: 10),
            _ResultBox(msg: _resultMsg!, success: _resultSuccess),
          ],

          const SizedBox(height: 16),

          // ── YouGlish-style segment builder ────────────────────────────────
          if (_playerReady && _ytCtrl != null) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Player
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: YoutubePlayer(
                        controller: _ytCtrl!,
                        aspectRatio: 16 / 9,
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Time controls
                        Row(children: [
                          Expanded(
                            child: _timeField(
                                _startCtrl, 'Başlangıç (sn)'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _timeField(_endCtrl, 'Bitiş (sn)'),
                          ),
                          const SizedBox(width: 8),
                          _timeBtn(
                              icon: Icons.flag_outlined,
                              label: 'Başlangıç',
                              onTap: _setStartToCurrent),
                          const SizedBox(width: 4),
                          _timeBtn(
                              icon: Icons.sports_score_outlined,
                              label: 'Bitiş',
                              onTap: _setEndToCurrent),
                        ]),
                        const SizedBox(height: 10),

                        // Play segment button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _playSegment,
                            icon: const Icon(Icons.play_circle_outline,
                                size: 18, color: AppColors.primary),
                            label: const Text('Segmenti Oynat',
                                style:
                                    TextStyle(color: AppColors.primary)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Transcription + Pinyin
                        _segField(_transcriptionCtrl,
                            'Çince metin (汉字)'),
                        const SizedBox(height: 8),
                        _segField(_pinyinCtrl, 'Pinyin'),
                        const SizedBox(height: 10),

                        // HSK level
                        Text('HSK Seviye: $_hskLevel',
                            style: const TextStyle(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Slider(
                          value: _hskLevel.toDouble(),
                          min: 1, max: 6, divisions: 5,
                          activeColor:
                              AppColors.forHskLevel(_hskLevel),
                          label: 'HSK $_hskLevel',
                          onChanged: (v) =>
                              setState(() => _hskLevel = v.round()),
                        ),

                        // Category
                        Wrap(
                          spacing: 6, runSpacing: 4,
                          children: QuizCategory.values.map((cat) {
                            final sel = _category == cat;
                            return ChoiceChip(
                              label: Text(
                                  '${cat.emoji} ${cat.displayName}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: sel
                                          ? AppColors.primary
                                          : AppColors.onSurfaceMuted)),
                              selected: sel,
                              selectedColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              onSelected: (_) =>
                                  setState(() => _category = cat),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _saveSegment,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Icon(Icons.save_outlined,
                                    size: 18),
                            label: const Text('Segmenti Kaydet'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Empty state hint
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.onSurfaceMuted.withValues(alpha: 0.2)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.smart_display_outlined,
                      size: 40, color: AppColors.onSurfaceMuted),
                  SizedBox(height: 12),
                  Text(
                    'YouTube linki girip "Yükle" butonuna basın.\n'
                    'Video yüklendikten sonra başlangıç/bitiş sürelerini\n'
                    'ayarlayıp segmentleri kaydedebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppColors.onSurface, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }

  Widget _timeBtn(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, size: 20, color: AppColors.primary),
          onPressed: onTap,
          tooltip: 'Mevcut süreyi "$label" olarak ayarla',
          style: IconButton.styleFrom(
            backgroundColor:
                AppColors.primary.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        Text(label,
            style: const TextStyle(
                color: AppColors.onSurfaceMuted, fontSize: 9)),
      ],
    );
  }

  Widget _segField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppColors.onSurface, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }
}

// ── Tab 2: Movie / Local File ─────────────────────────────────────────────────

class _MovieImportTab extends StatefulWidget {
  final VoidCallback onVideosChanged;
  const _MovieImportTab({required this.onVideosChanged});

  @override
  State<_MovieImportTab> createState() => _MovieImportTabState();
}

class _MovieImportTabState extends State<_MovieImportTab> {
  final _service = AdminService();

  html.File? _selectedFile;
  Uint8List? _fileBytes;
  String? _fileName;

  bool _serverRunning = false;
  bool _ffmpegAvailable = false;
  bool _checking = true;
  bool _processing = false;
  int _maxClips = 50;
  String? _resultMsg;
  bool _resultSuccess = false;

  @override
  void initState() {
    super.initState();
    _checkDeps();
  }

  Future<void> _checkDeps() async {
    setState(() => _checking = true);
    final server = await _service.isPipelineServerRunning();
    final ffmpeg = server ? await _service.isFfmpegAvailable() : false;
    if (mounted) {
      setState(() {
        _serverRunning = server;
        _ffmpegAvailable = ffmpeg;
        _checking = false;
      });
    }
  }

  void _pickFile() {
    final input = html.InputElement(type: 'file')
      ..accept = '.mp4,video/mp4'
      ..click();
    input.onChange.listen((_) {
      final file = input.files?.first;
      if (file == null) return;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoad.listen((_) {
        if (mounted) {
          setState(() {
            _selectedFile = file;
            _fileName = file.name;
            _fileBytes = Uint8List.fromList(
                (reader.result as List<dynamic>).cast<int>());
          });
        }
      });
    });
  }

  Future<void> _process() async {
    if (_fileBytes == null || _fileName == null) return;
    setState(() { _processing = true; _resultMsg = null; });
    try {
      final result = await _service.processMovieFileBytes(
        _fileBytes!,
        fileName: _fileName!,
        maxClips: _maxClips,
        active: false,
      );
      final count = result['clipsWritten'] as int? ?? 0;
      if (mounted) {
        setState(() {
          _processing = false;
          _resultSuccess = true;
          _resultMsg = '✓ $count klip çıkarıldı. Aşağıdan aktifleştirin.';
        });
        widget.onVideosChanged();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _resultSuccess = false;
          _resultMsg = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _serverRunning && _ffmpegAvailable && !_processing;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusRow(
              label: 'Pipeline sunucusu',
              ok: _serverRunning,
              checking: _checking),
          const SizedBox(height: 4),
          _StatusRow(
            label: _ffmpegAvailable
                ? 'ffmpeg bulundu'
                : 'ffmpeg bulunamadı — çalıştırın: winget install Gyan.FFmpeg',
            ok: _ffmpegAvailable,
            checking: _checking,
          ),
          if (!_checking && (!_serverRunning || !_ffmpegAvailable)) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _checkDeps,
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Tekrar Dene',
                  style: TextStyle(fontSize: 11)),
            ),
          ],
          const SizedBox(height: 16),

          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedFile != null
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.onSurfaceMuted.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFile != null
                        ? Icons.movie_filter_outlined
                        : Icons.upload_file_outlined,
                    size: 32,
                    color: _selectedFile != null
                        ? AppColors.primary
                        : AppColors.onSurfaceMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedFile != null
                        ? _fileName!
                        : 'MP4 dosyası seçmek için tıklayın',
                    style: TextStyle(
                      color: _selectedFile != null
                          ? AppColors.onSurface
                          : AppColors.onSurfaceMuted,
                      fontSize: 13,
                      fontWeight: _selectedFile != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(1)} MB',
                      style: const TextStyle(
                          color: AppColors.onSurfaceMuted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
              'Max klip: $_maxClips${_maxClips == 0 ? " (sınırsız)" : ""}',
              style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Slider(
            value: _maxClips.toDouble(),
            min: 0, max: 200, divisions: 40,
            activeColor: AppColors.primary,
            label: _maxClips == 0 ? '∞' : '$_maxClips',
            onChanged: (v) =>
                setState(() => _maxClips = v.round()),
          ),
          const Text(
            'Pipeline sunucusu + ffmpeg gerektirir.',
            style: TextStyle(
                color: AppColors.onSurfaceMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  (ready && _selectedFile != null) ? _process : null,
              icon: _processing
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.movie_filter_outlined, size: 18),
              label: Text(_processing
                  ? 'Klipleri ayırıyor… (birkaç dakika)'
                  : 'Klipleri Ayır ve İçe Aktar'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          if (_resultMsg != null) ...[
            const SizedBox(height: 12),
            _ResultBox(msg: _resultMsg!, success: _resultSuccess),
          ],
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final String label;
  final bool ok;
  final bool checking;
  const _StatusRow(
      {required this.label, required this.ok, required this.checking});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      checking
          ? const SizedBox(
              width: 10, height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5))
          : Icon(
              ok ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 14,
              color: ok ? AppColors.correctAnswer : AppColors.wrongAnswer),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          checking ? 'Kontrol ediliyor…' : label,
          style: TextStyle(
            color: checking
                ? AppColors.onSurfaceMuted
                : ok
                    ? AppColors.correctAnswer
                    : AppColors.wrongAnswer,
            fontSize: 12,
          ),
        ),
      ),
    ]);
  }
}

class _ResultBox extends StatelessWidget {
  final String msg;
  final bool success;
  const _ResultBox({required this.msg, required this.success});

  @override
  Widget build(BuildContext context) {
    final color =
        success ? AppColors.correctAnswer : AppColors.wrongAnswer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(msg, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}

// ── AddVideoScreen (kept for /admin/add-video deep link) ──────────────────────

class AddVideoScreen extends StatelessWidget {
  const AddVideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Video Ekle')),
      body: const _YouTubeTab(onVideosChanged: _noop),
    );
  }

  static void _noop() {}
}
