import 'dart:convert';

import '../../../core/data/backend.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/utils/json.dart';
import '../domain/card.dart';

/// Issues cards through the backend's `members-create`, which saves the
/// member, assigns their number and prints the temple's own card design.
final class FirebaseCardRepository implements CardRepository {
  FirebaseCardRepository(this._backend);

  /// Longer than the 60 seconds the function itself is given, so the app
  /// never gives up on a card the backend goes on to issue.
  static const _timeout = Duration(seconds: 75);

  final Backend _backend;

  @override
  Future<IssuedCard> issue(NewCard card) => guardFailures(() async {
    final response = await _backend.call(
      'members-create',
      input: {
        'id': card.id,
        'name': card.name,
        'phone': card.phone,
        'email': card.email,
        'photo': base64Encode(card.photo),
      },
      timeout: _timeout,
    );
    final member = jsonObject(response['member']);
    final printed = jsonObject(response['card']);
    return IssuedCard(
      number: member['number']! as String,
      name: member['name']! as String,
      expiresOn: DateTime.parse(member['expiresOn']! as String),
      pdf: base64Decode(printed['pdf']! as String),
    );
  });
}
