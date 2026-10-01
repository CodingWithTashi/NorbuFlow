import '../../../core/data/fake_repository.dart';
import '../domain/writing_assistant.dart';

/// Stands in for the AI rewrite with honest, mechanical tidying: stray
/// spaces, blank-line runs and sentence capitals. It never invents wording.
final class FakeWritingAssistant extends FakeRepository
    implements WritingAssistant {
  FakeWritingAssistant(super.latency);

  static final _spaces = RegExp(r'[ \t]+');
  static final _blankRuns = RegExp(r'\n{3,}');
  static final _sentenceStart = RegExp(r'(^|[.!?]\s+)([a-z])');

  @override
  Future<String> improve(String text, WritingKind kind) => respond(() {
    return text
        .split('\n')
        .map((line) => line.replaceAll(_spaces, ' ').trim())
        .join('\n')
        .replaceAll(_blankRuns, '\n\n')
        .replaceAllMapped(
          _sentenceStart,
          (match) => '${match[1]}${match[2]!.toUpperCase()}',
        )
        .trim();
  });
}
