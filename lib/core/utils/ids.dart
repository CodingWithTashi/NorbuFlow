import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Makes a new random id (a UUID). A provider, like the clock, so that a
/// test can say which ids it expects.
final newIdProvider = Provider<String Function()>((ref) => const Uuid().v4);
