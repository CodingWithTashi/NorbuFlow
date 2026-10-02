import 'dart:convert';
import 'dart:typed_data';

import '../../../core/models/photo_source.dart';
import '../../../core/utils/json.dart';
import '../domain/card.dart';
import '../domain/member.dart';

/// A member as the backend sends them. It keeps one name and no membership
/// type yet, and leaves out a phone or an email the member does not have.
Member memberFromJson(Object? json) {
  final fields = jsonObject(json);
  final photoUrl = fields['photoUrl'] as String?;
  return Member(
    id: fields['id']! as String,
    nameEn: fields['name']! as String,
    nameBo: '',
    number: fields['number']! as String,
    phone: fields['phone'] as String? ?? '',
    email: fields['email'] as String? ?? '',
    expiresOn: DateTime.parse(fields['expiresOn']! as String),
    cardId: fields['cardId'] as String?,
    // The link is signed afresh each time; the key is the photo's own name.
    photo: photoUrl == null
        ? null
        : NetworkPhoto(photoUrl, cacheKey: fields['photoKey'] as String?),
  );
}

/// A member with their card, as `members-create`, `-update` and `-card`
/// answer.
IssuedCard issuedCardFromJson(Map<String, Object?> response) => IssuedCard(
  member: memberFromJson(response['member']),
  pdf: pdfFromJson(response['card']),
);

Uint8List pdfFromJson(Object? card) =>
    base64Decode(jsonObject(card)['pdf']! as String);
