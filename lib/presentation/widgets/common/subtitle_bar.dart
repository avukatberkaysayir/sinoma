import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class SubtitleBar extends StatelessWidget {
  final String transcription;
  final String pinyin;
  final List<String> targetWords;
  final void Function(String word) onWordTapped;

  const SubtitleBar({
    super.key,
    required this.transcription,
    required this.pinyin,
    required this.targetWords,
    required this.onWordTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.surfaceVariant,
      child: Column(
        children: [
          Text(
            pinyin,
            style: const TextStyle(
              color: AppColors.onSurfaceMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          _buildTappableText(),
        ],
      ),
    );
  }

  Widget _buildTappableText() {
    final spans = _buildWordWidgets();
    return Wrap(alignment: WrapAlignment.center, children: spans);
  }

  List<Widget> _buildWordWidgets() {
    if (targetWords.isEmpty) {
      return [
        Text(
          transcription,
          style: const TextStyle(color: AppColors.onSurface, fontSize: 22),
        ),
      ];
    }

    // Sort target words by first occurrence position in transcription.
    final positioned = targetWords
        .where((w) => transcription.contains(w))
        .toList()
      ..sort((a, b) =>
          transcription.indexOf(a).compareTo(transcription.indexOf(b)));

    final widgets = <Widget>[];
    int cursor = 0;

    for (final word in positioned) {
      final start = transcription.indexOf(word, cursor);
      if (start == -1) continue;

      if (start > cursor) {
        widgets.add(_plainText(transcription.substring(cursor, start)));
      }

      widgets.add(_tappableWord(word));
      cursor = start + word.length;
    }

    if (cursor < transcription.length) {
      widgets.add(_plainText(transcription.substring(cursor)));
    }

    return widgets;
  }

  Widget _plainText(String text) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.onSurface, fontSize: 22),
    );
  }

  Widget _tappableWord(String word) {
    return GestureDetector(
      onTap: () => onWordTapped(word),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.primary, width: 2)),
        ),
        child: Text(
          word,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
