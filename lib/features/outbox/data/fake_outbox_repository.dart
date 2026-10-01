import '../../../core/data/fake_repository.dart';
import '../domain/outbox.dart';

/// Pretends to deliver: waits like a network call, then succeeds. Keeps a log
/// so tests can assert on what would have been sent.
final class FakeOutboxRepository extends FakeRepository
    implements OutboxRepository {
  FakeOutboxRepository(super.latency);

  final List<OutgoingMessage> sent = [];
  final List<String> jobs = [];

  @override
  Future<void> send(OutgoingMessage message) =>
      respond(() => sent.add(message));

  @override
  Future<void> printDocument(String title) =>
      respond(() => jobs.add('print:$title'));

  @override
  Future<void> export(String title, ExportFormat format) =>
      respond(() => jobs.add('${format.name}:$title'));

  @override
  Future<void> addToWallet(String title) =>
      respond(() => jobs.add('wallet:$title'));
}
