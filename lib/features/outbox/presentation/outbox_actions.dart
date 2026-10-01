import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/command.dart';
import '../data/outbox_repositories.dart';
import '../domain/outbox.dart';

/// Send / print / export commands for views. Each returns whether it worked;
/// failures have already been shown, so callers only handle success.
class OutboxActions {
  OutboxActions(this._ref);

  final Ref _ref;

  OutboxRepository get _repository => _ref.read(outboxRepositoryProvider);

  Future<bool> send(OutgoingMessage message) =>
      _run(() => _repository.send(message), 'outbox.send');

  Future<bool> printDocument(String title) =>
      _run(() => _repository.printDocument(title), 'outbox.print');

  Future<bool> export(String title, ExportFormat format) =>
      _run(() => _repository.export(title, format), 'outbox.export');

  Future<bool> addToWallet(String title) =>
      _run(() => _repository.addToWallet(title), 'outbox.wallet');

  Future<bool> _run(Future<void> Function() action, String source) async =>
      (await runCommand(_ref, action, source: source)).isOk;
}

final outboxActionsProvider = Provider<OutboxActions>(OutboxActions.new);
