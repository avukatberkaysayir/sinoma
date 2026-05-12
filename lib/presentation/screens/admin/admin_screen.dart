import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this, initialIndex: 2);
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
            Tab(icon: Icon(Icons.edit_outlined, size: 18),
                text: 'Manual Add'),
          ],
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 340,
            child: TabBarView(
              controller: _tabs,
              children: [
                _YouTubeImportTab(onVideosChanged: _loadVideos),
                _MovieImportTab(onVideosChanged: _loadVideos),
                _ManualAddTab(
                  service: _service,
                  onSaved: () {
                    _loadVideos();
                    _tabs.animateTo(0);
                  },
                ),
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
          // ── Header row ───────────────────────────────────────────────────
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

          // ── Expanded edit panel ───────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.surface),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preview button
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

                  // HSK Level
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

                  // Category chips
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

                  // Quiz fields
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

                  // Save button
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

// ── Tab 1: YouTube Import ─────────────────────────────────────────────────────

class _YouTubeImportTab extends StatefulWidget {
  final VoidCallback onVideosChanged;
  const _YouTubeImportTab({required this.onVideosChanged});

  @override
  State<_YouTubeImportTab> createState() => _YouTubeImportTabState();
}

class _YouTubeImportTabState extends State<_YouTubeImportTab> {
  final _service = AdminService();
  final _urlCtrl = TextEditingController();

  bool _serverRunning = false;
  bool _checking = true;
  bool _processing = false;
  String? _resultMsg;
  bool _resultSuccess = false;

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkServer() async {
    setState(() => _checking = true);
    final ok = await _service.isPipelineServerRunning();
    if (mounted) setState(() { _serverRunning = ok; _checking = false; });
  }

  Future<void> _process() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _processing = true;
      _resultMsg = null;
    });
    try {
      final result = await _service.processYoutubeVideo(url, active: false);
      final count = result['segmentsWritten'] as int? ?? 0;
      if (mounted) {
        setState(() {
          _processing = false;
          _resultSuccess = true;
          _resultMsg =
              '✓ $count clips imported (inactive). Toggle them on below.';
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Server status
          Row(
            children: [
              _checking
                  ? const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5))
                  : Icon(
                      _serverRunning
                          ? Icons.circle
                          : Icons.circle_outlined,
                      size: 10,
                      color: _serverRunning
                          ? AppColors.correctAnswer
                          : AppColors.wrongAnswer),
              const SizedBox(width: 6),
              Text(
                _checking
                    ? 'Checking pipeline server…'
                    : _serverRunning
                        ? 'Pipeline server running (localhost:9302)'
                        : 'Pipeline server offline — start with start_dev.bat',
                style: TextStyle(
                  color: _checking
                      ? AppColors.onSurfaceMuted
                      : _serverRunning
                          ? AppColors.correctAnswer
                          : AppColors.wrongAnswer,
                  fontSize: 12,
                ),
              ),
              if (!_checking && !_serverRunning) ...[
                const Spacer(),
                TextButton(
                  onPressed: _checkServer,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Retry', style: TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _urlCtrl,
            enabled: !_processing,
            style: const TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'https://www.youtube.com/watch?v=...',
              hintStyle:
                  const TextStyle(color: AppColors.onSurfaceMuted),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.link,
                  color: AppColors.onSurfaceMuted, size: 18),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_serverRunning &&
                      _urlCtrl.text.trim().isNotEmpty &&
                      !_processing)
                  ? _process
                  : null,
              icon: _processing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_processing
                  ? 'Processing… (1–10 min, longer if no subtitles)'
                  : 'Process Video — Import All Clips'),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (_resultSuccess
                        ? AppColors.correctAnswer
                        : AppColors.wrongAnswer)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _resultSuccess
                      ? AppColors.correctAnswer
                      : AppColors.wrongAnswer,
                  width: 0.5,
                ),
              ),
              child: Text(
                _resultMsg!,
                style: TextStyle(
                  color: _resultSuccess
                      ? AppColors.correctAnswer
                      : AppColors.wrongAnswer,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          if (!_serverRunning && !_checking) ...[
            const SizedBox(height: 12),
            const Text('Or run manually:',
                style: TextStyle(
                    color: AppColors.onSurfaceMuted, fontSize: 11)),
            const SizedBox(height: 4),
            _CopyableCommand(
              command: _urlCtrl.text.trim().isNotEmpty
                  ? 'py python/pipeline/seed_video.py --url "${_urlCtrl.text.trim()}"'
                  : 'py python/pipeline/seed_video.py --url "<youtube_url>"',
            ),
          ],
        ],
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
  final _videoCtrl = TextEditingController();
  final _subCtrl = TextEditingController();

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

  @override
  void dispose() {
    _videoCtrl.dispose();
    _subCtrl.dispose();
    super.dispose();
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

  Future<void> _process() async {
    final videoPath = _videoCtrl.text.trim();
    if (videoPath.isEmpty) return;
    setState(() { _processing = true; _resultMsg = null; });
    try {
      final result = await _service.processMovieFile(
        videoPath,
        subPath: _subCtrl.text.trim(),
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
          // ── Status row ───────────────────────────────────────────────────
          _StatusRow(
            label: 'Pipeline server',
            ok: _serverRunning,
            checking: _checking,
          ),
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
          const SizedBox(height: 14),

          // ── Video path ───────────────────────────────────────────────────
          _pathField(_videoCtrl, 'Video file path (MP4 / MKV / AVI…)',
              hint: r'C:\Movies\my_movie.mkv', required: true),
          _pathField(_subCtrl, 'Subtitle file path (optional)',
              hint: r'C:\Movies\my_movie.srt'),

          // ── Max clips slider ─────────────────────────────────────────────
          const SizedBox(height: 8),
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
            'Use 0 for unlimited. For long films run in batches: '
            '0–50, then 50–100, etc.',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),

          // ── Process button ───────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: ready && _videoCtrl.text.trim().isNotEmpty
                  ? _process
                  : null,
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

          // ── Result ───────────────────────────────────────────────────────
          if (_resultMsg != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (_resultSuccess
                        ? AppColors.correctAnswer
                        : AppColors.wrongAnswer)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _resultSuccess
                      ? AppColors.correctAnswer
                      : AppColors.wrongAnswer,
                  width: 0.5,
                ),
              ),
              child: Text(_resultMsg!,
                  style: TextStyle(
                      color: _resultSuccess
                          ? AppColors.correctAnswer
                          : AppColors.wrongAnswer,
                      fontSize: 13)),
            ),
          ],

          // ── CLI fallback ─────────────────────────────────────────────────
          const SizedBox(height: 12),
          const Text('Or run from terminal for full control:',
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11)),
          const SizedBox(height: 4),
          _CopyableCommand(
            command: _videoCtrl.text.trim().isNotEmpty
                ? 'py python/pipeline/movie_pipeline.py'
                    ' --video "${_videoCtrl.text.trim()}"'
                    '${_subCtrl.text.trim().isNotEmpty ? ' --sub "${_subCtrl.text.trim()}"' : ''}'
                : 'py python/pipeline/movie_pipeline.py --video "path/to/movie.mkv" --sub "path/to/subs.srt"',
          ),
        ],
      ),
    );
  }

  Widget _pathField(
    TextEditingController ctrl,
    String label, {
    String hint = '',
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: AppColors.onSurface, fontSize: 13),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle:
              const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
          hintStyle:
              const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11),
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary)),
          prefixIcon: const Icon(Icons.folder_outlined,
              color: AppColors.onSurfaceMuted, size: 16),
        ),
      ),
    );
  }
}

