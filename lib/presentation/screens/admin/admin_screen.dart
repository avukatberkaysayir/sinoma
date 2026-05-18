import 'dart:async';
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
  final _reviewKey = GlobalKey<_VideoReviewPanelState>();
  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _service.seedHsk1Dictionary();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _seedDictionary(int level) async {
    final counts = {1: 300, 2: 198, 3: 494};
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: Text('Seed HSK $level Dictionary?',
            style: const TextStyle(color: AppColors.onSurface)),
        content: Text(
            '~${counts[level]} HSK Level $level kelimesi dictionary tablosuna eklenir. Mevcut kayıtlar güncellenir.',
            style: const TextStyle(color: AppColors.onSurfaceMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
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
      final count = level == 1
          ? await _service.seedHsk1Dictionary()
          : level == 2
              ? await _service.seedHsk2Dictionary()
              : await _service.seedHsk3Dictionary();
      _snack('✓ $count kelime eklendi (HSK $level)');
    } catch (e) {
      _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _seeding = false);
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
        _reviewKey.currentState?.refresh();
      } catch (e) {
        _snack('Error: $e');
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          if (_seeding)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary)),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.looks_one_outlined, color: AppColors.primary),
              tooltip: 'Seed HSK 1 Dictionary (300 words)',
              onPressed: () => _seedDictionary(1),
            ),
            IconButton(
              icon: const Icon(Icons.looks_two_outlined, color: AppColors.primary),
              tooltip: 'Seed HSK 2 Dictionary (198 words)',
              onPressed: () => _seedDictionary(2),
            ),
            IconButton(
              icon: const Icon(Icons.looks_3_outlined, color: AppColors.primary),
              tooltip: 'Seed HSK 3 Dictionary (~494 words)',
              onPressed: () => _seedDictionary(3),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined,
                color: AppColors.wrongAnswer),
            tooltip: 'Clear seed data',
            onPressed: _deleteSeedVideos,
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left: Add panel (420px) ──────────────────────────────────────
          SizedBox(
            width: 420,
            child: Column(
              children: [
                Material(
                  color: AppColors.surfaceVariant,
                  child: TabBar(
                    controller: _tabs,
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.onSurfaceMuted,
                    tabs: const [
                      Tab(
                          icon: Icon(Icons.smart_display_outlined, size: 18),
                          text: 'YouTube'),
                      Tab(
                          icon: Icon(Icons.movie_outlined, size: 18),
                          text: 'Movie / File'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _YouTubeTab(
                        onVideosChanged: () =>
                            _reviewKey.currentState?.refresh(),
                      ),
                      _MovieImportTab(
                        onVideosChanged: () =>
                            _reviewKey.currentState?.refresh(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Divider ──────────────────────────────────────────────────────
          Container(width: 1, color: AppColors.surfaceVariant),
          // ── Right: Review panel ──────────────────────────────────────────
          Expanded(
            child: _VideoReviewPanel(key: _reviewKey, service: _service),
          ),
        ],
      ),
    );
  }
}

// ── Video Review Panel ────────────────────────────────────────────────────────

class _VideoReviewPanel extends StatefulWidget {
  final AdminService service;
  const _VideoReviewPanel({super.key, required this.service});

  @override
  State<_VideoReviewPanel> createState() => _VideoReviewPanelState();
}

class _VideoReviewPanelState extends State<_VideoReviewPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _refreshCount = 0;
  int? _filterHsk;
  String? _filterCategory;
  String? _filterLength;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void refresh() {
    if (mounted) setState(() => _refreshCount++);
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ara (Çince, pinyin, kelime…)',
                hintStyle: const TextStyle(
                    color: AppColors.onSurfaceMuted, fontSize: 12),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                prefixIcon: const Icon(Icons.search,
                    size: 16, color: AppColors.onSurfaceMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
              ),
              onChanged: (q) {
                _searchDebounce?.cancel();
                _searchDebounce =
                    Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _searchQuery = q.trim());
                });
              },
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('HSK:',
                    style: TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 11)),
                const SizedBox(width: 4),
                _FilterDropdown<int>(
                  value: _filterHsk,
                  hint: 'Tümü',
                  options: [for (var i = 1; i <= 6; i++) ('HSK $i', i)],
                  onChanged: (v) => setState(() => _filterHsk = v),
                ),
                const SizedBox(width: 10),
                const Text('Kat:',
                    style: TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 11)),
                const SizedBox(width: 4),
                _FilterDropdown<String>(
                  value: _filterCategory,
                  hint: 'Tümü',
                  options: QuizCategory.values
                      .map((c) => ('${c.emoji} ${c.displayName}', c.name))
                      .toList(),
                  onChanged: (v) => setState(() => _filterCategory = v),
                ),
                const SizedBox(width: 10),
                const Text('Uzunluk:',
                    style: TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 11)),
                const SizedBox(width: 4),
                _FilterDropdown<String>(
                  value: _filterLength,
                  hint: 'Tümü',
                  options: const [
                    ('1-5字', '1-5字'),
                    ('6-10字', '6-10字'),
                    ('11-15字', '11-15字'),
                    ('16-20字', '16-20字'),
                    ('21字+', '21字+'),
                  ],
                  onChanged: (v) => setState(() => _filterLength = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        Material(
          color: AppColors.surfaceVariant,
          child: TabBar(
            controller: _tabs,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceMuted,
            tabs: const [
              Tab(
                  icon: Icon(Icons.hourglass_empty_outlined, size: 16),
                  text: 'Onay Bekleyen'),
              Tab(
                  icon: Icon(Icons.check_circle_outline, size: 16),
                  text: 'Aktif'),
              Tab(
                  icon: Icon(Icons.delete_outline, size: 16),
                  text: 'Silinmiş'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _VideoStatusTab(
                key: ValueKey('pending-$_refreshCount'),
                status: 'pending',
                service: widget.service,
                onRefresh: refresh,
                filterHsk: _filterHsk,
                filterCategory: _filterCategory,
                filterLength: _filterLength,
                searchQuery: _searchQuery,
              ),
              _VideoStatusTab(
                key: ValueKey('active-$_refreshCount'),
                status: 'active',
                service: widget.service,
                onRefresh: refresh,
                filterHsk: _filterHsk,
                filterCategory: _filterCategory,
                filterLength: _filterLength,
                searchQuery: _searchQuery,
              ),
              _VideoStatusTab(
                key: ValueKey('deleted-$_refreshCount'),
                status: 'deleted',
                service: widget.service,
                onRefresh: refresh,
                filterHsk: _filterHsk,
                filterCategory: _filterCategory,
                filterLength: _filterLength,
                searchQuery: _searchQuery,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Video Status Tab ──────────────────────────────────────────────────────────

class _VideoStatusTab extends StatefulWidget {
  final String status;
  final AdminService service;
  final VoidCallback onRefresh;
  final int? filterHsk;
  final String? filterCategory;
  final String? filterLength;
  final String searchQuery;

  const _VideoStatusTab({
    super.key,
    required this.status,
    required this.service,
    required this.onRefresh,
    this.filterHsk,
    this.filterCategory,
    this.filterLength,
    this.searchQuery = '',
  });

  @override
  State<_VideoStatusTab> createState() => _VideoStatusTabState();
}

class _VideoStatusTabState extends State<_VideoStatusTab> {
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;
  String? _error;
  final Set<String> _selected = {};
  bool _bulkLoading = false;

  static String _sentenceLengthBucket(int n) {
    if (n <= 5) return '1-5字';
    if (n <= 10) return '6-10字';
    if (n <= 15) return '11-15字';
    if (n <= 20) return '16-20字';
    return '21字+';
  }

  List<Map<String, dynamic>> get _filteredVideos {
    var result = _videos;
    if (widget.filterHsk != null) {
      result = result
          .where((v) => (v['hsk_level'] as int?) == widget.filterHsk)
          .toList();
    }
    if (widget.filterCategory != null) {
      result = result
          .where((v) => (v['quiz_category'] as String?) == widget.filterCategory)
          .toList();
    }
    if (widget.filterLength != null) {
      result = result.where((v) {
        final t = v['transcription'] as String? ?? '';
        final n = RegExp(r'[一-鿿]').allMatches(t).length;
        return _sentenceLengthBucket(n) == widget.filterLength;
      }).toList();
    }
    if (widget.searchQuery.isNotEmpty) {
      final q = widget.searchQuery.toLowerCase();
      result = result.where((v) {
        final t = (v['transcription'] as String? ?? '').toLowerCase();
        final p = (v['pinyin'] as String? ?? '').toLowerCase();
        final words = (v['target_words'] as List<dynamic>?)
                ?.map((w) => w.toString().toLowerCase())
                .toList() ??
            [];
        return t.contains(q) || p.contains(q) || words.any((w) => w.contains(q));
      }).toList();
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected.clear();
    });
    try {
      final list = await widget.service.listVideosByStatus(widget.status);
      if (mounted) setState(() { _videos = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    final filtered = _filteredVideos;
    setState(() {
      final allSel = filtered.isNotEmpty &&
          filtered.every((v) => _selected.contains(v['id'] as String));
      if (allSel) {
        _selected.removeAll(filtered.map((v) => v['id'] as String));
      } else {
        _selected.addAll(filtered.map((v) => v['id'] as String));
      }
    });
  }

  Future<void> _bulkApprove() async {
    if (_selected.isEmpty) return;
    setState(() => _bulkLoading = true);
    try {
      await widget.service.approveVideos(_selected.toList());
      if (mounted) _snack('✓ ${_selected.length} video onaylandı');
      widget.onRefresh();
    } catch (e) {
      if (mounted) _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _bulkLoading = false);
    }
  }

  Future<void> _bulkSoftDelete() async {
    if (_selected.isEmpty) return;
    setState(() => _bulkLoading = true);
    try {
      await widget.service.softDeleteVideos(_selected.toList());
      if (mounted) _snack('${_selected.length} video silindi');
      widget.onRefresh();
    } catch (e) {
      if (mounted) _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _bulkLoading = false);
    }
  }

  Future<void> _bulkDeactivate() async {
    if (_selected.isEmpty) return;
    setState(() => _bulkLoading = true);
    try {
      await widget.service.restoreVideos(_selected.toList()); // → pending
      if (mounted) _snack('${_selected.length} video pasife alındı');
      widget.onRefresh();
    } catch (e) {
      if (mounted) _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _bulkLoading = false);
    }
  }

  Future<void> _bulkRestore() async {
    if (_selected.isEmpty) return;
    setState(() => _bulkLoading = true);
    try {
      await widget.service.restoreVideos(_selected.toList());
      if (mounted) _snack('${_selected.length} video geri yüklendi');
      widget.onRefresh();
    } catch (e) {
      if (mounted) _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _bulkLoading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _allSelected {
    final filtered = _filteredVideos;
    return filtered.isNotEmpty &&
        filtered.every((v) => _selected.contains(v['id'] as String));
  }

  bool get _someSelected {
    final filtered = _filteredVideos;
    return filtered.any((v) => _selected.contains(v['id'] as String));
  }

  Widget _buildBulkActions() {
    final selCount = _selected.length;
    final disabled = selCount == 0 || _bulkLoading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: AppColors.surfaceVariant,
      child: Row(
        children: [
          Checkbox(
            value: _allSelected ? true : (_someSelected ? null : false),
            tristate: true,
            activeColor: AppColors.primary,
            onChanged: (_) => _toggleSelectAll(),
          ),
          Text(
            selCount > 0 ? '$selCount seçili' : 'Tümünü seç',
            style: TextStyle(
              color: selCount > 0
                  ? AppColors.onSurface
                  : AppColors.onSurfaceMuted,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          if (_bulkLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
          else ...[
            if (widget.status == 'pending') ...[
              _actionBtn('Onayla', AppColors.primary, filled: true,
                  onPressed: disabled ? null : _bulkApprove),
              const SizedBox(width: 6),
              _actionBtn('Sil', AppColors.wrongAnswer,
                  onPressed: disabled ? null : _bulkSoftDelete),
            ],
            if (widget.status == 'active') ...[
              _actionBtn('Pasife Al', AppColors.onSurfaceMuted,
                  onPressed: disabled ? null : _bulkDeactivate),
              const SizedBox(width: 6),
              _actionBtn('Sil', AppColors.wrongAnswer,
                  onPressed: disabled ? null : _bulkSoftDelete),
            ],
            if (widget.status == 'deleted') ...[
              _actionBtn('Geri Yükle', AppColors.primary, filled: true,
                  onPressed: disabled ? null : _bulkRestore),
            ],
          ],
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _load,
            tooltip: 'Yenile',
            style: IconButton.styleFrom(
                minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color,
      {bool filled = false, VoidCallback? onPressed}) {
    final style = filled
        ? FilledButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: const TextStyle(fontSize: 12),
            minimumSize: Size.zero,
          )
        : OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: const TextStyle(fontSize: 12),
            minimumSize: Size.zero,
          );

    return filled
        ? FilledButton(onPressed: onPressed, style: style, child: Text(label))
        : OutlinedButton(
            onPressed: onPressed, style: style, child: Text(label));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline,
              color: AppColors.wrongAnswer, size: 40),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: AppColors.onSurfaceMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _load,
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Tekrar Dene')),
        ]),
      );
    }

    final filtered = _filteredVideos;
    return Column(
      children: [
        _buildBulkActions(),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _videos.isEmpty
                        ? switch (widget.status) {
                            'pending' => 'Onay bekleyen video yok.',
                            'active' => 'Aktif video yok.',
                            'deleted' => 'Silinmiş video yok.',
                            _ => 'Video yok.',
                          }
                        : 'Filtreyle eşleşen video yok.',
                    style:
                        const TextStyle(color: AppColors.onSurfaceMuted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final video = filtered[i];
                    final id = video['id'] as String;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Checkbox(
                            value: _selected.contains(id),
                            activeColor: AppColors.primary,
                            onChanged: (_) => _toggleSelect(id),
                          ),
                        ),
                        Expanded(
                          child: _VideoCard(
                            data: video,
                            service: widget.service,
                            onSaved: _load,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Video Card ────────────────────────────────────────────────────────────────

class _VideoCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final AdminService service;
  final VoidCallback onSaved;

  const _VideoCard({
    required this.data,
    required this.service,
    required this.onSaved,
  });

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  bool _expanded = false;
  late int _hskLevel;
  late QuizCategory _category;
  late List<String> _targetWords;
  late final TextEditingController _questionCtrl;
  late final TextEditingController _correctCtrl;
  late final TextEditingController _wrongCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.data;
    _hskLevel = (v['hsk_level'] as int?) ?? 1;
    _category =
        QuizCategory.fromString(v['quiz_category'] as String? ?? 'general');
    _targetWords = List<String>.from(
        (v['target_words'] as List<dynamic>?) ?? []);
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
        'hsk_level': _hskLevel,
        'quiz_category': _category.name,
        'target_words': _targetWords,
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
    final hsk = (v['hsk_level'] as int?) ?? 1;
    final qc =
        QuizCategory.fromString(v['quiz_category'] as String? ?? 'general');
    final ytId = v['youtube_id'] as String?;
    final id = v['id'] as String;
    final status = v['status'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'active'
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
              style:
                  const TextStyle(color: AppColors.onSurface, fontSize: 13),
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
            trailing: IconButton(
              icon: Icon(
                _expanded ? Icons.edit : Icons.edit_outlined,
                color:
                    _expanded ? AppColors.primary : AppColors.onSurfaceMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
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
                    min: 1,
                    max: 6,
                    divisions: 5,
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
                        onSelected: (_) => setState(() => _category = cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  _WordTagEditor(
                    words: _targetWords,
                    service: widget.service,
                    onChanged: (words) =>
                        setState(() => _targetWords = words),
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
                              width: 16,
                              height: 16,
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
      ),
    );
  }
}

// ── Word Tag Editor ───────────────────────────────────────────────────────────

class _WordTagEditor extends StatefulWidget {
  final List<String> words;
  final AdminService service;
  final void Function(List<String>) onChanged;

  const _WordTagEditor({
    required this.words,
    required this.service,
    required this.onChanged,
  });

  @override
  State<_WordTagEditor> createState() => _WordTagEditorState();
}

class _WordTagEditorState extends State<_WordTagEditor> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = [];
  bool _searching = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      final results = await widget.service.searchDictionary(q.trim());
      if (mounted) setState(() { _suggestions = results; _searching = false; });
    });
  }

  void _addWord(String word) {
    final current = List<String>.from(widget.words);
    if (!current.contains(word)) {
      current.add(word);
      widget.onChanged(current);
    }
    _ctrl.clear();
    setState(() => _suggestions = []);
  }

  void _removeWord(String word) {
    final current = List<String>.from(widget.words);
    current.remove(word);
    widget.onChanged(current);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kelimeler (sözlükten)',
            style: TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        const SizedBox(height: 6),
        if (widget.words.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: widget.words
                .map((w) => InputChip(
                      label: Text(w,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.primary)),
                      onDeleted: () => _removeWord(w),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      deleteIconColor: AppColors.primary,
                    ))
                .toList(),
          ),
        const SizedBox(height: 6),
        TextField(
          controller: _ctrl,
          style: const TextStyle(color: AppColors.onSurface, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Kelime ara (Çince veya pinyin)…',
            hintStyle: const TextStyle(
                color: AppColors.onSurfaceMuted, fontSize: 12),
            filled: true,
            fillColor: AppColors.surface,
            isDense: true,
            prefixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ))
                : const Icon(Icons.search,
                    size: 16, color: AppColors.onSurfaceMuted),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary)),
          ),
          onChanged: _onSearch,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: _suggestions.map((s) {
                final word = s['simplified'] as String;
                final pinyin = s['pinyin'] as String? ?? '';
                final hsk = s['hsk_level'] as int? ?? 0;
                final already = widget.words.contains(word);
                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.forHskLevel(hsk),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('HSK$hsk',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(word,
                      style: const TextStyle(
                          color: AppColors.onSurface, fontSize: 13)),
                  subtitle: Text(pinyin,
                      style: const TextStyle(
                          color: AppColors.onSurfaceMuted, fontSize: 11)),
                  trailing: already
                      ? const Icon(Icons.check,
                          color: AppColors.correctAnswer, size: 16)
                      : const Icon(Icons.add,
                          color: AppColors.primary, size: 16),
                  onTap: already ? null : () => _addWord(word),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ── Filter Dropdown ───────────────────────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  final T? value;
  final List<(String, T)> options;
  final String hint;
  final void Function(T?) onChanged;

  const _FilterDropdown({
    required this.value,
    required this.options,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<T?>(
      value: value,
      hint: Text(hint,
          style: const TextStyle(
              color: AppColors.onSurfaceMuted, fontSize: 12)),
      dropdownColor: AppColors.surfaceVariant,
      style: const TextStyle(color: AppColors.onSurface, fontSize: 12),
      underline: const SizedBox.shrink(),
      isDense: true,
      onChanged: onChanged,
      items: [
        DropdownMenuItem<T?>(
          value: null,
          child: const Text('Tümü',
              style: TextStyle(
                  color: AppColors.onSurfaceMuted, fontSize: 12)),
        ),
        ...options.map(
          (opt) => DropdownMenuItem<T?>(
            value: opt.$2,
            child: Text(opt.$1,
                style: const TextStyle(
                    color: AppColors.onSurface, fontSize: 12)),
          ),
        ),
      ],
    );
  }
}

// ── Tab 1: YouTube ────────────────────────────────────────────────────────────

class _YouTubeTab extends StatefulWidget {
  final VoidCallback onVideosChanged;
  const _YouTubeTab({required this.onVideosChanged});

  @override
  State<_YouTubeTab> createState() => _YouTubeTabState();
}

class _YouTubeTabState extends State<_YouTubeTab> {
  final _service = AdminService();
  final _urlCtrl = TextEditingController();

  bool _processing = false;
  String? _resultMsg;
  bool _resultSuccess = false;

  bool _asrProcessing = false;
  Timer? _jobPollTimer;

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
    _jobPollTimer?.cancel();
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
          _resultMsg =
              '✓ $count klip içe aktarıldı. Sağdan onaylayın.';
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

  Future<void> _processAsr() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() { _asrProcessing = true; _resultMsg = null; });
    try {
      final jobId = await _service.createYoutubeAsrJob(url, active: false);
      if (!mounted) return;
      setState(() {
        _resultSuccess = true;
        _resultMsg = '⏳ İşe alındı — pipeline arka planda çalışıyor…';
      });
      _startJobPolling(jobId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _asrProcessing = false;
          _resultSuccess = false;
          _resultMsg = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _startJobPolling(String jobId) {
    _jobPollTimer?.cancel();
    _jobPollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      try {
        final job = await _service.getJob(jobId);
        if (!mounted) return;
        final status = job['status'] as String? ?? '';
        if (status == 'processing') {
          setState(() => _resultMsg = '🔄 Whisper transkripsiyon yapıyor…');
        } else if (status == 'done') {
          final count =
              (job['result'] as Map?)?['segmentsWritten'] as int? ?? 0;
          setState(() {
            _asrProcessing = false;
            _resultSuccess = true;
            _resultMsg = '✓ $count klip içe aktarıldı (Whisper). Sağdan onaylayın.';
          });
          _jobPollTimer?.cancel();
          widget.onVideosChanged();
        } else if (status == 'error') {
          setState(() {
            _asrProcessing = false;
            _resultSuccess = false;
            _resultMsg = job['error_text'] as String? ?? 'Bilinmeyen hata';
          });
          _jobPollTimer?.cancel();
        }
      } catch (_) {}
    });
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
        'status': 'pending',
        'is_active': false,
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Segment kaydedildi! Onay bekleyenler sekmesine düştü.')));
        widget.onVideosChanged();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'),
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
          const Row(children: [
            Icon(Icons.cloud_done_outlined,
                size: 14, color: AppColors.correctAnswer),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Bulut: altyazılı videolar otomatik parçalanır',
                style:
                    TextStyle(color: AppColors.correctAnswer, fontSize: 12),
              ),
            ),
            SizedBox(width: 12),
            Icon(Icons.memory, size: 14, color: AppColors.correctAnswer),
            SizedBox(width: 4),
            Text('Whisper ASR aktif',
                style:
                    TextStyle(color: AppColors.correctAnswer, fontSize: 12)),
          ]),
          const SizedBox(height: 10),

          Row(children: [
            Expanded(
              child: TextField(
                controller: _urlCtrl,
                onChanged: (_) => setState(() {}),
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

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_urlCtrl.text.trim().isNotEmpty &&
                      !_processing &&
                      !_asrProcessing)
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

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_urlCtrl.text.trim().isNotEmpty &&
                      !_processing &&
                      !_asrProcessing)
                  ? _processAsr
                  : null,
              icon: _asrProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.graphic_eq, size: 18),
              label: Text(_asrProcessing
                  ? 'İşe alındı — pipeline çalışıyor…'
                  : 'Whisper ASR — Altyazısız Videolar İçin'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
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
                        Row(children: [
                          Expanded(
                              child: _timeField(_startCtrl, 'Başlangıç (sn)')),
                          const SizedBox(width: 8),
                          Expanded(child: _timeField(_endCtrl, 'Bitiş (sn)')),
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
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _playSegment,
                            icon: const Icon(Icons.play_circle_outline,
                                size: 18, color: AppColors.primary),
                            label: const Text('Segmenti Oynat',
                                style: TextStyle(color: AppColors.primary)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _segField(_transcriptionCtrl, 'Çince metin (汉字)'),
                        const SizedBox(height: 8),
                        _segField(_pinyinCtrl, 'Pinyin'),
                        const SizedBox(height: 10),
                        Text('HSK Seviye: $_hskLevel',
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
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _saveSegment,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Segmenti Kaydet'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
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
                    style:
                        TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
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
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
          _resultMsg = '✓ $count klip çıkarıldı. Sağdan onaylayın.';
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
            min: 0,
            max: 200,
            divisions: 40,
            activeColor: AppColors.primary,
            label: _maxClips == 0 ? '∞' : '$_maxClips',
            onChanged: (v) => setState(() => _maxClips = v.round()),
          ),
          const Text(
            'Pipeline sunucusu + ffmpeg gerektirir.',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (ready && _selectedFile != null) ? _process : null,
              icon: _processing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
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
              width: 10,
              height: 10,
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
      appBar: AppBar(title: const Text('Video Ekle')),
      body: const _YouTubeTab(onVideosChanged: _noop),
    );
  }

  static void _noop() {}
}
