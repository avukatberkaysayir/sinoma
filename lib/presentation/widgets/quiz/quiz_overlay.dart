import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/video_segment_model.dart';
import '../../providers/video_provider.dart';

class QuizOverlay extends ConsumerStatefulWidget {
  final QuizData quiz;
  final VoidCallback onAnswered;

  const QuizOverlay({
    super.key,
    required this.quiz,
    required this.onAnswered,
  });

  @override
  ConsumerState<QuizOverlay> createState() => _QuizOverlayState();
}

class _QuizOverlayState extends ConsumerState<QuizOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late List<_AnswerOption> _shuffledOptions;
  String? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _shuffledOptions = [
      _AnswerOption(text: widget.quiz.correctAnswer, isCorrect: true),
      _AnswerOption(text: widget.quiz.wrongAnswer, isCorrect: false),
    ]..shuffle();

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _handleAnswer(_AnswerOption option) {
    if (_selectedAnswer != null) return;
    setState(() => _selectedAnswer = option.text);

    final notifier = ref.read(videoPlaybackProvider.notifier);
    if (option.isCorrect) {
      notifier.recordCorrectAnswer();
    } else {
      notifier.recordWrongAnswer();
    }

    Future.delayed(const Duration(milliseconds: 800), widget.onAnswered);
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.quiz.question,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: _shuffledOptions
                  .map((opt) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _AnswerButton(
                            option: opt,
                            selectedAnswer: _selectedAnswer,
                            onTap: () => _handleAnswer(opt),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final _AnswerOption option;
  final String? selectedAnswer;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.option,
    required this.selectedAnswer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = AppColors.surfaceVariant;
    if (selectedAnswer != null) {
      if (option.isCorrect) {
        bgColor = AppColors.correctAnswer;
      } else if (selectedAnswer == option.text) {
        bgColor = AppColors.wrongAnswer;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.onSurfaceMuted),
      ),
      child: InkWell(
        onTap: selectedAnswer == null ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Text(
            option.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerOption {
  final String text;
  final bool isCorrect;
  const _AnswerOption({required this.text, required this.isCorrect});
}
