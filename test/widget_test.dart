import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_academy/core/utils/hsk_analyzer.dart';

void main() {
  group('HskAnalyzer', () {
    late HskAnalyzer analyzer;

    setUp(() {
      analyzer = const HskAnalyzer({
        '你好': 1,
        '学习': 2,
        '工作': 3,
        '经济': 4,
        '战略': 5,
        '辩证': 6,
      });
    });

    test('returns level of highest word in sentence', () {
      expect(analyzer.computeSentenceLevel('你好，我在学习'), 2);
      expect(analyzer.computeSentenceLevel('这个工作很重要'), 3);
      expect(analyzer.computeSentenceLevel('你好'), 1);
    });

    test('returns 1 for sentence with no known words', () {
      expect(analyzer.computeSentenceLevel('未知文字'), 1);
    });

    test('lookupWordLevel returns correct level', () {
      expect(analyzer.lookupWordLevel('经济'), 4);
      expect(analyzer.lookupWordLevel('未知'), isNull);
    });
  });
}
