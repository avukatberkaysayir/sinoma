import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

// Admin panel — only accessible in debug mode via /admin route.
// Allows adding and toggling video segments for emulator testing.

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (!kDebugMode) return;
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _loading = true);
    final snap = await _firestore.collection('videos').get();
    setState(() {
      _videos = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _loading = false;
    });
  }

  Future<void> _toggleActive(String videoId, bool current) async {
    await _firestore.collection('videos').doc(videoId).update({'isActive': !current});
    await _loadVideos();
  }

  Future<void> _deleteVideo(String videoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: const Text('Delete video?', style: TextStyle(color: AppColors.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.wrongAnswer)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _firestore.collection('videos').doc(videoId).delete();
      await _loadVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(child: Text('Admin panel only available in debug mode.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Admin — Video Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVideos,
          ),
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
          : _videos.isEmpty
              ? const Center(
                  child: Text('No videos. Tap + to add one.',
                      style: TextStyle(color: AppColors.onSurfaceMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _videos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final v = _videos[i];
                    final isActive = v['isActive'] as bool? ?? true;
                    final hsk = v['hskLevel'] as int? ?? 1;
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.forHskLevel(hsk),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'HSK $hsk',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          v['transcription'] as String? ?? v['id'] as String,
                          style: TextStyle(
                            color: isActive ? AppColors.onSurface : AppColors.onSurfaceMuted,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          v['pinyin'] as String? ?? '',
                          style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isActive,
                              activeTrackColor: AppColors.primary,
                              onChanged: (_) => _toggleActive(v['id'] as String, isActive),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.wrongAnswer, size: 20),
                              onPressed: () => _deleteVideo(v['id'] as String),
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
  final _firestore = FirebaseFirestore.instance;

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
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _idCtrl, _youtubeIdCtrl, _transcriptionCtrl, _pinyinCtrl,
      _questionCtrl, _correctCtrl, _wrongCtrl, _targetWordsCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
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

    await _firestore.collection('videos').doc(id).set({
      'videoId': id,
      'sourceType': 'youtube',
      'youtubeId': _youtubeIdCtrl.text.trim(),
      'startTime': _startTime,
      'endTime': _endTime,
      'hskLevel': _hskLevel,
      'transcription': _transcriptionCtrl.text.trim(),
      'pinyin': _pinyinCtrl.text.trim(),
      'targetWords': targetWords,
      'quizCategory': 'vocabulary',
      'quiz': {
        'question': _questionCtrl.text.trim(),
        'correctAnswer': _correctCtrl.text.trim(),
        'wrongAnswer': _wrongCtrl.text.trim(),
      },
      'isActive': true,
      'createdAt': Timestamp.now(),
    });

    if (mounted) context.pop();
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
            _field(_idCtrl, 'Video ID (e.g. video-hsk1-04)', required: true),
            _field(_youtubeIdCtrl, 'YouTube ID (11-char code)', required: true),
            _field(_transcriptionCtrl, 'Chinese transcription', required: true),
            _field(_pinyinCtrl, 'Pinyin', required: true),
            _field(_targetWordsCtrl, 'Target word IDs (comma-separated)'),
            const SizedBox(height: 12),
            Text('HSK Level: $_hskLevel',
                style: const TextStyle(color: AppColors.onSurface)),
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
              style: const TextStyle(color: AppColors.onSurface),
            ),
            RangeSlider(
              values: RangeValues(_startTime, _endTime),
              min: 0,
              max: 600,
              divisions: 600,
              activeColor: AppColors.primary,
              onChanged: (r) =>
                  setState(() { _startTime = r.start; _endTime = r.end; }),
            ),
            const Divider(color: AppColors.surfaceVariant),
            const Text('Quiz', style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _field(_questionCtrl, 'Question', required: true),
            _field(_correctCtrl, 'Correct answer', required: true),
            _field(_wrongCtrl, 'Wrong answer', required: true),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Video'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        style: const TextStyle(color: AppColors.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.onSurfaceMuted),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }
}
