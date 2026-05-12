import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _loadingVideos = true;
      _videosError = null;
    });
    try {
      final videos = await _service.listVideos();
      videos.sort((a, b) =>
          ((a['hskLevel'] as int?) ?? 1)
              .compareTo((b['hskLevel'] as int?) ?? 1));
      if (mounted) setState(() { _videos = videos; _loadingVideos = false; });
    } catch (e) {
      if (mounted) setState(() { _videosError = e.toString(); _loadingVideos = false; });
    }
  }

  Future<void> _toggleActive(String videoId, bool current) async {
    try {
      await _service.updateField(videoId, 'isActive', !current);
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
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
            'This deletes all videos with IDs starting with "video-" '
            '(the demo seed data). Real imported videos won\'t be affected.',
            style: TextStyle(color: AppColors.onSurfaceMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
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
            'This will upsert all 300 HSK Level 1 words into the dictionary table. '
            'Existing entries with the same ID will be updated.',
            style: TextStyle(color: AppColors.onSurfaceMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Seed', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _seeding = true);
    try {
      final count = await _service.seedHsk1Dictionary();
      _snack('✓ $count words seeded into dictionary');
    } catch (e) {
      _snack('Error: $e');
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
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
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabs,
              children: [
                _YouTubeImportTab(onVideosChanged: _loadVideos),
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
          const Icon(Icons.error_outline,
              color: AppColors.wrongAnswer, size: 40),
          const SizedBox(height: 12),
          Text(_videosError!,
              style: const TextStyle(color: AppColors.onSurfaceMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _loadVideos,
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.primary),
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

// ── Expandable video card ─────────────────────────────────────────────────────

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
    _hskLevel = (v['hskLevel'] as int?) ?? 1;
    _category =
        QuizCategory.fromString(v['quizCategory'] as String? ?? 'general');
    final quiz = v['quiz'] as Map<String, dynamic>? ?? {};
    _questionCtrl =
        TextEditingController(text: quiz['question'] as String? ?? '');
    _correctCtrl =
        TextEditingController(text: quiz['correctAnswer'] as String? ?? '');
    _wrongCtrl =
        TextEditingController(text: quiz['wrongAnswer'] as String? ?? '');
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
        'hskLevel': _hskLevel,
        'quizCategory': _category.name,
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
    final ytId = widget.data['youtubeId'] as String?;
    final start = (widget.data['startTime'] as num?)?.toInt() ?? 0;
    if (ytId == null || ytId.isEmpty) return;
    final uri = Uri.parse('https://youtu.be/$ytId?t=$start');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.data;
    final isActive = v['isActive'] as bool? ?? false;
    final hsk = (v['hskLevel'] as int?) ?? 1;
    final qc = QuizCategory.fromString(
        v['quizCategory'] as String? ?? 'general');
    final ytId = v['youtubeId'] as String?;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                tooltip: 'Edit tags & quiz',
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
                          'Preview on YouTube (t=${(v['startTime'] as num?)?.toInt() ?? 0}s)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text('HSK Level: $_hskLevel',
                      style: const TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Slider(
                    value: _hskLevel.toDouble(),
                    min: 1,
                    max: 6,
                    divisions: 5,
                    activeColor: AppColors.forHskLevel(_hskLevel),
                    label: 'HSK $_hskLevel',
                    onChanged: (v) =>
                        setState(() => _hskLevel = v.round()),
                  ),
                  const Text('Category',
                      style: TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
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
                        onSelected: (_) =>
                            setState(() => _category = cat),
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
                  _editField(_questionCtrl, 'Question'),
                  _editField(_correctCtrl, 'Correct answer'),
                  _editField(_wrongCtrl, 'Wrong answer (decoy)'),
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
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes'),
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
        style:
            const TextStyle(color: AppColors.onSurface, fontSize: 13),
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
              borderSide:
                  const BorderSide(color: AppColors.primary)),
        ),
      ),
    );
  }
}

// ── Tab 1: YouTube Import (pipeline + direct add fallback) ────────────────────

class _YouTubeImportTab extends StatefulWidget {
  final VoidCallback onVideosChanged;
  const _YouTubeImportTab({required this.onVideosChanged});

  @override
  State<_YouTubeImportTab> createState() => _YouTubeImportTabState();
}

class _YouTubeImportTabState extends State<_YouTubeImportTab> {
  final _service = AdminService();
  final _urlCtrl = TextEditingController();

  // Pipeline state
  bool _serverRunning = false;
  bool _checking = true;
  bool _processing = false;
  String? _resultMsg;
  bool _resultSuccess = false;

  // Direct-add state
  final _transcriptionCtrl = TextEditingController();
  final _pinyinCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();
  final _correctCtrl = TextEditingController();
  final _wrongCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  int _hskLevel = 1;
  double _startTime = 0;
  double _endTime = 8;
  QuizCategory _category = QuizCategory.general;
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _transcriptionCtrl.dispose();
    _pinyinCtrl.dispose();
    _questionCtrl.dispose();
    _correctCtrl.dispose();
    _wrongCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkServer() async {
    setState(() => _checking = true);
    final ok = await _service.isPipelineServerRunning();
    if (mounted) setState(() { _serverRunning = ok; _checking = false; });
  }

  static String _extractYtId(String input) {
    final uri = Uri.tryParse(input);
    if (uri != null) {
      if (uri.host.contains('youtu.be')) return uri.pathSegments.first;
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;
    }
    return input.trim();
  }

  void _onUrlChanged(String raw) {
    final ytId = _extractYtId(raw);
    if (_idCtrl.text.isEmpty && ytId.length >= 4) {
      _idCtrl.text = 'video-hsk$_hskLevel-${ytId.substring(0, 4).toLowerCase()}';
    }
    setState(() {});
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
          _resultMsg = '✓ $count clips imported (inactive). Toggle them on below.';
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

  Future<void> _saveDirectly() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ytId = _extractYtId(_urlCtrl.text.trim());
    final id = _idCtrl.text.trim().isNotEmpty
        ? _idCtrl.text.trim()
        : 'video-hsk$_hskLevel-${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _service.setVideo(id, {
        'videoId': id,
        'sourceType': 'youtube',
        'youtubeId': ytId,
        'startTime': _startTime,
        'endTime': _endTime,
        'hskLevel': _hskLevel,
        'transcription': _transcriptionCtrl.text.trim(),
        'pinyin': _pinyinCtrl.text.trim(),
        'targetWords': <String>[],
        'quizCategory': _category.name,
        'quiz': {
          'question': _questionCtrl.text.trim(),
          'correctAnswer': _correctCtrl.text.trim(),
          'wrongAnswer': _wrongCtrl.text.trim(),
        },
        'isActive': true,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) {
        for (final c in [
          _idCtrl, _transcriptionCtrl, _pinyinCtrl,
          _questionCtrl, _correctCtrl, _wrongCtrl,
        ]) { c.clear(); }
        setState(() {
          _hskLevel = 1; _startTime = 0; _endTime = 8;
          _category = QuizCategory.general; _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Video saved!')));
        widget.onVideosChanged();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'),
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
          // ── Pipeline status ───────────────────────────────────────────────
          Row(
            children: [
              _checking
                  ? const SizedBox(
                      width: 10, height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5))
                  : Icon(
                      _serverRunning ? Icons.circle : Icons.circle_outlined,
                      size: 10,
                      color: _serverRunning
                          ? AppColors.correctAnswer
                          : AppColors.wrongAnswer),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _checking
                      ? 'Checking pipeline server…'
                      : _serverRunning
                          ? 'Pipeline server running (localhost:9302)'
                          : 'Pipeline server offline — use Direct Add below',
                  style: TextStyle(
                    color: _checking
                        ? AppColors.onSurfaceMuted
                        : _serverRunning
                            ? AppColors.correctAnswer
                            : AppColors.onSurfaceMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              if (!_checking)
                TextButton(
                  onPressed: _checkServer,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Retry', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── URL field (shared by pipeline + direct add) ───────────────────
          TextFormField(
            controller: _urlCtrl,
            style: const TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'https://www.youtube.com/watch?v=... or video ID',
              hintStyle: const TextStyle(color: AppColors.onSurfaceMuted),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.link,
                  color: AppColors.onSurfaceMuted, size: 18),
            ),
            onChanged: _onUrlChanged,
          ),
          const SizedBox(height: 10),

          // ── Pipeline process button (only when server online) ─────────────
          if (_serverRunning)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_urlCtrl.text.trim().isNotEmpty && !_processing)
                    ? _process
                    : null,
                icon: _processing
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(_processing
                    ? 'Processing… (1–10 min)'
                    : 'Process via Pipeline — Import All Clips'),
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

          const SizedBox(height: 18),

          // ── Direct Add section (always visible) ───────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            padding: const EdgeInsets.all(14),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Doğrudan Ekle',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Spacer(),
                      Text('Supabase\'e doğrudan kaydeder',
                          style: TextStyle(
                              color: AppColors.onSurfaceMuted, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _field(_idCtrl, 'Document ID (auto-filled)'),
                  _field(_transcriptionCtrl, 'Chinese transcription (汉字)', required: true),
                  _field(_pinyinCtrl, 'Pinyin', required: true),
                  const SizedBox(height: 6),
                  Text('HSK Level: $_hskLevel',
                      style: const TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600)),
                  Slider(
                    value: _hskLevel.toDouble(),
                    min: 1, max: 6, divisions: 5,
                    activeColor: AppColors.forHskLevel(_hskLevel),
                    label: 'HSK $_hskLevel',
                    onChanged: (v) => setState(() => _hskLevel = v.round()),
                  ),
                  Text(
                      'Segment: ${_startTime.toStringAsFixed(1)}s → ${_endTime.toStringAsFixed(1)}s',
                      style: const TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600)),
                  RangeSlider(
                    values: RangeValues(_startTime, _endTime),
                    min: 0, max: 600, divisions: 600,
                    activeColor: AppColors.primary,
                    labels: RangeLabels('${_startTime.toInt()}s', '${_endTime.toInt()}s'),
                    onChanged: (r) =>
                        setState(() { _startTime = r.start; _endTime = r.end; }),
                  ),
                  Wrap(
                    spacing: 6, runSpacing: 4,
                    children: QuizCategory.values.map((cat) {
                      final sel = _category == cat;
                      return ChoiceChip(
                        label: Text('${cat.emoji} ${cat.displayName}'),
                        selected: sel,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                            color: sel ? AppColors.primary : AppColors.onSurfaceMuted,
                            fontSize: 11),
                        onSelected: (_) => setState(() => _category = cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  const Text('Quiz',
                      style: TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  _field(_questionCtrl, 'Question', required: true),
                  _field(_correctCtrl, 'Correct answer', required: true),
                  _field(_wrongCtrl, 'Wrong answer (decoy)', required: true),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveDirectly,
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: _saving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Video'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: ctrl,
        style: const TextStyle(color: AppColors.onSurface, fontSize: 13),
        onChanged: (_) => setState(() {}),
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
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }
}

// ── Tab 2: Movie / Local File Import ─────────────────────────────────────────

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
          _resultMsg = '✓ $count clips extracted. Toggle them on below.';
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
          _StatusRow(label: 'Pipeline server', ok: _serverRunning, checking: _checking),
          const SizedBox(height: 4),
          _StatusRow(
            label: _ffmpegAvailable
                ? 'ffmpeg found'
                : 'ffmpeg not found — run: winget install Gyan.FFmpeg',
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
              child: const Text('Retry check', style: TextStyle(fontSize: 11)),
            ),
          ],
          const SizedBox(height: 16),

          // ── File picker ───────────────────────────────────────────────────
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedFile != null
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.onSurfaceMuted.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
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
                        : 'Click to select an MP4 file',
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

          // ── Max clips slider ──────────────────────────────────────────────
          Text('Max clips per run: $_maxClips${_maxClips == 0 ? " (unlimited)" : ""}',
              style: const TextStyle(
                  color: AppColors.onSurface, fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Slider(
            value: _maxClips.toDouble(),
            min: 0, max: 200, divisions: 40,
            activeColor: AppColors.primary,
            label: _maxClips == 0 ? '∞' : '$_maxClips',
            onChanged: (v) => setState(() => _maxClips = v.round()),
          ),
          const Text(
            'Requires pipeline server + ffmpeg running locally.',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (ready && _selectedFile != null) ? _process : null,
              icon: _processing
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.movie_filter_outlined, size: 18),
              label: Text(_processing
                  ? 'Extracting clips… (may take several minutes)'
                  : 'Extract & Import Clips'),
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
    return Row(
      children: [
        checking
            ? const SizedBox(
                width: 10, height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5))
            : Icon(ok ? Icons.check_circle_outline : Icons.cancel_outlined,
                size: 14,
                color: ok ? AppColors.correctAnswer : AppColors.wrongAnswer),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            checking ? 'Checking…' : label,
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
      ],
    );
  }
}

class _ResultBox extends StatelessWidget {
  final String msg;
  final bool success;
  const _ResultBox({required this.msg, required this.success});

  @override
  Widget build(BuildContext context) {
    final color = success ? AppColors.correctAnswer : AppColors.wrongAnswer;
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
      appBar: AppBar(title: const Text('Add Video')),
      body: const _YouTubeImportTab(onVideosChanged: _noop),
    );
  }

  static void _noop() {}
}
