enum WritingKind { announcement }

/// "Improve wording": rewrites a draft to be warmer and clearer while keeping
/// every fact. The real implementation will call a Cloud Function.
abstract interface class WritingAssistant {
  Future<String> improve(String text, WritingKind kind);
}
