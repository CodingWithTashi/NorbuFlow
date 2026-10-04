import 'dart:convert';
import 'dart:typed_data';

import '../../../core/models/formatted_text.dart';
import '../../../core/utils/date_only.dart';
import '../../../core/utils/json.dart';
import '../domain/letter.dart';

/// A letter as the backend lists it.
Letter letterFromJson(Object? json) {
  final fields = jsonObject(json);
  return Letter(
    id: fields['id']! as String,
    number: fields['number']! as String,
    name: fields['name']! as String,
    memberId: fields['memberId'] as String?,
    validUntil: DateTime.parse(fields['validUntil']! as String),
    issuedOn: DateTime.parse(fields['issuedOn']! as String),
  );
}

/// What a letter says, as the backend takes it: a mark that is off is left
/// out.
List<Map<String, Object?>> bodyToJson(List<TextLine> body) => [
  for (final line in body)
    {
      if (line.bullet) 'bullet': true,
      'runs': [
        for (final run in line.runs)
          {'text': run.text, for (final mark in run.marks) mark.name: true},
      ],
    },
];

List<TextLine> bodyFromJson(Object? json) => [
  for (final line in (json! as List).map(jsonObject))
    TextLine([
      for (final run in (line['runs']! as List).map(jsonObject))
        TextRun(
          run['text']! as String,
          marks: {
            for (final mark in TextMark.values)
              if (run[mark.name] == true) mark,
          },
        ),
    ], bullet: line['bullet'] == true),
];

Uint8List letterPdfFromJson(Object? file) =>
    base64Decode(jsonObject(file)['pdf']! as String);

/// A draft as it is kept on the device.
String draftToJson(LetterDraft draft) => jsonEncode({
  'v': 1,
  'name': draft.name,
  'memberId': ?draft.memberId,
  'validUntil': ?draft.validUntil?.isoDate,
  'body': bodyToJson(draft.body),
});

/// Reads what [draftToJson] wrote. Null for anything else.
LetterDraft? draftFromJson(String stored) {
  try {
    final fields = jsonObject(jsonDecode(stored));
    if (fields['v'] != 1) return null;
    return LetterDraft(
      name: fields['name']! as String,
      memberId: fields['memberId'] as String?,
      validUntil: parseIsoDate(fields['validUntil'] as String?),
      body: bodyFromJson(fields['body']),
    );
  } on Object {
    // Written by another version, or damaged: there is no draft.
    return null;
  }
}
