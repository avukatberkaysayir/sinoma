import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/onboarding_provider.dart';

class HskRetestScreen extends ConsumerStatefulWidget {
  const HskRetestScreen({super.key});

  @override
  ConsumerState<HskRetestScreen> createState() => _HskRetestScreenState();
}

class _HskRetestScreenState extends ConsumerState<HskRetestScreen> {
  int _questionIndex = 0;
  final List<int?> _answers = List.filled(20, null);
  bool _done = false;
  int? _resultLevel;
  bool _saving = false;

  void _selectAnswer(int answerIndex) {
    if (_answers[_questionIndex] != null) return;
    _answers[_questionIndex] = answerIndex;
    final nextIndex = _questionIndex + 1;

    if (nextIndex >= kPlacementQuestions.length) {
      setState(() {
        _questionIndex = nextIndex;
        _done = true;
        _resultLevel = computeHskLevel(_answers);
      });
    } else {
      setState(() => _questionIndex = nextIndex);
    }
  }

  Future<void> _saveAndReturn() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .updateHskLevel(uid, _resultLevel!);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _ResultPage(level: _resultLevel!, saving: _saving, onSave: _saveAndReturn);

    final question = kPlacementQuestions[_questionIndex];
    final total = kPlacementQuestions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('HSK Testi  ${_questionIndex + 1} / $total'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _questionIndex / total,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Text(
              question.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 44,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            ...List.generate(
              question.choices.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  onPressed: () => _selectAnswer(i),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onSurface,
                    side: const BorderSide(color: AppColors.surfaceVariant),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.surfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    question.choices[i],
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultPage extends StatelessWidget {
  final int level;
  final bool saving;
  final VoidCallback onSave;

  const _ResultPage({
    required this.level,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forHskLevel(level);
    return Scaffold(
      appBar: AppBar(title: const Text('Sonuç')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HSK $level',
                style: TextStyle(
                  color: color,
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _levelLabel(level),
                style: const TextStyle(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  minimumSize: const Size(200, 48),
                ),
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Kaydet ve Geri Dön',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _levelLabel(int level) => switch (level) {
        1 => 'Başlangıç',
        2 => 'Temel',
        3 => 'Orta',
        4 => 'Orta-İleri',
        5 => 'İleri',
        6 => 'Uzman',
        _ => '',
      };
}