// ── Shared status row widget ──────────────────────────────────────────────────

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
                color:
                    ok ? AppColors.correctAnswer : AppColors.wrongAnswer),
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

// ── Tab 3: Manual Add ─────────────────────────────────────────────────────────

class _ManualAddTab extends StatefulWidget {
  final AdminService service;
  final VoidCallback onSaved;
  const _ManualAddTab({required this.service, required this.onSaved});

  @override
  State<_ManualAddTab> createState() => _ManualAddTabState();
}

class _ManualAddTabState extends State<_ManualAddTab> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _youtubeIdCtrl = TextEditingController();
  final _transcriptionCtrl = TextEditingController();
  final _pinyinCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();
  final _correctCtrl = TextEditingController();
  final _wrongCtrl = TextEditingController();
  final _targetWordsCtrl = TextEditingController();

  int _hskLevel = 1;
  double _startTime = 0;
  double _endTime = 8;
  QuizCategory _category = QuizCategory.general;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _idCtrl, _youtubeIdCtrl, _transcriptionCtrl, _pinyinCtrl,
      _questionCtrl, _correctCtrl, _wrongCtrl, _targetWordsCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // Accepts a full YouTube URL or a bare 11-char video ID.
  static String _extractYtId(String input) {
    final uri = Uri.tryParse(input);
    if (uri != null) {
      if (uri.host.contains('youtu.be')) return uri.pathSegments.first;
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;
    }
    return input.trim();
  }

  void _onYoutubeUrlChanged(String raw) {
    final ytId = _extractYtId(raw);
    if (_idCtrl.text.isEmpty && ytId.length >= 4) {
      _idCtrl.text =
          'video-hsk$_hskLevel-${ytId.substring(0, 4).toLowerCase()}';
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final id = _idCtrl.text.trim();
    final targetWords = _targetWordsCtrl.text
        .split(',')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();

    try {
      await widget.service.setVideo(id, {
        'videoId': id,
        'sourceType': 'youtube',
        'youtubeId': _extractYtId(_youtubeIdCtrl.text.trim()),
        'startTime': _startTime,
        'endTime': _endTime,
        'hskLevel': _hskLevel,
        'transcription': _transcriptionCtrl.text.trim(),
        'pinyin': _pinyinCtrl.text.trim(),
        'targetWords': targetWords,
        'quizCategory': _category.name,
        'quiz': {
          'question': _questionCtrl.text.trim(),
          'correctAnswer': _correctCtrl.text.trim(),
          'wrongAnswer': _wrongCtrl.text.trim(),
        },
        'isActive': true,
        'createdAt': DateTime.now().toUtc(),
      });
      if (mounted) {
        for (final c in [
          _idCtrl, _youtubeIdCtrl, _transcriptionCtrl, _pinyinCtrl,
          _questionCtrl, _correctCtrl, _wrongCtrl, _targetWordsCtrl,
        ]) {
          c.clear();
        }
        setState(() {
          _hskLevel = 1;
          _startTime = 0;
          _endTime = 8;
          _category = QuizCategory.general;
          _saving = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Video saved!')));
        widget.onSaved();
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.wrongAnswer));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _field(_youtubeIdCtrl, 'YouTube URL or ID',
              required: true, onChanged: _onYoutubeUrlChanged),
          _field(_idCtrl, 'Document ID (auto-filled)', required: true),
          _field(_transcriptionCtrl, 'Chinese transcription (汉字)',
              required: true),
          _field(_pinyinCtrl, 'Pinyin', required: true),
          _field(_targetWordsCtrl, 'Target word IDs (comma-separated)'),
          const SizedBox(height: 10),
          Text('HSK Level: $_hskLevel',
              style: const TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600)),
          Slider(
            value: _hskLevel.toDouble(),
            min: 1,
            max: 6,
            divisions: 5,
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
            min: 0,
            max: 600,
            divisions: 600,
            activeColor: AppColors.primary,
            labels:
                RangeLabels('${_startTime.toInt()}s', '${_endTime.toInt()}s'),
            onChanged: (r) =>
                setState(() { _startTime = r.start; _endTime = r.end; }),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: QuizCategory.values.map((cat) {
              final sel = _category == cat;
              return ChoiceChip(
                label: Text('${cat.emoji} ${cat.displayName}'),
                selected: sel,
                selectedColor:
                    AppColors.primary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                    color: sel
                        ? AppColors.primary
                        : AppColors.onSurfaceMuted,
                    fontSize: 12),
                onSelected: (_) => setState(() => _category = cat),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.surfaceVariant),
          const Text('Quiz',
              style: TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 8),
          _field(_questionCtrl, 'Question', required: true),
          _field(_correctCtrl, 'Correct answer', required: true),
          _field(_wrongCtrl, 'Wrong answer (decoy)', required: true),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save Video'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        onChanged: onChanged,
        style:
            const TextStyle(color: AppColors.onSurface, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              color: AppColors.onSurfaceMuted, fontSize: 13),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.primary)),
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }
}

// ── Copyable command box ──────────────────────────────────────────────────────

class _CopyableCommand extends StatelessWidget {
  final String command;
  const _CopyableCommand({required this.command});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.black, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Expanded(
            child: Text(command,
                style: const TextStyle(
                    color: Color(0xFF7CFC00),
                    fontSize: 10,
                    fontFamily: 'monospace')),
          ),
          IconButton(
            icon:
                const Icon(Icons.copy, color: Colors.white38, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: command)),
          ),
        ],
      ),
    );
  }
}

// ── AddVideoScreen (kept for /admin/add-video deep link compatibility) ────────

class AddVideoScreen extends StatelessWidget {
  const AddVideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Add Video')),
      body: _ManualAddTab(
        service: AdminService(),
        onSaved: () => context.pop(),
      ),
    );
  }
}
