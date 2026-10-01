import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../domain/writing_assistant.dart';
import 'fake_writing_assistant.dart';

final writingAssistantProvider = Provider<WritingAssistant>(
  // Thinking takes a little longer than a plain round-trip.
  (ref) => FakeWritingAssistant(ref.watch(appConfigProvider).fakeLatency * 3),
);
