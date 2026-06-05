import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/video_segment_model.dart';
import '../../../data/services/admin_service.dart';
import '../../providers/video_provider.dart';

// ── Navigation sections ───────────────────────────────────────────────────────

enum _Section { video, dictionary, users, social, game }
enum _VideoSub { youtube, movie }
enum _VideoAction { add, manage }

// ── Admin Screen ──────────────────────────────────────────────────────────────

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _service = AdminService();
  final _ytReviewKey = GlobalKey<_VideoReviewPanelState>();
  final _mvReviewKey = GlobalKey<_VideoReviewPanelState>();

  _Section _section = _Section.video;
  bool _videoOpen = false;
  bool _youtubeOpen = false;
  bool _movieOpen = false;
  _VideoSub _activeSub = _VideoSub.youtube;
  _VideoAction _activeAction = _VideoAction.add;

  @override
  void initState() {
    super.initState();
    _service.seedHsk1Dictionary();
    _service.applyDefinitionPatches();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceVariant,
        title: const Text('Admin Panel'),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NavRail(
            section: _section,
            videoOpen: _videoOpen,
            youtubeOpen: _youtubeOpen,
            movieOpen: _movieOpen,
            activeSub: _activeSub,
            activeAction: _activeAction,
            onSection: (s) => setState(() => _section = s),
            onToggleVideo: () => setState(() {
              _section = _Section.video;
              _videoOpen = !_videoOpen;
            }),
            onToggleYoutube: () => setState(() {
              _activeSub = _VideoSub.youtube;
              _youtubeOpen = !_youtubeOpen;
              if (_youtubeOpen) _movieOpen = false;
            }),
            onToggleMovie: () => setState(() {
              _activeSub = _VideoSub.movie;
              _movieOpen = !_movieOpen;
              if (_movieOpen) _youtubeOpen = false;
            }),
            onSelectAction: (sub, action) => setState(() {
              _section = _Section.video;
              _activeSub = sub;
              _activeAction = action;
            }),
          ),
          Container(width: 1, color: AppColors.surfaceVariant),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return switch (_section) {
      _Section.video      => _buildVideoBody(),
      _Section.dictionary => _DictionaryPanel(service: _service),
      _Section.users      => const _UsersPanel(),
      _Section.social     => const _SocialPanel(),
      _Section.game       => const _GamePanel(),
    };
  }

  Widget _buildVideoBody() {
    if (_activeSub == _VideoSub.youtube) {
      return _activeAction == _VideoAction.add
          ? _YouTubeTab(onVideosChanged: () => _ytReviewKey.currentState?.refresh())
          : _VideoReviewPanel(key: _ytReviewKey, service: _service, sourceType: 'youtube');
    } else {
      return _activeAction == _VideoAction.add
          ? _MovieImportTab(onVideosChanged: () => _mvReviewKey.currentState?.refresh())
          : _VideoReviewPanel(key: _mvReviewKey, service: _service, sourceType: 'self_hosted');
    }
  }
}

// ── Nav Rail ──────────────────────────────────────────────────────────────────

class _NavRail extends StatelessWidget {
  final _Section section;
  final bool videoOpen;
  final bool youtubeOpen;
  final bool movieOpen;
  final _VideoSub activeSub;
  final _VideoAction activeAction;
  final void Function(_Section) onSection;
  final void Function() onToggleVideo;
  final void Function() onToggleYoutube;
  final void Function() onToggleMovie;
  final void Function(_VideoSub, _VideoAction) onSelectAction;

  const _NavRail({
    required this.section,
    required this.videoOpen,
    required this.youtubeOpen,
    required this.movieOpen,
    required this.activeSub,
    required this.activeAction,
    required this.onSection,
    required this.onToggleVideo,
    required this.onToggleYoutube,
    required this.onToggleMovie,
    required this.onSelectAction,
  });

  bool get _videoActive => section == _Section.video;
  bool get _ytActive => _videoActive && activeSub == _VideoSub.youtube;
  bool get _mvActive => _videoActive && activeSub == _VideoSub.movie;
  bool get _ytAddActive => _ytActive && activeAction == _VideoAction.add;
  bool get _ytManageActive => _ytActive && activeAction == _VideoAction.manage;
  bool get _mvAddActive => _mvActive && activeAction == _VideoAction.add;
  bool get _mvManageActive => _mvActive && activeAction == _VideoAction.manage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      color: AppColors.surfaceVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _TopItem(
            icon: Icons.smart_display_outlined,
            label: 'Video',
            selected: _videoActive,
            open: videoOpen,
            onTap: onToggleVideo,
          ),
          if (videoOpen) ...[
            _MidItem(
              icon: Icons.play_circle_outline,
              label: 'YouTube',
              selected: _ytActive,
              open: youtubeOpen,
              onTap: onToggleYoutube,
            ),
            if (youtubeOpen) ...[
              _LeafItem(
                label: 'Ekle',
                selected: _ytAddActive,
                onTap: () => onSelectAction(_VideoSub.youtube, _VideoAction.add),
              ),
              _LeafItem(
                label: 'Yönet',
                selected: _ytManageActive,
                onTap: () => onSelectAction(_VideoSub.youtube, _VideoAction.manage),
              ),
            ],
            _MidItem(
              icon: Icons.movie_outlined,
              label: 'Movie',
              selected: _mvActive,
              open: movieOpen,
              onTap: onToggleMovie,
            ),
            if (movieOpen) ...[
              _LeafItem(
                label: 'Ekle',
                selected: _mvAddActive,
                onTap: () => onSelectAction(_VideoSub.movie, _VideoAction.add),
              ),
              _LeafItem(
                label: 'Yönet',
                selected: _mvManageActive,
                onTap: () => onSelectAction(_VideoSub.movie, _VideoAction.manage),
              ),
            ],
          ],
          _TopItem(
            icon: Icons.menu_book_outlined,
            label: 'Sözlük',
            selected: section == _Section.dictionary,
            open: false,
            hasChildren: false,
            onTap: () => onSection(_Section.dictionary),
          ),
          _TopItem(
            icon: Icons.manage_accounts_outlined,
            label: 'Kullanıcılar',
            selected: section == _Section.users,
            open: false,
            hasChildren: false,
            onTap: () => onSection(_Section.users),
          ),
          _TopItem(
            icon: Icons.people_outline,
            label: 'Sosyal',
            selected: section == _Section.social,
            open: false,
            hasChildren: false,
            onTap: () => onSection(_Section.social),
          ),
          _TopItem(
            icon: Icons.sports_esports_outlined,
            label: 'Oyun',
            selected: section == _Section.game,
            open: false,
            hasChildren: false,
            onTap: () => onSection(_Section.game),
          ),
        ],
      ),
    );
  }
}

// ── Nav item widgets ──────────────────────────────────────────────────────────

class _TopItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool open;
  final bool hasChildren;
  final VoidCallback onTap;

  const _TopItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.open,
    this.hasChildren = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.onSurfaceMuted;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (hasChildren)
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: color,
              ),
          ],
        ),
      ),
    );
  }
}

class _MidItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool open;
  final VoidCallback onTap;

  const _MidItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.onSurfaceMuted;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.only(left: 30, right: 14),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              open ? Icons.expand_less : Icons.expand_more,
              size: 14,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeafItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LeafItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.onSurfaceMuted;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 50, right: 14),
        color: selected
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}


// ── Dictionary Panel ──────────────────────────────────────────────────────────

class _DictionaryPanel extends StatefulWidget {
  final AdminService service;
  const _DictionaryPanel({required this.service});

  @override
  State<_DictionaryPanel> createState() => _DictionaryPanelState();
}

