import '../../../core/utils/formatters.dart';
import '../../temple/domain/temple.dart';
import 'volunteer.dart';

enum LetterType { thanks, reference, certificate }

/// Writes the first draft of a volunteer letter from what the temple already
/// knows. Letters are in English; the coordinator edits before sending.
abstract final class LetterComposer {
  static String compose({
    required LetterType type,
    required Volunteer volunteer,
    required Temple temple,
    required DateTime today,
  }) {
    final first = firstNameOf(volunteer.name);
    final hours = volunteer.hoursThisYear;
    final duties = volunteer.duties.toLowerCase();
    return switch (type) {
      LetterType.thanks =>
        'Dear $first,\n\n'
            'On behalf of everyone at ${temple.nameEn}, thank you for your '
            'kind service. This year you have given $hours hours, helping '
            'with $duties. Your generosity keeps our temple open and '
            'welcoming for all.\n\n'
            'With gratitude and prayers,\n'
            '${temple.signatory}\n'
            '${temple.nameEn}',
      LetterType.reference =>
        'To whom it may concern,\n\n'
            'I am pleased to recommend ${volunteer.name}, who has volunteered '
            'at ${temple.nameEn} since ${volunteer.sinceYear}. This year '
            '$first has given $hours hours of service, helping with $duties.'
            '\n\n'
            '$first is reliable, kind and works well with people of all ages. '
            'We would be glad to answer any questions.\n\n'
            'With best wishes,\n'
            '${temple.signatory}\n'
            '${temple.nameEn} · ${temple.charityRegistration}',
      LetterType.certificate =>
        'CERTIFICATE OF SERVICE\n\n'
            'This certifies that ${volunteer.name} has given $hours hours of '
            'volunteer service to ${temple.nameEn} in ${today.year}, helping '
            'with $duties.\n\n'
            'Presented with gratitude on ${Formats.monthDay(today)}, '
            '${today.year}.\n\n'
            '${temple.signatory}\n'
            '${temple.nameEn}',
    };
  }
}
