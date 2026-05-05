import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/video_segment_model.dart';
import '../../../data/services/admin_service.dart';

// Admin panel — debug mode only, accessible via /admin route.
// Uses EmulatorAdminService to bypass Firestore security rules
// (Authorization: Bearer owner — emulator only, never production).

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _service = AdminService();
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() { _loading = true; _error = null; });
    try {
      final videos = await _service.listVideos();
      videos.sort((a, b) {
        final ha = (a['hskLevel'] as int?) ?? 1;
        final hb = (b['hskLevel'] as int?) ?? 1;
        return ha.compareTo(hb);
      });
      setState(() { _videos = videos; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleActive(String videoId, bool current) async {
    try {
      await _service.updateField(videoId, 'isActive', !current);
      await _loadVideos();
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Future<void> _deleteVideo(String videoId) async {
    final confirmed = await showDialog<bool>(
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
    if (confirmed == true) {
      try {
        await _service.deleteVideo(videoId);
        await _loadVideos();
      } catch (e) {
        _showSnack('Error: $e');
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(
            child: Text('Admin panel only available in debug mode.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Admin — ${_videos.length} videos'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadVideos),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/admin/add-video');
          _loadVideos();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Video'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.wrongAnswer, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(
                              color: AppColors.onSurfaceMuted),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadVideos,
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _videos.isEmpty
                  ? const Center(
                      child: Text('No videos. Tap + to add one.',
                          style:
                              TextStyle(color: AppColors.onSurfaceMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _videos.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final v = _videos[i];
                        final isActive =
                            v['isActive'] as bool? ?? true;
                        final hsk = (v['hskLevel'] as int?) ?? 1;
                        final cat =
                            v['quizCategory'] as String? ?? 'vocabulary';
                        final qc = QuizCategory.fromString(cat);

                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primary
                                      .withValues(alpha: 0.3)
                                  : Colors.grey.withValues(alpha: 0.15),
                            ),
                          ),
                          child: ListTile(
                            leading: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.forHskLevel(hsk),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Text('HSK $hsk',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight:
                                              FontWeight.bold)),
                                ),
                                const SizedBox(height: 4),
                                Text(qc.emoji,
                                    style:
                                        const TextStyle(fontSize: 14)),
                              ],
                            ),
                            title: Text(
                              v['transcription'] as String? ??
                                  (v['id'] as String),
                              style: TextStyle(
                                color: isActive
                                    ? AppColors.onSurface
                                    : AppColors.onSurfaceMuted,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v['pinyin'] as String? ?? '',
                                  style: const TextStyle(
                                      color: AppColors.onSurfaceMuted,
                                      fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'YouTube: ${v['youtubeId'] ?? '—'}',
                                  style: const TextStyle(
                                      color: AppColors.onSurfaceMuted,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: isActive,
                                  activeTrackColor: AppColors.primary,
                                  onChanged: (_) => _toggleActive(
                                      v['id'] as String, isActive),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.wrongAnswer,
                                      size: 20),
                                  onPressed: () =>
                                      _deleteVideo(v['id'] as String),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

// ── Add Video Form ────────────────────────────────────────────────────────────

class AddVideoScreen extends StatefulWidget {
  const AddVideoScreen({super.key});

  @override
  State<AddVideoScreen> createState() => _AddVideoScreenState();
}

class _AddVideoScreenState extends State<AddVideoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = AdminService();

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
  QuizCategory _category = QuizCategory.vocabulary;
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

  // Auto-fill video ID from YouTube ID
  void _onYoutubeIdChanged(String ytId) {
    if (_idCtrl.text.isEmpty && ytId.length >= 4) {
      _idCtrl.text =
          'video-hsk$_hskLevel-${ytId.substring(0, 4).toLowerCase()}';
    }
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
      await _service.setVideo(id, {
        'videoId': id,
        'sourceType': 'youtube',
        'youtubeId': _youtubeIdCtrl.text.trim(),
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
        'createdAt': DateTime.now(),
      });
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: AppColors.wrongAnswer),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Add Video Segment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field(_youtubeIdCtrl, 'YouTube ID (11-char)',
                required: true,
                onChanged: _onYoutubeIdChanged),
            _field(_idCtrl, 'Video document ID (auto-filled)',
                required: true),
            _field(_transcriptionCtrl, 'Chinese transcription (汉字)',
                required: true),
            _field(_pinyinCtrl, 'Pinyin (tone marks)', required: true),
            _field(_targetWordsCtrl,
                'Target word IDs (comma-separated, e.g. ni-hao,shui)'),
            const SizedBox(height: 16),
            // HSK level slider
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
            // Time range slider
            Text(
              'Segment: ${_startTime.toStringAsFixed(1)}s → ${_endTime.toStringAsFixed(1)}s  '
              '(${(_endTime - _startTime).toStringAsFixed(1)}s)',
              style: const TextStyle(
                  color: AppColors.onSurface, fontWeight: FontWeight.w600),
            ),
            RangeSlider(
              values: RangeValues(_startTime, _endTime),
              min: 0, max: 600, divisions: 600,
              activeColor: AppColors.primary,
              labels: RangeLabels('${_startTime.toInt()}s',
                  '${_endTime.toInt()}s'),
              onChanged: (r) => setState(
                  () { _startTime = r.start; _endTime = r.end; }),
            ),
            // Category picker
            const SizedBox(height: 8),
            const Text('Quiz Category',
                style: TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: QuizCategory.values.map((cat) {
                final selected = _category == cat;
                return ChoiceChip(
                  label:
                      Text('${cat.emoji} ${cat.displayName}'),
                  selected: selected,
                  selectedColor:
                      AppColors.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: selected
                        ? AppColors.primary
                        : AppColors.onSurfaceMuted,
                    fontSize: 12,
                  ),
                  onSelected: (_) =>
                      setState(() => _category = cat),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Divider(color: AppColors.surfaceVariant),
            const Text('Quiz',
                style: TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 8),
            _field(_questionCtrl, 'Question (e.g. "水" means:)',
                required: true),
            _field(_correctCtrl, 'Correct answer', required: true),
            _field(_wrongCtrl, 'Wrong answer (decoy)',
                required: true),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Video',
                      style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              const TextStyle(color: AppColors.onSurfaceMuted),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary),
          ),
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }
}
