import 'dart:convert';

import '../../../core/data/backend.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/services/file_cache.dart';
import '../../../core/utils/json.dart';
import '../domain/card.dart';
import '../domain/member.dart';
import 'member_json.dart';

/// Cards through the backend, which saves the member, numbers them and prints
/// the temple's card. A card is kept on the device, so it is fetched once.
final class FirebaseCardRepository implements CardRepository {
  FirebaseCardRepository(this._backend, this._cache);

  /// Longer than the 60 seconds the functions themselves are given, so the
  /// app never gives up on a card the backend goes on to issue.
  static const _timeout = Duration(seconds: 75);

  final Backend _backend;
  final FileCache _cache;

  @override
  Future<CardPreview> preview(String templeId, CardRequest request) =>
      guardFailures(() async {
        final response = await _backend.call(
          'members-preview',
          input: {
            'templeId': templeId,
            'memberId': ?request.memberId,
            'name': request.name,
            'photo': ?_encoded(request.photo),
            'number': ?request.number,
          },
          timeout: _timeout,
        );
        return CardPreview(
          number: response['number']! as String,
          label: response['label']! as String,
          pdf: pdfFromJson(response['card']),
        );
      });

  @override
  Future<CardOutcome> issue(
    String templeId,
    CardRequest request, {
    bool replace = false,
  }) => guardFailures(() async {
    final memberId = request.memberId;
    final response = await _backend.call(
      memberId == null ? 'members-create' : 'members-update',
      input: {
        'templeId': templeId,
        'id': request.id,
        'memberId': ?memberId,
        'name': request.name,
        'phone': request.phone,
        'email': request.email,
        'photo': ?_encoded(request.photo),
        'number': ?request.number,
        if (replace) 'replace': true,
      },
      timeout: _timeout,
    );
    if (response['taken'] case final taken?) {
      final holder = jsonObject(taken);
      return NumberTaken(
        name: holder['name']! as String,
        number: holder['number']! as String,
      );
    }
    return CardIssued(await _kept(issuedCardFromJson(response)));
  });

  @override
  Future<IssuedCard> fetch(String templeId, Member member) =>
      guardFailures(() async {
        if (member.cardId case final cardId?) {
          final pdf = await _cache.read(CardFiles.pdf(cardId));
          if (pdf != null) return IssuedCard(member: member, pdf: pdf);
        }
        final response = await _backend.call(
          'members-card',
          input: {'templeId': templeId, 'memberId': member.id},
          timeout: _timeout,
        );
        return _kept(issuedCardFromJson(response));
      });

  /// Keeps [card] on the device under its own id, and hands it back.
  Future<IssuedCard> _kept(IssuedCard card) async {
    if (card.member.cardId case final cardId?) {
      await _cache.write(CardFiles.pdf(cardId), card.pdf);
    }
    return card;
  }

  static String? _encoded(List<int>? photo) =>
      photo == null ? null : base64Encode(photo);
}