class _DictionaryPanelState extends State<_DictionaryPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final Set<int> _selectedLevels = {1};

  List<Map<String, dynamic>> _words = [];
  bool _loading = false;
  String? _error;
  int _offset = 0;
  static const _pageSize = 100;

  bool _seeding = false;
  String? _seedMsg;

  List<Map<String, dynamic>> _suggestions = [];
  bool _loadingSugg = false;
  String? _suggError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() {});
        if (_tabs.index == 2 && _suggestions.isEmpty && !_loadingSugg) {
          _loadSuggestions();
        }
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) _offset = 0;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.service.listDictionaryWords(
        hskLevels: _selectedLevels.toList()..sort(),
        offset: _offset,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _words = reset ? result : [..._words, ...result];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _toggleLevel(int level) {
    setState(() {
      if (_selectedLevels.contains(level)) {
        if (_selectedLevels.length > 1) _selectedLevels.remove(level);
      } else {
        _selectedLevels.add(level);
      }
    });
    _load();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _deleteWord(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: Text('$id kelimesini sil?',
            style: const TextStyle(color: AppColors.onSurface)),
        content: const Text('Bu işlem geri alınamaz.',
            style: TextStyle(color: AppColors.onSurfaceMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil',
                  style: TextStyle(color: AppColors.wrongAnswer))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.deleteDictionaryWord(id);
      _snack('✓ $id silindi');
      _load();
    } catch (e) {
      _snack('Hata: $e');
    }
  }

  Future<void> _openAddDialog() async {
    await showDialog(
      context: context,
      builder: (_) => _WordEditDialog(
        service: widget.service,
        onSaved: () { _load(); Navigator.pop(context); },
      ),
    );
  }

  Future<void> _openEditDialog(Map<String, dynamic> word) async {
    await showDialog(
      context: context,
      builder: (_) => _WordEditDialog(
        service: widget.service,
        initialWord: word,
        onSaved: () { _load(); Navigator.pop(context); },
      ),
    );
  }

  Future<void> _seedHsk6() async {
    setState(() { _seeding = true; _seedMsg = null; });
    try {
      final count = await widget.service.seedHsk6Dictionary();
      if (mounted) {
        setState(() { _seeding = false; _seedMsg = '✓ $count kelime eklendi'; });
        _load();
      }
    } catch (e) {
      if (mounted) setState(() { _seeding = false; _seedMsg = 'Hata: $e'; });
    }
  }

  Future<void> _loadSuggestions() async {
    setState(() { _loadingSugg = true; _suggError = null; });
    try {
      final result = await widget.service.listWordSuggestions();
      if (mounted) setState(() { _suggestions = result; _loadingSugg = false; });
    } catch (e) {
      if (mounted) setState(() { _suggError = e.toString(); _loadingSugg = false; });
    }
  }

  Future<void> _deleteSuggestion(String id) async {
    try {
      await widget.service.deleteWordSuggestion(id);
      _snack('Silindi');
      _loadSuggestions();
    } catch (e) {
      _snack('Hata: $e');
    }
  }

  Widget _buildSuggestionsPanel() {
    if (_loadingSugg) return const Center(child: CircularProgressIndicator());
    if (_suggError != null) {
      return Center(
        child: Text(_suggError!,
            style: const TextStyle(color: AppColors.wrongAnswer),
            textAlign: TextAlign.center),
      );
    }
    if (_suggestions.isEmpty) {
      return const Center(
        child: Text('Henüz öneri yok',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
      );
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.surfaceVariant,
          child: Row(
            children: [
              Text('${_suggestions.length} öneri',
                  style: const TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => const Divider(
                height: 1, color: AppColors.surfaceVariant, indent: 56),
            itemBuilder: (_, i) {
              final s = _suggestions[i];
              // posts row: content=word, metadata.suggested_by_email, timestamp
              final word = s['content'] as String? ?? '';
              final meta = s['metadata'] as Map<String, dynamic>? ?? {};
              final by = meta['suggested_by_email'] as String? ?? '';
              final ts = s['timestamp'] as String? ?? '';
              final shortDate = ts.length >= 10 ? ts.substring(0, 10) : ts;
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.onSurfaceMuted.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(word,
                      style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(word,
                    style: const TextStyle(
                        color: AppColors.onSurface, fontSize: 14)),
                subtitle: Text(
                    '${by.isNotEmpty ? by : 'Anonim'} • $shortDate',
                    style: const TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.wrongAnswer),
                  onPressed: () => _deleteSuggestion(s['id'] as String),
                  tooltip: 'Sil',
                  style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Left: filter panel (260px) ───────────────────────────────────
        SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: AppColors.surfaceVariant,
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.onSurfaceMuted,
                  tabs: const [
                    Tab(text: 'Aktif'),
                    Tab(text: 'Pasif'),
                    Tab(text: 'Önerilen'),
                  ],
                ),
              ),
              if (_tabs.index == 0) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Text('HSK Seviyesi',
                      style: TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(9, (i) {
                      final level = i + 1;
                      final sel = _selectedLevels.contains(level);
                      return FilterChip(
                        label: Text('HSK $level',
                            style: TextStyle(
                                fontSize: 11,
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.onSurfaceMuted)),
                        selected: sel,
                        onSelected: (_) => _toggleLevel(level),
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        checkmarkColor: AppColors.primary,
                        side: BorderSide(
                          color: sel
                              ? AppColors.primary
                              : AppColors.onSurfaceMuted.withValues(alpha: 0.3),
                        ),
                        backgroundColor: AppColors.surface,
                        showCheckmark: false,
                        avatar: sel
                            ? null
                            : Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.forHskLevel(level),
                                  shape: BoxShape.circle,
                                ),
                              ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Yenile', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _seeding ? null : _seedHsk6,
                      icon: _seeding
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary))
                          : const Icon(Icons.upload_outlined, size: 16),
                      label: Text(
                        _seeding ? 'Yükleniyor…' : 'Seed HSK 6',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
                if (_seedMsg != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Text(
                      _seedMsg!,
                      style: TextStyle(
                        fontSize: 11,
                        color: _seedMsg!.startsWith('Hata')
                            ? AppColors.wrongAnswer
                            : AppColors.correctAnswer,
                      ),
                    ),
                  ),
              ] else if (_tabs.index == 2) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loadSuggestions,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Yenile',
                          style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
              ] else
                const Expanded(
                  child: Center(
                    child: Text('Pasif kelimeler yakında',
                        style: TextStyle(
                            color: AppColors.onSurfaceMuted, fontSize: 13)),
                  ),
                ),
            ],
          ),
        ),
        Container(width: 1, color: AppColors.surfaceVariant),
        // ── Right: word list / suggestions ──────────────────────────────
        Expanded(
          child: _tabs.index == 2
              ? _buildSuggestionsPanel()
              : Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: AppColors.surfaceVariant,
                      child: Row(
                        children: [
                          Text(
                            _loading
                                ? 'Yükleniyor…'
                                : '${_words.length} kelime',
                            style: const TextStyle(
                                color: AppColors.onSurfaceMuted, fontSize: 13),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _openAddDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Yeni Kelime Ekle',
                                style: TextStyle(fontSize: 13)),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Body
                    Expanded(
                      child: _tabs.index == 0
                          ? _buildWordList()
                          : const Center(
                              child: Text('Pasif kelimeler yakında',
                                  style: TextStyle(
                                      color: AppColors.onSurfaceMuted,
                                      fontSize: 13)),
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildWordList() {
    if (_loading && _words.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
          child: Text(_error!,
              style: const TextStyle(color: AppColors.wrongAnswer)));
    }
    if (_words.isEmpty) {
      return const Center(
          child: Text('Kelime bulunamadı',
              style: TextStyle(color: AppColors.onSurfaceMuted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      itemCount: _words.length + (_words.length == _pageSize ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(
          height: 1,
          color: AppColors.surfaceVariant,
          indent: 56),
      itemBuilder: (_, i) {
        if (i == _words.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: TextButton(
                onPressed: () {
                  _offset += _pageSize;
                  _load(reset: false);
                },
                child: const Text('Daha fazla yükle'),
              ),
            ),
          );
        }
        final w = _words[i];
        return _DictionaryWordRow(
          word: w,
          onEdit: () => _openEditDialog(w),
          onDelete: () => _deleteWord(w['id'] as String),
        );
      },
    );
  }
}

// ── Dictionary word row ───────────────────────────────────────────────────────

class _DictionaryWordRow extends StatelessWidget {
  final Map<String, dynamic> word;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DictionaryWordRow({
    required this.word,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final simplified = word['simplified'] as String? ?? '';
    final pinyin = word['pinyin'] as String? ?? '';
    final hsk = (word['hsk_level'] as int?) ?? 0;
    final defs = word['definitions'] as Map<String, dynamic>? ?? {};
    final en = defs['en'] as String? ?? '';
    final tr = defs['tr'] as String? ?? '';
    final pos = defs['pos'] as String? ?? '';

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.forHskLevel(hsk),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(simplified,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ),
      title: Row(
        children: [
          Text(pinyin,
              style: const TextStyle(
                  color: AppColors.onSurface, fontSize: 14)),
          const SizedBox(width: 8),
          if (pos.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.onSurfaceMuted.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(pos.split('/').first.split(',').first.trim(),
                  style: const TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 10)),
            ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.forHskLevel(hsk).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: AppColors.forHskLevel(hsk).withValues(alpha: 0.4)),
            ),
            child: Text('HSK $hsk',
                style: TextStyle(
                    color: AppColors.forHskLevel(hsk),
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (en.isNotEmpty)
            Text('EN: $en',
                style: const TextStyle(
                    color: AppColors.onSurfaceMuted, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          if (tr.isNotEmpty)
            Text('TR: $tr',
                style: const TextStyle(
                    color: AppColors.onSurfaceMuted, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: AppColors.onSurfaceMuted),
            onPressed: onEdit,
            tooltip: 'Düzenle',
            style: IconButton.styleFrom(
                minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.wrongAnswer),
            onPressed: onDelete,
            tooltip: 'Sil',
            style: IconButton.styleFrom(
                minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }
}

// ── Word Edit / Add Dialog ────────────────────────────────────────────────────

class _WordEditDialog extends StatefulWidget {
  final AdminService service;
  final Map<String, dynamic>? initialWord;
  final VoidCallback onSaved;

  const _WordEditDialog({
    required this.service,
    required this.onSaved,
    this.initialWord,
  });

  @override
  State<_WordEditDialog> createState() => _WordEditDialogState();
}

class _WordEditDialogState extends State<_WordEditDialog> {
  late final TextEditingController _simplified;
  late final TextEditingController _pinyin;
  late final TextEditingController _pos;
  late final TextEditingController _en;
  late final TextEditingController _tr;
  late int _hskLevel;
  bool _saving = false;

  bool get _isEdit => widget.initialWord != null;

  @override
  void initState() {
    super.initState();
    final w = widget.initialWord;
    final defs = (w?['definitions'] as Map<String, dynamic>?) ?? {};
    _simplified = TextEditingController(text: w?['simplified'] as String? ?? '');
    _pinyin = TextEditingController(text: w?['pinyin'] as String? ?? '');
    _pos = TextEditingController(text: defs['pos'] as String? ?? '');
    _en = TextEditingController(text: defs['en'] as String? ?? '');
    _tr = TextEditingController(text: defs['tr'] as String? ?? '');
    _hskLevel = (w?['hsk_level'] as int?) ?? 1;
  }

  @override
  void dispose() {
    _simplified.dispose();
    _pinyin.dispose();
    _pos.dispose();
    _en.dispose();
    _tr.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_simplified.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.service.saveDictionaryWord({
        'simplified': _simplified.text.trim(),
        'pinyin': _pinyin.text.trim(),
        'hsk_level': _hskLevel,
        'definitions': {
          'pos': _pos.text.trim(),
          'en': _en.text.trim(),
          'tr': _tr.text.trim(),
          'vi': '',
        },
      });
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceVariant,
      title: Text(_isEdit ? '${_simplified.text} Düzenle' : 'Yeni Kelime Ekle',
          style: const TextStyle(color: AppColors.onSurface, fontSize: 16)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_simplified, 'Çince karakter (simplified)', enabled: !_isEdit),
              const SizedBox(height: 8),
              _field(_pinyin, 'Pinyin (tonlarla, örn: nǐ hǎo)'),
              const SizedBox(height: 8),
              _field(_pos, 'Sözcük türü (noun, verb, adjective…)'),
              const SizedBox(height: 8),
              _field(_en, 'İngilizce anlam'),
              const SizedBox(height: 8),
              _field(_tr, 'Türkçe anlam'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('HSK $_hskLevel',
                      style: const TextStyle(
                          color: AppColors.onSurface, fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: _hskLevel.toDouble(),
                      min: 1,
                      max: 9,
                      divisions: 8,
                      activeColor: AppColors.forHskLevel(_hskLevel),
                      label: 'HSK $_hskLevel',
                      onChanged: (v) => setState(() => _hskLevel = v.round()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal')),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(_isEdit ? 'Güncelle' : 'Ekle'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool enabled = true}) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
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
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
      ),
    );
  }
}

// ── Video Review Panel ────────────────────────────────────────────────────────

class _VideoReviewPanel extends StatefulWidget {
  final AdminService service;
  final String? sourceType;
  const _VideoReviewPanel({super.key, required this.service, this.sourceType});

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
                  options: [
                    for (var lvl = 1; lvl <= 6; lvl++)
                      for (final c in (kGrammarByHsk[lvl] ?? const []))
                        ('L$lvl · ${c.displayName}', c.name),
                  ],
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
                sourceType: widget.sourceType,
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
                sourceType: widget.sourceType,
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
                sourceType: widget.sourceType,
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
  final String? sourceType;

  const _VideoStatusTab({
    super.key,
    required this.status,
    required this.service,
    required this.onRefresh,
    this.filterHsk,
    this.filterCategory,
    this.filterLength,
    this.searchQuery = '',
    this.sourceType,
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
    if (widget.sourceType != null) {
      result = result
          .where((v) => (v['source_type'] as String?) == widget.sourceType)
          .toList();
    }
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
      // Derive a pinyin that matches the confirmed target_words (the card title),
      // so an edited sentence no longer shows the stale ASR pinyin. One batched
      // dictionary lookup for the whole list.
      final allWords = <String>{};
      for (final v in list) {
        allWords.addAll(
            (v['target_words'] as List<dynamic>?)?.map((e) => e.toString()) ??
                const []);
      }
      final pmap = await widget.service.pinyinForWords(allWords.toList());
      for (final v in list) {
        final ws = (v['target_words'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [];
        if (ws.isNotEmpty) {
          final p =
              ws.map((w) => pmap[w] ?? '').where((x) => x.isNotEmpty).join(' ');
          if (p.isNotEmpty) v['pinyin_derived'] = p;
        }
      }
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
      await widget.service.restoreVideos(_selected.toList());
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

  Future<void> _bulkHardDelete() async {
    if (_selected.isEmpty) return;
    final count = _selected.length;
    final ids = _selected.toList();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: Text('$count videoyu tamamen sil?',
            style: const TextStyle(color: AppColors.onSurface)),
        content: const Text(
            'Bu işlem geri alınamaz. Videolar hiçbir listede görünmeyecek.',
            style: TextStyle(color: AppColors.onSurfaceMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tamamen Sil',
                  style: TextStyle(color: AppColors.wrongAnswer))),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    setState(() => _bulkLoading = true);
    try {
      await widget.service.hardDeleteVideos(ids);
      if (mounted) {
        _snack('$count video kalıcı olarak silindi');
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) _snack('Silme hatası: $e');
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
              const SizedBox(width: 6),
              _actionBtn('Tamamen Sil', AppColors.wrongAnswer,
                  onPressed: disabled ? null : _bulkHardDelete),
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
                            // Stable identity: without a key Flutter reuses a
                            // card's State by list position, so after a refresh
                            // (or a streaming insert) the edit fields kept the
                            // PREVIOUS row's text while thumbnail/time updated —
                            // the "card shows a different sentence" desync.
                            key: ValueKey(id),
                            data: video,
                            service: widget.service,
                            // Refresh ALL tabs (not just this one) so an
                            // approved clip leaves "pending" and shows under
                            // "active" immediately after Save / Save & Approve.
                            onSaved: widget.onRefresh,
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

class _VideoCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  final AdminService service;
  final VoidCallback onSaved;

  const _VideoCard({
    super.key,
    required this.data,
    required this.service,
    required this.onSaved,
  });

  @override
  ConsumerState<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends ConsumerState<_VideoCard> {
  bool _expanded = false;
  // Multi-tag classification (mirrors the home filters). Add via dropdown,
  // remove via chip. Auto-seeded from the row on first open.
  final Set<int> _hskLevels = {};
  final Set<String> _quizCategories = {};
  final Set<String> _lifeCategories = {};
  late List<String> _targetWords;
  late final TextEditingController _transcriptionCtrl;
  late final TextEditingController _pinyinCtrl;
  late final TextEditingController _questionCtrl;
  late final TextEditingController _correctCtrl;
  late final TextEditingController _wrongCtrl;
  late final TextEditingController _correctCtrlEn;
  late final TextEditingController _wrongCtrlEn;
  String _selectedQuizLang = 'tr';
  bool _saving = false;
  bool _generating = false;
  bool _segmenting = false;
  bool _whisperRunning = false;
  List<String>? _confirmedWords;
  // Live overrides for the collapsed card header so confirming words / applying
  // Whisper updates the title + pinyin INSTANTLY (before Save/reload).
  List<String>? _liveTitleWords;
  String? _livePinyin;
  String? _whisperText;
  Timer? _whisperTimer;
  String? _asrTranslation; // TR translation of the ASR/edited sentence
  String? _whisperTranslation; // TR translation of the Whisper result
  bool _trAsrBusy = false;
  bool _trWhisperBusy = false;
  bool _pinyinBusy = false;

  YoutubePlayerController? _ytController;
  Timer? _segmentTimer; // restricts playback to start..end
  bool _segEnded = false;

  @override
  void initState() {
    super.initState();
    final v = widget.data;
    _hskLevels.addAll(
        ((v['hsk_levels'] as List<dynamic>?) ?? []).map((e) => (e as num).toInt()));
    if (_hskLevels.isEmpty) _hskLevels.add((v['hsk_level'] as int?) ?? 1);
    _quizCategories.addAll(
        ((v['quiz_categories'] as List<dynamic>?) ?? []).map((e) => e.toString()));
    if (_quizCategories.isEmpty) {
      _quizCategories.add(v['quiz_category'] as String? ?? 'general');
    }
    _lifeCategories.addAll(
        ((v['life_categories'] as List<dynamic>?) ?? []).map((e) => e.toString()));
    if (_lifeCategories.isEmpty) {
      _lifeCategories.add(v['life_category'] as String? ?? 'daily_life');
    }
    _targetWords = List<String>.from(
        (v['target_words'] as List<dynamic>?) ?? []);
    final tr = v['transcription'] as String? ?? '';
    _transcriptionCtrl =
        TextEditingController(text: tr);
    _pinyinCtrl = TextEditingController(text: v['pinyin'] as String? ?? '');
    _whisperText = v['whisper_text'] as String?;
    final quiz = v['quiz'] as Map<String, dynamic>? ?? {};
    _questionCtrl =
        TextEditingController(text: quiz['question'] as String? ?? '');
    _correctCtrl =
        TextEditingController(text: quiz['correctAnswer'] as String? ?? '');
    _wrongCtrl =
        TextEditingController(text: quiz['wrongAnswer'] as String? ?? '');
    final quizEn = (quiz['en'] as Map<String, dynamic>?) ?? {};
    _correctCtrlEn = TextEditingController(
        text: quizEn['correctAnswer'] as String? ?? '');
    _wrongCtrlEn = TextEditingController(
        text: quizEn['wrongAnswer'] as String? ?? '');
  }

  void _openInlinePlayer() {
    final v = widget.data;
    final ytId = v['youtube_id'] as String?;
    if (ytId == null || ytId.isEmpty) return;
    final start = (v['start_time'] as num?)?.toDouble() ?? 0.0;
    _segEnded = false;
    setState(() {
      _ytController?.close();
      _ytController = YoutubePlayerController.fromVideoId(
        videoId: ytId,
        startSeconds: start,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: false,
          loop: false,
          playsInline: true,
        ),
      );
      if (!_expanded) _expanded = true;
    });
    _startSegmentMonitor();
  }

  // Keep the preview inside [start, end] — same as the home player.
  void _startSegmentMonitor() {
    _segmentTimer?.cancel();
    final v = widget.data;
    final start = (v['start_time'] as num?)?.toDouble() ?? 0.0;
    final end = (v['end_time'] as num?)?.toDouble() ?? 0.0;
    if (end <= start) return;
    _segmentTimer =
        Timer.periodic(const Duration(milliseconds: 400), (_) async {
      final c = _ytController;
      if (c == null) return;
      final t = await c.currentTime;
      if (!_segEnded && t >= end) {
        _segEnded = true;
        await c.pauseVideo();
      } else if (t < start - 1) {
        await c.seekTo(seconds: start, allowSeekAhead: true);
      }
    });
  }

  Future<void> _replaySegment() async {
    final c = _ytController;
    if (c == null) return;
    final start = (widget.data['start_time'] as num?)?.toDouble() ?? 0.0;
    _segEnded = false;
    await c.seekTo(seconds: start, allowSeekAhead: true);
    await c.playVideo();
  }

  void _closeInlinePlayer() {
    _segmentTimer?.cancel();
    _ytController?.close();
    setState(() => _ytController = null);
  }

  @override
  void dispose() {
    _segmentTimer?.cancel();
    _whisperTimer?.cancel();
    _ytController?.close();
    _transcriptionCtrl.dispose();
    _pinyinCtrl.dispose();
    _questionCtrl.dispose();
    _correctCtrl.dispose();
    _wrongCtrl.dispose();
    _correctCtrlEn.dispose();
    _wrongCtrlEn.dispose();
    super.dispose();
  }

  // Ask Gemini (server-side edge function) for the two translation options and
  // fill the fields; the admin reviews/edits, then Saves. Gemini is used only
  // here — the saved options are served from the DB afterwards.
  Future<void> _generateQuiz() async {
    if (_confirmedWords == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Önce kelimeleri ayırıp "Kelimeleri Onayla"ya bas.')));
      return;
    }
    final transcription = _confirmedWords!.join('');
    if (transcription.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu klipte transkripsiyon yok.')));
      return;
    }
    setState(() => _generating = true);
    try {
      final q = await widget.service.generateQuiz(
        transcription: transcription,
        pinyin: _pinyinCtrl.text.trim(),
        lang: _selectedQuizLang,
      );
      if (!mounted) return;
      setState(() {
        if (_selectedQuizLang == 'tr') {
          _correctCtrl.text = q['correctAnswer'] ?? '';
          _wrongCtrl.text = q['wrongAnswer'] ?? '';
        } else {
          _correctCtrlEn.text = q['correctAnswer'] ?? '';
          _wrongCtrlEn.text = q['wrongAnswer'] ?? '';
        }
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Üretim hatası: $e')));
    }
  }

  // Split the sentence into word chips that exactly reconstruct it.
  Future<void> _segmentIntoWords() async {
    // Each line of the sentence box is a separate sentence: split per line and
    // join the word groups with the '\n' sentinel so the player shows them
    // stacked and the word editor shows them line by line.
    final lines = _transcriptionCtrl.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    setState(() => _segmenting = true);
    try {
      final words = <String>[];
      for (final line in lines) {
        final ws = await widget.service.segmentSentence(line);
        if (ws.isEmpty) continue;
        if (words.isNotEmpty) words.add('\n');
        words.addAll(ws);
      }
      if (!mounted) return;
      setState(() {
        _targetWords = words;
        _segmenting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _segmenting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Bölme hatası: $e')));
    }
  }

  // Enqueue a Whisper job (needs the local worker running), poll it, then load
  // the whisper_text written for this clip so it can be compared/picked.
  Future<void> _runWhisper() async {
    final ytId = widget.data['youtube_id'] as String?;
    if (ytId == null || ytId.isEmpty) return;
    final url = 'https://www.youtube.com/watch?v=$ytId';
    final start = (widget.data['start_time'] as num?)?.toDouble() ?? 0.0;
    final end = (widget.data['end_time'] as num?)?.toDouble() ?? 0.0;
    setState(() => _whisperRunning = true);
    try {
      final jobId = await widget.service.createWhisperJob(
        url,
        start: start,
        end: end,
        rowId: widget.data['id'] as String,
      );
      _whisperTimer?.cancel();
      _whisperTimer = Timer.periodic(const Duration(seconds: 4), (t) async {
        try {
          final job = await widget.service.getJob(jobId);
          final status = job['status'] as String?;
          if (status == 'done') {
            t.cancel();
            final v = await widget.service.getVideo(widget.data['id'] as String);
            if (!mounted) return;
            setState(() {
              _whisperText = v?['whisper_text'] as String?;
              _whisperRunning = false;
            });
            if ((_whisperText ?? '').isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Whisper bu klip için metin üretemedi.')));
            }
          } else if (status == 'error') {
            t.cancel();
            if (!mounted) return;
            setState(() => _whisperRunning = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Whisper hatası: ${job['error_text'] ?? 'bilinmiyor'}')));
          }
        } catch (_) {/* keep polling */}
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _whisperRunning = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('İş oluşturulamadı: $e')));
    }
  }

  Future<void> _save({bool approve = false}) async {
    final id = widget.data['id'] as String;
    // Primary single values (first tag) kept for backward compatibility + the
    // collapsed card badge; the arrays drive the home filtering.
    final hskList = _hskLevels.toList()..sort();
    final catList = _quizCategories.toList();
    final lifeList = _lifeCategories.toList();
    setState(() => _saving = true);
    try {
      await widget.service.patchVideoFields(id, {
        'transcription': _transcriptionCtrl.text.trim(),
        'pinyin': _pinyinCtrl.text.trim(),
        'hsk_level': hskList.isNotEmpty ? hskList.first : 1,
        'quiz_category': catList.isNotEmpty ? catList.first : 'general',
        'life_category': lifeList.isNotEmpty ? lifeList.first : 'daily_life',
        'hsk_levels': hskList,
        'quiz_categories': catList,
        'life_categories': lifeList,
        'target_words': _targetWords,
        'quiz': {
          'question': _questionCtrl.text.trim(),
          'correctAnswer': _correctCtrl.text.trim(),
          'wrongAnswer': _wrongCtrl.text.trim(),
          'en': {
            'correctAnswer': _correctCtrlEn.text.trim(),
            'wrongAnswer': _wrongCtrlEn.text.trim(),
          },
        },
      });
      // Approve in the same step so an edited clip actually reaches the home
      // feed (which only shows is_active=true); saving alone leaves it pending.
      if (approve) await widget.service.approveVideos([id]);
      if (mounted) {
        // Invalidate the homepage feed so the next visit fetches fresh quiz data.
        ref.invalidate(videoFeedProvider);
        setState(() { _saving = false; _expanded = false; });
        if (approve) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✓ Kaydedildi ve onaylandı — anasayfada görünür')));
        }
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

  // Apply the Whisper result to the sentence AND refresh the pinyin to match
  // (the old pinyin was for the previous sentence). The sentence is no longer
  // confirmed, so the live card overrides reset until "Kelimeleri Onayla".
  Future<void> _applyWhisper() async {
    final t = _whisperText ?? '';
    if (t.isEmpty) return;
    setState(() {
      _transcriptionCtrl.text = t;
      _confirmedWords = null;
      _liveTitleWords = null;
      _livePinyin = null;
      _asrTranslation = null;
      _pinyinBusy = true;
    });
    try {
      final py = await widget.service.pinyinForText(t);
      if (mounted && py.isNotEmpty) setState(() => _pinyinCtrl.text = py);
    } catch (_) {/* keep old pinyin on failure */}
    finally {
      if (mounted) setState(() => _pinyinBusy = false);
    }
  }

  // "Kelimeleri Onayla": lock in the current word list AND instantly refresh the
  // ASR pinyin field + the collapsed card title/pinyin from the confirmed words.
  Future<void> _onConfirmWords() async {
    final words = List<String>.from(_targetWords);
    setState(() {
      _confirmedWords = words;
      _liveTitleWords = words; // card title updates instantly
      _pinyinBusy = true;
    });
    try {
      final spoken = words.where((w) => w != '\n').toList();
      final pmap = await widget.service.pinyinForWords(spoken);
      final py = spoken
          .map((w) => pmap[w] ?? '')
          .where((p) => p.isNotEmpty)
          .join(' ');
      if (mounted && py.isNotEmpty) {
        setState(() {
          _pinyinCtrl.text = py; // ASR pinyin field
          _livePinyin = py; // collapsed card pinyin
        });
      }
    } catch (_) {/* keep existing pinyin on failure */}
    finally {
      if (mounted) setState(() => _pinyinBusy = false);
    }
  }

  Future<void> _refreshPinyin() async {
    final t = _transcriptionCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() => _pinyinBusy = true);
    try {
      final py = await widget.service.pinyinForText(t);
      if (mounted && py.isNotEmpty) _pinyinCtrl.text = py;
    } catch (_) {}
    finally {
      if (mounted) setState(() => _pinyinBusy = false);
    }
  }

  Future<void> _translateAsr() async {
    final t = _transcriptionCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() => _trAsrBusy = true);
    try {
      final tr = await widget.service.translateText(t);
      if (mounted) setState(() => _asrTranslation = tr);
    } catch (e) {
      if (mounted) setState(() => _asrTranslation = 'Çeviri hatası: $e');
    } finally {
      if (mounted) setState(() => _trAsrBusy = false);
    }
  }

  Future<void> _translateWhisper() async {
    final t = _whisperText ?? '';
    if (t.isEmpty) return;
    setState(() => _trWhisperBusy = true);
    try {
      final tr = await widget.service.translateText(t);
      if (mounted) setState(() => _whisperTranslation = tr);
    } catch (e) {
      if (mounted) setState(() => _whisperTranslation = 'Çeviri hatası: $e');
    } finally {
      if (mounted) setState(() => _trWhisperBusy = false);
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
    // Title shows the confirmed word order (target_words), falling back to the
    // ASR transcription, so an edited sentence is reflected here too. A live
    // override (set on "Kelimeleri Onayla") updates it instantly before save.
    final words = _liveTitleWords ??
        (v['target_words'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        [];
    final titleText = words.isNotEmpty
        ? words.map((w) => w == '\n' ? ' / ' : w).join('')
        : (v['transcription'] as String? ?? id).replaceAll('\n', ' / ');
    final headerPinyin = _livePinyin ??
        ((v['pinyin_derived'] as String?)?.isNotEmpty == true
            ? v['pinyin_derived'] as String
            : (v['pinyin'] as String? ?? ''));

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
              titleText,
              style:
                  const TextStyle(color: AppColors.onSurface, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    headerPinyin,
                    style: const TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (ytId != null && ytId.isNotEmpty)
                  GestureDetector(
                    onTap: _openInlinePlayer,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_circle_outline,
                            size: 12, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Text(
                          '$ytId  (${(v['start_time'] as num?)?.toInt() ?? 0}s)',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              decoration: TextDecoration.underline),
                        ),
                      ],
                    ),
                  )
                else
                  const Text('—',
                      style: TextStyle(
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
              onPressed: () {
                setState(() => _expanded = !_expanded);
                // Show the player in the left column right away, like home.
                if (_expanded && _ytController == null) _openInlinePlayer();
              },
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.surface),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left: video player ──────────────────────────────────
                  SizedBox(
                    width: 420,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  if (ytId != null && ytId.isNotEmpty) ...[
                    // Inline player or clickable thumbnail
                    if (_ytController != null) ...[
                      // Fixed 400×225 box — same proportions as home-screen cards
                      SizedBox(
                        width: 400,
                        height: 225,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: YoutubePlayerScaffold(
                            controller: _ytController!,
                            builder: (_, player) => player,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _replaySegment,
                            icon: const Icon(Icons.replay, size: 14),
                            label: const Text('Tekrar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _closeInlinePlayer,
                            icon: const Icon(Icons.close, size: 14),
                            label: const Text('Kapat'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.onSurfaceMuted,
                              side: const BorderSide(
                                  color: AppColors.onSurfaceMuted),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _openPreview,
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: const Text("YouTube'da Aç"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side:
                                  const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Thumbnail with play overlay → click to embed
                      GestureDetector(
                        onTap: _openInlinePlayer,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.network(
                                'https://img.youtube.com/vi/$ytId/mqdefault.jpg',
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 140,
                                  color: AppColors.surface,
                                  child: const Center(
                                    child: Icon(Icons.play_circle_outline,
                                        color: AppColors.onSurfaceMuted,
                                        size: 48),
                                  ),
                                ),
                              ),
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow,
                                    color: Colors.white, size: 32),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // ── Right: metadata, words, quiz ────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // ── Classification filters — the SAME 5 groups as the home
                  // feed, left-to-right. Multi-select: add from the dropdown,
                  // remove from the chips below. Saved as tag arrays so the clip
                  // shows under every matching home filter once approved.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _multiDropdown<String>(
                        label: 'Hayat',
                        options: [
                          for (final c in LifeCategory.values)
                            (value: c.name, text: c.tr),
                        ],
                        chosen: _lifeCategories,
                        onAdd: (v) => setState(() => _lifeCategories.add(v)),
                      ),
                      _multiDropdown<int>(
                        label: 'HSK',
                        options: [
                          for (var i = 1; i <= 6; i++) (value: i, text: 'HSK $i'),
                        ],
                        chosen: _hskLevels,
                        onAdd: (v) => setState(() => _hskLevels.add(v)),
                      ),
                      _multiDropdown<QuizCategory>(
                        label: 'Gramer',
                        // Grouped by HSK level: each level's grammar rules listed
                        // under an "L1 · …" prefix, in curriculum order.
                        options: [
                          for (var lvl = 1; lvl <= 6; lvl++)
                            for (final c in (kGrammarByHsk[lvl] ?? const []))
                              (value: c, text: 'L$lvl · ${c.displayName}'),
                          (value: QuizCategory.general,
                              text: QuizCategory.general.displayName),
                        ],
                        chosen: _quizCategories
                            .map(QuizCategory.fromString)
                            .toSet(),
                        onAdd: (v) =>
                            setState(() => _quizCategories.add(v.name)),
                      ),
                      // Length (SinoRhythm) is derived from the sentence.
                      _readonlyFilter('Uzunluk', _lengthBucket()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final lvl in _hskLevels.toList()..sort())
                        _tagChip('HSK $lvl',
                            () => setState(() => _hskLevels.remove(lvl))),
                      for (final c in _quizCategories)
                        _tagChip(QuizCategory.fromString(c).displayName,
                            () => setState(() => _quizCategories.remove(c))),
                      for (final lc in _lifeCategories)
                        _tagChip(_lifeLabel(lc),
                            () => setState(() => _lifeCategories.remove(lc))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Left = ASR (auto-caption), Right = Whisper (clip range only).
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Left: ASR transcription (auto-filled, editable) ────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Cümle — ASR (oto-altyazı)',
                                style: TextStyle(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            const SizedBox(height: 6),
                            _editField(_transcriptionCtrl, 'Çince cümle',
                                maxLines: 3),
                            _editField(_pinyinCtrl, 'Pinyin'),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _miniBtn(
                                  _pinyinBusy ? 'Pinyin…' : 'Pinyin yenile',
                                  Icons.refresh,
                                  _pinyinBusy ? null : _refreshPinyin,
                                ),
                                _miniBtn(
                                  _trAsrBusy ? 'Çevriliyor…' : 'Türkçesi',
                                  Icons.translate,
                                  _trAsrBusy ? null : _translateAsr,
                                ),
                              ],
                            ),
                            if ((_asrTranslation ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('TR: ${_asrTranslation!}',
                                    style: const TextStyle(
                                        color: AppColors.onSurfaceMuted,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ── Right: Whisper (optional, only the clip's seconds) ──
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Whisper (seçili aralık)',
                                style: TextStyle(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _whisperRunning ? null : _runWhisper,
                                icon: _whisperRunning
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.graphic_eq, size: 18),
                                label: Text(_whisperRunning
                                    ? 'Whisper çalışıyor…'
                                    : 'Whisper ile çevir'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.onSurface,
                                  side: const BorderSide(
                                      color: AppColors.onSurfaceMuted),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            if ((_whisperText ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.correctAnswer
                                          .withValues(alpha: 0.5)),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text('Whisper sonucu',
                                              style: TextStyle(
                                                  color:
                                                      AppColors.correctAnswer,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)),
                                        ),
                                        TextButton(
                                          onPressed: _pinyinBusy
                                              ? null
                                              : _applyWhisper,
                                          style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8),
                                              minimumSize: const Size(0, 28)),
                                          child: Text(
                                              _pinyinBusy
                                                  ? 'Uygulanıyor…'
                                                  : "Cümle'ye al",
                                              style:
                                                  const TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                    Text(_whisperText!,
                                        style: const TextStyle(
                                            color: AppColors.onSurface,
                                            fontSize: 15)),
                                    const SizedBox(height: 4),
                                    _miniBtn(
                                      _trWhisperBusy
                                          ? 'Çevriliyor…'
                                          : 'Türkçesi',
                                      Icons.translate,
                                      _trWhisperBusy ? null : _translateWhisper,
                                    ),
                                    if ((_whisperTranslation ?? '').isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                            'TR: ${_whisperTranslation!}',
                                            style: const TextStyle(
                                                color: AppColors.onSurfaceMuted,
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic)),
                                      ),
                                  ],
                                ),
                              ),
                            ] else
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Lokal worker çalışırken bu klibin sesini '
                                  'Whisper ile çevirir.',
                                  style: TextStyle(
                                      color: AppColors.onSurfaceMuted,
                                      fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _segmenting ? null : _segmentIntoWords,
                      icon: _segmenting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_fix_high, size: 18),
                      label: Text(_segmenting
                          ? 'Bölünüyor…'
                          : 'Cümleyi kelimelere ayır'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _WordTagEditor(
                    words: _targetWords,
                    service: widget.service,
                    onChanged: (words) => setState(() {
                      _targetWords = words;
                      _confirmedWords = null; // reset confirmation on change
                    }),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_targetWords.isEmpty || _pinyinBusy)
                          ? null
                          : _onConfirmWords,
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Kelimeleri Onayla'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _confirmedWords != null
                            ? AppColors.correctAnswer
                            : AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (_confirmedWords != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '✓ Onaylı: ${_confirmedWords!.join(' · ')}',
                        style: const TextStyle(
                            color: AppColors.correctAnswer, fontSize: 11),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Quiz',
                          style: TextStyle(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(width: 12),
                      _quizLangTab('TR', 'tr'),
                      const SizedBox(width: 6),
                      _quizLangTab('EN', 'en'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _generating ? null : _generateQuiz,
                      icon: _generating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(_generating
                          ? 'Üretiliyor…'
                          : 'Gemini ile şık üret (${_selectedQuizLang.toUpperCase()})'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_selectedQuizLang == 'tr') ...[
                    _editField(_correctCtrl, 'Doğru cevap (TR)'),
                    _editField(_wrongCtrl, 'Yanlış cevap — tuzak (TR)'),
                  ] else ...[
                    _editField(_correctCtrlEn, 'Correct answer (EN)'),
                    _editField(_wrongCtrlEn, 'Wrong answer — distractor (EN)'),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => _save(),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12)),
                          child: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Text('Kaydet'),
                        ),
                      ),
                      // Approve in one step so the edit reaches the home feed
                      // (only is_active=true shows). Hidden for already-active.
                      if (status != 'active') ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : () => _save(approve: true),
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.correctAnswer,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12)),
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Kaydet ve Onayla'),
                          ),
                        ),
                      ],
                    ],
                  ),
                      ],
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

  String _lifeLabel(String code) => LifeCategory.labelFor(code, isTr: true);

  String _lengthBucket() {
    final s = _targetWords.isNotEmpty
        ? _targetWords.join('')
        : _transcriptionCtrl.text;
    final n = RegExp(r'[一-鿿]').allMatches(s).length;
    if (n <= 5) return '1-5字';
    if (n <= 10) return '6-10字';
    if (n <= 15) return '11-15字';
    if (n <= 20) return '16-20字';
    return '21字+';
  }

  // A labelled multi-select: tapping opens a translucent menu downward; picking
  // an item adds it (already-chosen items are filtered out). Removal is via the
  // tag chips shown below.
  Widget _multiDropdown<T>({
    required String label,
    required List<({T value, String text})> options,
    required Set<T> chosen,
    required ValueChanged<T> onAdd,
  }) {
    final available = options.where((o) => !chosen.contains(o.value)).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        PopupMenuButton<T>(
          enabled: available.isNotEmpty,
          onSelected: onAdd,
          color: AppColors.surfaceVariant.withValues(alpha: 0.92),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          itemBuilder: (_) => [
            for (final o in available)
              PopupMenuItem<T>(
                value: o.value,
                height: 38,
                child: Text(o.text,
                    style: const TextStyle(
                        color: AppColors.onSurface, fontSize: 12)),
              ),
          ],
          child: Container(
            width: 132,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.onSurfaceMuted.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text('Ekle…',
                      style: TextStyle(
                          color: AppColors.onSurfaceMuted, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
                Icon(Icons.keyboard_arrow_down,
                    color: AppColors.onSurfaceMuted, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _readonlyFilter(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.onSurfaceMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          width: 132,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppColors.onSurfaceMuted.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(value,
                    style: const TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.lock_outline,
                  color: AppColors.onSurfaceMuted, size: 13),
            ],
          ),
        ),
      ],
    );
  }

  // Uniform removable tag chip (no per-level colours — those were confusing).
  Widget _tagChip(String text, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _quizLangTab(String label, String lang) {
    final selected = _selectedQuizLang == lang;
    return GestureDetector(
      onTap: () => setState(() => _selectedQuizLang = lang),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.onSurfaceMuted.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.onSurfaceMuted,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _miniBtn(String label, IconData icon, VoidCallback? onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 13),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _editField(TextEditingController ctrl, String label,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
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

// Drag payload: which line + index a chip came from.
class _WordRef {
  final int line;
  final int index;
  const _WordRef(this.line, this.index);
}

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
  Set<String> _inDict = {}; // words that exist in the dictionary → green

  // Local editing model: per-sentence word groups. Kept locally so an
  // explicitly added (still empty) line survives our own onChanged round-trips;
  // re-synced from widget.words only on an EXTERNAL change (e.g. re-segment).
  late List<List<String>> _groups;

  @override
  void initState() {
    super.initState();
    _groups = _split(widget.words);
    _refreshDict();
  }

  @override
  void didUpdateWidget(_WordTagEditor old) {
    super.didUpdateWidget(old);
    if (!_sameList(widget.words, _flatten())) _groups = _split(widget.words);
    final a = old.words.toSet();
    final b = widget.words.toSet();
    if (a.length != b.length || !a.containsAll(b)) _refreshDict();
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _refreshDict() async {
    final res = await widget.service.wordsInDictionary(widget.words);
    if (mounted) setState(() => _inDict = res);
  }

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

  // Split the flat word list into per-sentence groups on the '\n' sentinel.
  static List<List<String>> _split(List<String> words) {
    final groups = <List<String>>[];
    var cur = <String>[];
    for (final w in words) {
      if (w == '\n') {
        groups.add(cur);
        cur = [];
      } else {
        cur.add(w);
      }
    }
    groups.add(cur);
    final nonEmpty = groups.where((g) => g.isNotEmpty).toList();
    return nonEmpty.isEmpty ? [<String>[]] : nonEmpty;
  }

  // Flatten the local groups back to the flat list with '\n' sentinels (empty
  // lines are dropped here — they exist only as a drop target until filled).
  List<String> _flatten() {
    final out = <String>[];
    for (final g in _groups) {
      if (g.isEmpty) continue;
      if (out.isNotEmpty) out.add('\n');
      out.addAll(g);
    }
    return out;
  }

  void _commit() {
    widget.onChanged(_flatten());
    setState(() {});
  }

  void _addLine() => setState(() => _groups.add(<String>[]));

  void _addWord(String word) {
    // Duplicates are allowed — a sentence can repeat the same word (e.g. 好…好).
    _groups.last.add(word);
    _commit();
    _ctrl.clear();
    setState(() => _suggestions = []);
  }

  void _removeAt(int line, int index) {
    _groups[line].removeAt(index);
    if (_groups[line].isEmpty && _groups.length > 1) _groups.removeAt(line);
    _commit();
  }

  // Move a word to [dstLine] at [dstIndex] (drag-drop). dstIndex == line length
  // means "append to the end of that line".
  void _moveWord(int srcLine, int srcIndex, int dstLine, int dstIndex) {
    if (srcLine == dstLine && (srcIndex == dstIndex || srcIndex == dstIndex - 1)) {
      return; // dropped onto itself / its own slot — no-op
    }
    final word = _groups[srcLine].removeAt(srcIndex);
    var di = dstIndex;
    if (srcLine == dstLine && srcIndex < di) di -= 1;
    di = di.clamp(0, _groups[dstLine].length);
    _groups[dstLine].insert(di, word);
    if (_groups[srcLine].isEmpty && _groups.length > 1) {
      _groups.removeAt(srcLine);
    }
    _commit();
  }

  // One sentence line: a drop target (append) holding a Wrap of draggable chips.
  Widget _buildLine(int li, bool multi) {
    final words = _groups[li];
    return DragTarget<_WordRef>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) =>
          _moveWord(d.data.line, d.data.index, li, words.length),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: hovering
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hovering
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : AppColors.onSurfaceMuted.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              if (multi)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('${li + 1}.',
                      style: const TextStyle(
                          color: AppColors.onSurfaceMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              Expanded(
                child: words.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('Buraya kelime sürükle…',
                            style: TextStyle(
                                color: AppColors.onSurfaceMuted,
                                fontSize: 12,
                                fontStyle: FontStyle.italic)),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (int k = 0; k < words.length; k++)
                            _buildChip(li, k),
                        ],
                      ),
              ),
              if (multi && words.isEmpty)
                GestureDetector(
                  onTap: () => setState(() => _groups.removeAt(li)),
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.onSurfaceMuted),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _chipVisual(String word, Color c, {VoidCallback? onRemove}) {
    return Container(
      padding: EdgeInsets.only(left: 12, right: onRemove == null ? 12 : 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(word,
              style: TextStyle(
                  color: c, fontSize: 15, fontWeight: FontWeight.w600)),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 16, color: c),
            ),
          ],
        ],
      ),
    );
  }

  // A draggable word chip; also a drop target that inserts a dropped word
  // BEFORE it (so order within / across lines is controllable by drag).
  Widget _buildChip(int li, int k) {
    final word = _groups[li][k];
    final c =
        _inDict.contains(word) ? AppColors.correctAnswer : AppColors.wrongAnswer;
    return DragTarget<_WordRef>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => _moveWord(d.data.line, d.data.index, li, k),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Container(
          decoration: hovering
              ? const BoxDecoration(
                  border: Border(
                      left: BorderSide(color: AppColors.primary, width: 2)))
              : null,
          padding: EdgeInsets.only(left: hovering ? 3 : 0),
          child: Draggable<_WordRef>(
            data: _WordRef(li, k),
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(opacity: 0.9, child: _chipVisual(word, c)),
            ),
            childWhenDragging:
                Opacity(opacity: 0.3, child: _chipVisual(word, c)),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: _chipVisual(word, c, onRemove: () => _removeAt(li, k)),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
            'Kelimeler — kelimeyi sürükleyip başka satıra taşı, × ile sil',
            style: TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        const SizedBox(height: 6),
        if (widget.words.isNotEmpty) ...[
          for (int li = 0; li < _groups.length; li++)
            _buildLine(li, _groups.length > 1),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _addLine,
              icon: const Icon(Icons.subdirectory_arrow_left, size: 16),
              label: const Text('+ Satır ekle'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
                minimumSize: Size.zero,
              ),
            ),
          ),
        ],
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
          onChanged: (q) {
            setState(() {}); // refresh the "add anyway" row live
            _onSearch(q);
          },
        ),
        if (_ctrl.text.trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                ..._suggestions.map((s) {
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
                    // Always tappable — duplicates allowed. A check hints it's
                    // already in the list, but you can still add it again.
                    trailing: Icon(already ? Icons.add_circle : Icons.add,
                        color: AppColors.primary, size: 16),
                    onTap: () => _addWord(word),
                  );
                }),
                // Add the typed text even when it isn't in the dictionary.
                if (!_suggestions
                    .any((s) => s['simplified'] == _ctrl.text.trim()))
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.add_circle_outline,
                        color: AppColors.primary, size: 20),
                    title: Text('"${_ctrl.text.trim()}" ekle',
                        style: const TextStyle(
                            color: AppColors.onSurface, fontSize: 13)),
                    subtitle: const Text('Sözlükte olmasa da ekle',
                        style: TextStyle(
                            color: AppColors.onSurfaceMuted, fontSize: 11)),
                    onTap: () => _addWord(_ctrl.text.trim()),
                  ),
              ],
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
  Timer? _jobPollTimer;

  String _asrJobYoutubeId = '';
  List<int>? _asrJobFilter;

  final Set<int> _hskFilter = {};

  // ── Countdown ETA + live import stream ────────────────────────────────────
  DateTime? _processingStart;
  DateTime? _lastProgressAt; // last time new segments appeared (stall detection)
  Timer? _elapsedTimer;
  int _partialCount = 0;
  double _durationSec = 0; // total audio length reported by the pipeline
  double _lastPos = 0;     // how far (sec) ASR has progressed into the audio
  double? _etaTotalSec;    // estimated total processing time (re-anchored per poll)
  List<Map<String, dynamic>> _liveVideos = [];
  Timer? _liveVideoTimer;

  void _toggleHskFilter(int lvl) {
    setState(() {
      if (_hskFilter.contains(lvl)) {
        _hskFilter.remove(lvl);
      } else {
        _hskFilter.add(lvl);
      }
    });
  }

  @override
  void dispose() {
    _jobPollTimer?.cancel();
    _elapsedTimer?.cancel();
    _liveVideoTimer?.cancel();
    _urlCtrl.dispose();
    super.dispose();
  }

  int get _elapsedSec => _processingStart == null
      ? 0
      : DateTime.now().difference(_processingStart!).inSeconds;

  // Countdown label "MM:SS" once an estimate exists, else null (→ show "İşleniyor…").
  String? get _countdownLabel {
    if (_etaTotalSec == null || _processingStart == null) return null;
    var rem = (_etaTotalSec! - _elapsedSec).round();
    if (rem < 0) rem = 0;
    final m = (rem ~/ 60).toString().padLeft(2, '0');
    final s = (rem % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Re-anchor the estimate from the latest reported audio position. As ASR
  // advances proportionally to elapsed time the estimate converges; between
  // polls the 1s ticker counts the frozen estimate down.
  void _recomputeEta() {
    if (_durationSec <= 0) return;
    final elapsed = _elapsedSec.toDouble();
    if (_lastPos > 0 && elapsed > 1) {
      final frac = (_lastPos / _durationSec).clamp(0.02, 1.0);
      _etaTotalSec = elapsed / frac;
    } else {
      _etaTotalSec ??= _durationSec; // rough first guess before any segment
    }
  }

  void _startTimers(String youtubeId) {
    _processingStart = DateTime.now();
    _lastProgressAt = DateTime.now();
    _partialCount = 0;
    _durationSec = 0;
    _lastPos = 0;
    _etaTotalSec = null;
    _liveVideos = [];
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _liveVideoTimer?.cancel();
    _liveVideoTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || youtubeId.isEmpty) return;
      try {
        final vids = await _service.listVideosByYoutubeId(youtubeId);
        if (mounted) setState(() => _liveVideos = vids);
      } catch (_) {}
    });
  }

  void _stopTimers() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _liveVideoTimer?.cancel();
    _liveVideoTimer = null;
    _processingStart = null;
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

  static bool _isNoCaptionsError(String msg) {
    return msg.contains('altyazı bulunamadı') ||
        msg.contains("track'i bulunamadı") ||
        msg.contains('Çince altyazı');
  }

  Future<void> _processSmartImport() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    final filter = _hskFilter.isEmpty ? null : (_hskFilter.toList()..sort());
    final videoId = _extractYtId(url);

    setState(() { _processing = true; _resultMsg = null; _liveVideos = []; });
    _startTimers(videoId);

    // Step 1: Try subtitle-based extraction via edge function
    try {
      final result = await _service.processYoutubeVideo(
        url,
        active: false,
        hskFilter: filter,
      );
      final written = result['segmentsWritten'] as int? ?? 0;
      final deleted = await _service.deleteNonMatchingPendingVideos(videoId, filter);
      final kept = written - deleted;
      final vids = await _service.listVideosByYoutubeId(videoId);
      if (mounted) {
        _stopTimers();
        setState(() {
          _processing = false;
          _resultSuccess = true;
          _resultMsg = '✓ $kept klip içe aktarıldı.'
              '${deleted > 0 ? ' ($deleted segment sözlük/filtre dışı otomatik silindi.)' : ''}'
              ' Sağdan onaylayın.';
          _liveVideos = vids;
        });
        widget.onVideosChanged();
      }
      return;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (!_isNoCaptionsError(msg)) {
        _stopTimers();
        if (mounted) {
          setState(() {
            _processing = false;
            _resultSuccess = false;
            _resultMsg = msg;
          });
        }
        return;
      }
      // No captions found → silently fall through to ASR
    }

    // Step 2: Auto-fallback to ASR (transparent to user)
    _asrJobYoutubeId = videoId;
    _asrJobFilter = filter;
    try {
      final jobId = await _service.createYoutubeAsrJob(
        url,
        active: false,
        hskFilter: filter,
      );
      if (!mounted) return;
      setState(() {
        _resultSuccess = true;
        _resultMsg = '⏳ Ses tanıma başlatıldı (altyazı bulunamadı). Whisper işleniyor…';
      });
      _startJobPolling(jobId);
    } catch (e) {
      _stopTimers();
      if (mounted) {
        setState(() {
          _processing = false;
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

      // Stall timeout: abort only if NO new segment has appeared for 10 min.
      // This supports hour-long videos (segments stream in for many minutes)
      // while still catching a dead/idle worker. A generous 3-hour absolute cap
      // guards against a truly stuck job.
      final lastTick = _lastProgressAt ?? _processingStart;
      final stalled = lastTick != null &&
          DateTime.now().difference(lastTick) > const Duration(minutes: 10);
      final tooLong = _processingStart != null &&
          DateTime.now().difference(_processingStart!) >
              const Duration(hours: 3);
      if (stalled || tooLong) {
        _jobPollTimer?.cancel();
        _stopTimers();
        setState(() {
          _processing = false;
          _resultSuccess = false;
          _resultMsg = stalled
              ? '10 dk yeni segment gelmedi — işlem durdu. Pipeline sunucusu (dev_server.py) çalışıyor mu?'
              : 'İşlem 3 saati aştı, durduruldu.';
        });
        return;
      }

      try {
        final job = await _service.getJob(jobId);
        if (!mounted) return;
        final status = job['status'] as String? ?? '';

        // Live partial-progress update + ETA basis (duration / audio position)
        final res = job['result'] as Map?;
        final dur = (res?['durationSec'] as num?)?.toDouble() ?? 0;
        final pos = (res?['lastPos'] as num?)?.toDouble() ?? 0;
        if (dur > 0) _durationSec = dur;
        if (pos > 0) _lastPos = pos;
        _recomputeEta();
        final partial = res?['segmentsWritten'] as int? ?? 0;
        if (partial > 0 && partial != _partialCount) {
          _partialCount = partial;
          _lastProgressAt = DateTime.now(); // reset stall timer on real progress
          widget.onVideosChanged();
        }

        if (status == 'done') {
          final written =
              (job['result'] as Map?)?['segmentsWritten'] as int? ?? 0;
          final deleted = await _service.deleteNonMatchingPendingVideos(
            _asrJobYoutubeId,
            _asrJobFilter,
          );
          final kept = written - deleted;
          if (!mounted) return;
          final vids = await _service.listVideosByYoutubeId(_asrJobYoutubeId);
          _jobPollTimer?.cancel();
          _stopTimers();
          setState(() {
            _processing = false;
            _resultSuccess = true;
            _resultMsg = '✓ $kept klip içe aktarıldı.'
                '${deleted > 0 ? ' ($deleted segment sözlük/filtre dışı silindi.)' : ''}'
                ' Sağdan onaylayın.';
            _liveVideos = vids;
          });
          widget.onVideosChanged();
        } else if (status == 'error') {
          _jobPollTimer?.cancel();
          _stopTimers();
          setState(() {
            _processing = false;
            _resultSuccess = false;
            _resultMsg = job['error_text'] as String? ?? 'İşlem başarısız.';
          });
        }
      } catch (_) {}
    });
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
                'Bulut: önce altyazı aranır, bulunamazsa ses tanıma otomatik devreye girer',
                style: TextStyle(color: AppColors.correctAnswer, fontSize: 12),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          TextField(
            controller: _urlCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'https://www.youtube.com/watch?v=...',
              hintStyle: const TextStyle(color: AppColors.onSurfaceMuted),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.link,
                  color: AppColors.onSurfaceMuted, size: 18),
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hskFilter.isNotEmpty
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.onSurfaceMuted.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 14,
                      color: _hskFilter.isNotEmpty
                          ? AppColors.primary
                          : AppColors.onSurfaceMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ön Filtre — Hangi HSK seviyelerini içe aktarayım?',
                      style: TextStyle(
                        color: _hskFilter.isNotEmpty
                            ? AppColors.primary
                            : AppColors.onSurfaceMuted,
                        fontSize: 12,
                        fontWeight: _hskFilter.isNotEmpty
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (_hskFilter.isNotEmpty) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _hskFilter.clear()),
                        child: const Text(
                          'Tümü',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _hskFilter.isEmpty
                      ? 'Boş = tüm seviyeleri aktar (sözlükte eşleşmeyen segmentler otomatik atlanır)'
                      : 'Sadece HSK ${(_hskFilter.toList()..sort()).join(" + ")} segmentleri aktarılır',
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (int i = 1; i <= 6; i++)
                      _HskFilterChip(
                        level: i,
                        selected: _hskFilter.contains(i),
                        onTap: () => _toggleHskFilter(i),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_urlCtrl.text.trim().isNotEmpty && !_processing)
                  ? _processSmartImport
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
                  : _hskFilter.isEmpty
                      ? 'Otomatik Parçala — Tüm Seviyeleri İçe Aktar'
                      : 'Otomatik Parçala — Yalnızca HSK ${(_hskFilter.toList()..sort()).join("+")}'),
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
            if (_processing && _processingStart != null) ...[
              const SizedBox(height: 6),
              Builder(builder: (_) {
                final cd = _countdownLabel;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(cd != null ? Icons.hourglass_bottom : Icons.timer_outlined,
                        size: 13, color: AppColors.onSurfaceMuted),
                    const SizedBox(width: 4),
                    Text(
                      cd != null ? '~$cd kaldı (tahmini)' : 'İşleniyor…',
                      style: const TextStyle(
                          color: AppColors.onSurfaceMuted, fontSize: 12),
                    ),
                    if (_partialCount > 0) ...[
                      const Text(' · ',
                          style: TextStyle(
                              color: AppColors.onSurfaceMuted, fontSize: 12)),
                      Text('$_partialCount klip bulundu',
                          style: const TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ],
                );
              }),
            ],
          ],

          if (_liveVideos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.playlist_add_check,
                  size: 15, color: AppColors.correctAnswer),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_liveVideos.length} klip eklendi — "Onay Bekleyen" sekmesinden onaylayın',
                  style: const TextStyle(
                      color: AppColors.onSurfaceMuted, fontSize: 12),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            ..._liveVideos.map((v) => _LiveImportCard(data: v)),
          ],
        ],
      ),
    );
  }
}

// ── Live Import Card (shown below button during/after import) ─────────────────

class _LiveImportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LiveImportCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final ytId = data['youtube_id'] as String? ?? '';
    final start = (data['start_time'] as num?)?.toInt() ?? 0;
    final end = (data['end_time'] as num?)?.toInt() ?? 0;
    final hsk = (data['hsk_level'] as int?) ?? 1;
    final text = data['transcription'] as String? ?? '';
    final pinyin = data['pinyin'] as String? ?? '';
    final status = data['status'] as String? ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: status == 'active'
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.onSurfaceMuted.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Thumbnail
          if (ytId.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(10)),
              child: Image.network(
                'https://img.youtube.com/vi/$ytId/mqdefault.jpg',
                width: 80,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 54,
                    color: AppColors.surface,
                    child: const Icon(Icons.play_circle_outline,
                        color: AppColors.onSurfaceMuted, size: 24)),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.forHskLevel(hsk),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('HSK $hsk',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      Text('${start}s–${end}s',
                          style: const TextStyle(
                              color: AppColors.onSurfaceMuted, fontSize: 10)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: status == 'active'
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.onSurfaceMuted.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status == 'active'
                              ? 'Aktif'
                              : status == 'pending'
                                  ? 'Onay bekliyor'
                                  : status,
                          style: TextStyle(
                            fontSize: 9,
                            color: status == 'active'
                                ? AppColors.primary
                                : AppColors.onSurfaceMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(text,
                      style: const TextStyle(
                          color: AppColors.onSurface, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (pinyin.isNotEmpty)
                    Text(pinyin,
                        style: const TextStyle(
                            color: AppColors.onSurfaceMuted, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ],
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

  final _videoPathCtrl = TextEditingController();
  final _subPathCtrl = TextEditingController();
  final Set<int> _hskFilter = {};

  bool _processing = false;
  String? _resultMsg;
  bool _resultSuccess = false;
  int _partial = 0;
  Timer? _pollTimer;
  DateTime? _start;
  DateTime? _lastProgressAt;

  @override
  void dispose() {
    _videoPathCtrl.dispose();
    _subPathCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _process() async {
    final path = _videoPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _processing = true;
      _resultMsg = null;
      _partial = 0;
      _start = DateTime.now();
      _lastProgressAt = DateTime.now();
    });
    try {
      final jobId = await _service.createMovieJob(
        path,
        subPath: _subPathCtrl.text.trim().isEmpty ? null : _subPathCtrl.text.trim(),
        active: false,
        hskFilter: _hskFilter.isEmpty ? null : (_hskFilter.toList()..sort()),
      );
      if (!mounted) return;
      setState(() => _resultMsg =
          '⏳ Yerel işçi işliyor… (klipler hazırlandıkça Onay Bekleyen\'e düşer)');
      _startPolling(jobId);
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

  void _startPolling(String jobId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      final lastTick = _lastProgressAt ?? _start;
      if (lastTick != null &&
          DateTime.now().difference(lastTick) > const Duration(minutes: 10)) {
        _pollTimer?.cancel();
        setState(() {
          _processing = false;
          _resultSuccess = false;
          _resultMsg =
              '10 dk yeni klip gelmedi — işçi durdu. dev_server.py çalışıyor mu, '
              'dosya yolu doğru mu?';
        });
        return;
      }
      try {
        final job = await _service.getJob(jobId);
        if (!mounted) return;
        final status = job['status'] as String? ?? '';
        final partial = (job['result'] as Map?)?['segmentsWritten'] as int? ?? 0;
        if (partial > 0 && partial != _partial) {
          setState(() => _partial = partial);
          _lastProgressAt = DateTime.now();
          widget.onVideosChanged();
        }
        if (status == 'done') {
          _pollTimer?.cancel();
          final n = (job['result'] as Map?)?['segmentsWritten'] as int? ?? _partial;
          setState(() {
            _processing = false;
            _resultSuccess = true;
            _resultMsg = '✓ $n klip içe aktarıldı. Sağdan onaylayın.';
          });
          widget.onVideosChanged();
        } else if (status == 'error') {
          _pollTimer?.cancel();
          setState(() {
            _processing = false;
            _resultSuccess = false;
            _resultMsg = job['error_text'] as String? ?? 'İşlem başarısız.';
          });
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Film / Yerel Dosya → Supabase',
              style: TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 4),
          const Text(
            'Yerel pipeline (dev_server.py) açıkken çalışır. Dosya yolu, işçinin '
            'çalıştığı bilgisayardaki yoldur. Her diyalog ayrı klip olarak kesilip '
            'Supabase Storage\'a yüklenir; kullanıcılar canlı sitede oynatır. '
            'Klipler hazırlandıkça Onay Bekleyen sekmesine düşer.',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          _pathField(_videoPathCtrl, 'Film dosyası yolu (ör. D:\\Movies\\film.mkv)'),
          const SizedBox(height: 8),
          _pathField(_subPathCtrl, 'Altyazı yolu — opsiyonel (.srt/.vtt/.ass)'),
          const SizedBox(height: 12),
          const Text('Ön Filtre (opsiyonel) — boş = tüm seviyeler',
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 1; i <= 6; i++)
                FilterChip(
                  label: Text('HSK $i', style: const TextStyle(fontSize: 11)),
                  selected: _hskFilter.contains(i),
                  onSelected: (_) => setState(() => _hskFilter.contains(i)
                      ? _hskFilter.remove(i)
                      : _hskFilter.add(i)),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundColor: AppColors.surface,
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _processing ? null : _process,
              icon: _processing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.movie_filter_outlined, size: 18),
              label: Text(_processing
                  ? (_partial > 0
                      ? '$_partial klip… (devam ediyor)'
                      : 'İşçi başlatıldı…')
                  : 'Parçala ve İçe Aktar'),
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

  Widget _pathField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppColors.onSurface, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

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

// ── HSK filter chip (admin import pre-filter) ─────────────────────────────────

class _HskFilterChip extends StatelessWidget {
  final int level;
  final bool selected;
  final VoidCallback onTap;

  const _HskFilterChip({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forHskLevel(level);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.35),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.check, size: 11, color: color),
              ),
            Text(
              'HSK $level',
              style: TextStyle(
                color: selected ? color : color.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Users Panel ───────────────────────────────────────────────────────────────

class _UsersPanel extends StatefulWidget {
  const _UsersPanel();

  @override
  State<_UsersPanel> createState() => _UsersPanelState();
}

class _UsersPanelState extends State<_UsersPanel> {
  static final _db = Supabase.instance.client;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = false;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _db
          .from('users')
          .select('id, display_name, email, hsk_level, is_premium, ai_credits, created_at')
          .order('created_at', ascending: false)
          .limit(500);
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(rows as List);
          _loading = false;
        });
        _applyFilter();
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_users)
          : _users.where((u) {
              final name = (u['display_name'] as String? ?? '').toLowerCase();
              final email = (u['email'] as String? ?? '').toLowerCase();
              return name.contains(q) || email.contains(q);
            }).toList();
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _togglePremium(Map<String, dynamic> user) async {
    final id = user['id'] as String;
    final current = user['is_premium'] as bool? ?? false;
    try {
      await _db.from('users').update({'is_premium': !current}).eq('id', id);
      _snack(!current ? '✓ Premium aktif edildi' : '✓ Premium kaldırıldı');
      _load();
    } catch (e) {
      _snack('Hata: $e');
    }
  }

  Future<void> _grantCredits(Map<String, dynamic> user) async {
    final id = user['id'] as String;
    final current = user['ai_credits'] as int? ?? 0;
    final ctrl = TextEditingController(text: current.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: Text(
          'Kredi Düzenle — ${user['display_name'] ?? user['email']}',
          style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
        ),
        content: SizedBox(
          width: 280,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              labelText: 'AI Kredi (mevcut: $current)',
              labelStyle: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary)),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final newVal = int.tryParse(ctrl.text.trim());
    if (newVal == null) return;
    try {
      await _db.from('users').update({'ai_credits': newVal}).eq('id', id);
      _snack('✓ Kredi güncellendi → $newVal');
      _load();
    } catch (e) {
      _snack('Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final premiumCount = _users.where((u) => u['is_premium'] == true).length;

    return Column(
      children: [
        // ── Stats + search bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: AppColors.surfaceVariant,
          child: Row(
            children: [
              _StatBadge(label: 'Toplam', value: '${_users.length}'),
              const SizedBox(width: 24),
              _StatBadge(
                  label: 'Premium',
                  value: '$premiumCount',
                  color: AppColors.premiumGold),
              const SizedBox(width: 24),
              _StatBadge(
                  label: 'Ücretsiz',
                  value: '${_users.length - premiumCount}'),
              const Spacer(),
              SizedBox(
                width: 220,
                height: 34,
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: AppColors.onSurface, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'İsim veya e-posta ara…',
                    hintStyle: const TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.surface,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    prefixIcon: const Icon(Icons.search,
                        size: 16, color: AppColors.onSurfaceMuted),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.onSurfaceMuted),
                onPressed: _load,
                tooltip: 'Yenile',
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.surface),
        // ── User list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text(_error!,
                          style: const TextStyle(color: AppColors.wrongAnswer),
                          textAlign: TextAlign.center))
                  : _filtered.isEmpty
                      ? const Center(
                          child: Text('Kullanıcı bulunamadı',
                              style: TextStyle(
                                  color: AppColors.onSurfaceMuted)))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, color: AppColors.surfaceVariant),
                          itemBuilder: (_, i) =>
                              _UserRow(
                                user: _filtered[i],
                                onTogglePremium: () =>
                                    _togglePremium(_filtered[i]),
                                onGrantCredits: () =>
                                    _grantCredits(_filtered[i]),
                              ),
                        ),
        ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTogglePremium;
  final VoidCallback onGrantCredits;

  const _UserRow({
    required this.user,
    required this.onTogglePremium,
    required this.onGrantCredits,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['display_name'] as String? ?? '—';
    final email = user['email'] as String? ?? '';
    final hsk = user['hsk_level'] as int? ?? 1;
    final isPremium = user['is_premium'] as bool? ?? false;
    final credits = user['ai_credits'] as int? ?? 0;
    final raw = user['created_at'] as String? ?? '';
    final createdAt = raw.length >= 10 ? raw.substring(0, 10) : raw;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: isPremium
            ? AppColors.premiumGold.withValues(alpha: 0.2)
            : AppColors.onSurfaceMuted.withValues(alpha: 0.15),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: isPremium ? AppColors.premiumGold : AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    color: AppColors.onSurface, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.forHskLevel(hsk).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('HSK $hsk',
                style: TextStyle(
                    color: AppColors.forHskLevel(hsk),
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      subtitle: Text(
        '$email · $createdAt',
        style: const TextStyle(
            color: AppColors.onSurfaceMuted, fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Credits badge + edit
          GestureDetector(
            onTap: onGrantCredits,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt,
                      size: 13, color: AppColors.primary),
                  const SizedBox(width: 2),
                  Text('$credits',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Premium toggle chip
          GestureDetector(
            onTap: onTogglePremium,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isPremium
                    ? AppColors.premiumGold.withValues(alpha: 0.15)
                    : AppColors.onSurfaceMuted.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isPremium
                      ? AppColors.premiumGold.withValues(alpha: 0.5)
                      : AppColors.onSurfaceMuted.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                isPremium ? '★ Premium' : 'Ücretsiz',
                style: TextStyle(
                  color: isPremium
                      ? AppColors.premiumGold
                      : AppColors.onSurfaceMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Social Panel ─────────────────────────────────────────────────────────────

class _SocialPanel extends StatefulWidget {
  const _SocialPanel();

  @override
  State<_SocialPanel> createState() => _SocialPanelState();
}

class _SocialPanelState extends State<_SocialPanel> {
  static final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = false;
  String? _error;
  int _totalUsers = 0;
  int _onlineUsers = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final posts = await _db
          .from('posts')
          .select('id, author_id, content, post_type, timestamp, likes')
          .order('timestamp', ascending: false)
          .limit(100);

      final userCount = await _db
          .from('users')
          .select('id, is_online')
          .limit(1000);

      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(posts as List);
          final users = List<Map<String, dynamic>>.from(userCount as List);
          _totalUsers = users.length;
          _onlineUsers = users.where((u) => u['is_online'] == true).length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _deletePost(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant,
        title: const Text('Postu sil?',
            style: TextStyle(color: AppColors.onSurface)),
        content: const Text('Bu işlem geri alınamaz.',
            style: TextStyle(color: AppColors.onSurfaceMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil',
                  style: TextStyle(color: AppColors.wrongAnswer))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.from('posts').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Post silindi')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: AppColors.surfaceVariant,
          child: Row(
            children: [
              _StatBadge(label: 'Toplam Kullanıcı', value: '$_totalUsers'),
              const SizedBox(width: 24),
              _StatBadge(label: 'Çevrimiçi', value: '$_onlineUsers', color: AppColors.correctAnswer),
              const SizedBox(width: 24),
              _StatBadge(label: 'Post (son 100)', value: '${_posts.length}'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.onSurfaceMuted),
                onPressed: _load,
                tooltip: 'Yenile',
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.surfaceVariant),
        // ── Post list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.wrongAnswer)))
                  : _posts.isEmpty
                      ? const Center(
                          child: Text('Post yok', style: TextStyle(color: AppColors.onSurfaceMuted)))
                      : ListView.separated(
                          itemCount: _posts.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: AppColors.surfaceVariant),
                          itemBuilder: (_, i) {
                            final p = _posts[i];
                            final likes = (p['likes'] as List?)?.length ?? 0;
                            final ts = p['timestamp'] as String? ?? '';
                            final date = ts.isNotEmpty
                                ? ts.substring(0, 10)
                                : '';
                            return ListTile(
                              dense: true,
                              leading: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p['post_type'] as String? ?? 'text',
                                  style: const TextStyle(
                                      color: AppColors.primary, fontSize: 10),
                                ),
                              ),
                              title: Text(
                                (p['content'] as String? ?? '').length > 80
                                    ? '${(p['content'] as String).substring(0, 80)}…'
                                    : (p['content'] as String? ?? ''),
                                style: const TextStyle(
                                    color: AppColors.onSurface, fontSize: 13),
                              ),
                              subtitle: Text(
                                '$date · ❤ $likes · ${(p['author_id'] as String).substring(0, 8)}…',
                                style: const TextStyle(
                                    color: AppColors.onSurfaceMuted, fontSize: 11),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.wrongAnswer, size: 18),
                                onPressed: () => _deletePost(p['id'] as String),
                                tooltip: 'Sil',
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

// ── Game Panel ────────────────────────────────────────────────────────────────

class _GamePanel extends StatefulWidget {
  const _GamePanel();

  @override
  State<_GamePanel> createState() => _GamePanelState();
}

class _GamePanelState extends State<_GamePanel>
    with SingleTickerProviderStateMixin {
  static final _db = Supabase.instance.client;
  late final TabController _tabs;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _leaderboard = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final requests = await _db
          .from('game_requests')
          .select('id, from_uid, to_uid, hsk_level, status, created_at')
          .order('created_at', ascending: false)
          .limit(100);

      final leaders = await _db
          .from('users')
          .select('display_name, hsk_level, stats')
          .order('stats->totalScore', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(requests as List);
          _leaderboard = List<Map<String, dynamic>>.from(leaders as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _statusColor(String s) => switch (s) {
    'pending' => Colors.orange,
    'accepted' => AppColors.correctAnswer,
    'declined' => AppColors.wrongAnswer,
    'expired' => Colors.grey,
    _ => AppColors.onSurfaceMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Tab bar + refresh
        Container(
          color: AppColors.surfaceVariant,
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'İstekler (${_requests.length})'),
                    const Tab(text: 'Liderboard'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.onSurfaceMuted),
                onPressed: _load,
                tooltip: 'Yenile',
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.surface),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text(_error!, style: const TextStyle(color: AppColors.wrongAnswer)))
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        // ── Game requests
                        _requests.isEmpty
                            ? const Center(
                                child: Text('İstek yok',
                                    style: TextStyle(color: AppColors.onSurfaceMuted)))
                            : ListView.separated(
                                itemCount: _requests.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1, color: AppColors.surfaceVariant),
                                itemBuilder: (_, i) {
                                  final r = _requests[i];
                                  final status = r['status'] as String? ?? '';
                                  final ts = (r['created_at'] as String? ?? '').substring(0, 10);
                                  return ListTile(
                                    dense: true,
                                    leading: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.forHskLevel(r['hsk_level'] as int? ?? 1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'HSK ${r['hsk_level']}',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 10),
                                      ),
                                    ),
                                    title: Text(
                                      '${(r['from_uid'] as String).substring(0, 8)} → ${(r['to_uid'] as String).substring(0, 8)}',
                                      style: const TextStyle(
                                          color: AppColors.onSurface, fontSize: 13),
                                    ),
                                    subtitle: Text(ts,
                                        style: const TextStyle(
                                            color: AppColors.onSurfaceMuted, fontSize: 11)),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                            color: _statusColor(status), fontSize: 11),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        // ── Leaderboard
                        _leaderboard.isEmpty
                            ? const Center(
                                child: Text('Henüz skor yok',
                                    style: TextStyle(color: AppColors.onSurfaceMuted)))
                            : ListView.builder(
                                itemCount: _leaderboard.length,
                                itemBuilder: (_, i) {
                                  final u = _leaderboard[i];
                                  final stats = u['stats'] as Map<String, dynamic>? ?? {};
                                  final score = stats['totalScore'] as int? ?? 0;
                                  final streak = stats['currentStreak'] as int? ?? 0;
                                  final name = u['display_name'] as String? ?? '—';
                                  final medals = ['🥇', '🥈', '🥉'];
                                  return ListTile(
                                    dense: true,
                                    leading: Text(
                                      i < 3 ? medals[i] : '${i + 1}.',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    title: Text(name,
                                        style: const TextStyle(
                                            color: AppColors.onSurface, fontSize: 13)),
                                    subtitle: Text(
                                      'HSK ${u['hsk_level']} · 🔥 $streak gün',
                                      style: const TextStyle(
                                          color: AppColors.onSurfaceMuted, fontSize: 11),
                                    ),
                                    trailing: Text(
                                      '$score puan',
                                      style: TextStyle(
                                        color: i == 0
                                            ? AppColors.premiumGold
                                            : AppColors.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
        ),
      ],
    );
  }
}

// ── Stat Badge (shared helper) ─────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatBadge({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 10)),
        Text(value,
            style: TextStyle(
              color: color ?? AppColors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
      ],
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
