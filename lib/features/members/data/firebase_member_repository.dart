import '../../../core/data/backend.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/utils/clock.dart';
import '../domain/member.dart';
import 'member_json.dart';

/// The member list from the backend. Members are added and changed through
/// `CardRepository`, which gives them their card at the same time.
final class FirebaseMemberRepository implements MemberRepository {
  FirebaseMemberRepository(this._backend, this._clock);

  final Backend _backend;
  final Clock _clock;

  @override
  Future<List<Member>> fetchMembers(String templeId) => guardFailures(() async {
    final response = await _backend.call(
      'members-list',
      input: {'templeId': templeId},
    );
    return [
      for (final member in response['members']! as List) memberFromJson(member),
    ];
  });

  /// The backend keeps no check-ins yet, so this only confirms that the
  /// person is on the temple's roll.
  @override
  Future<CheckIn> checkIn(String templeId, String memberId) async {
    final members = await fetchMembers(templeId);
    return guardFailures(
      () async => CheckIn(
        member: members.firstWhere(
          (member) => member.id == memberId,
          orElse: () => throw const NotFoundFailure(),
        ),
        at: _clock(),
      ),
    );
  }

  // The backend adds members with their card, and does not renew yet.
  @override
  Future<Member> addMember(String templeId, NewMember newMember) =>
      Future.error(const UnavailableFailure());

  @override
  Future<Member> renew(String templeId, String memberId) =>
      Future.error(const UnavailableFailure());
}
