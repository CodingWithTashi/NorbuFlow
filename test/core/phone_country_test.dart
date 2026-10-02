import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/core/error/validation_issue.dart';
import 'package:norbu_flow/core/models/phone_country.dart';
import 'package:norbu_flow/core/utils/validators.dart';

void main() {
  group('PhoneCountry', () {
    test(
      'knows the countries the temples are in, by what a SIM calls them',
      () {
        expect(
          [for (final country in PhoneCountry.values) country.isoCode],
          ['CA', 'US', 'IN', 'NP', 'TW', 'FR', 'AU', 'CH', 'GB'],
        );
        expect(PhoneCountry.fromIso('ca'), PhoneCountry.canada);
        expect(PhoneCountry.fromIso('US'), PhoneCountry.unitedStates);
        expect(PhoneCountry.fromIso('GB'), PhoneCountry.unitedKingdom);
      },
    );

    test('has no guess for anywhere else', () {
      expect(PhoneCountry.fromIso('DE'), isNull);
      expect(PhoneCountry.fromIso(''), isNull);
      expect(PhoneCountry.fromIso(null), isNull);
    });
  });

  group('a phone number', () {
    test('is saved with its country\'s code, less the 0 typed in front', () {
      String saved(PhoneCountry country, String typed) =>
          PhoneNumbers.compose(country, typed);

      expect(saved(PhoneCountry.canada, ' 416 555 0142 '), '+1 416 555 0142');
      expect(saved(PhoneCountry.india, '098765 43210'), '+91 98765 43210');
      expect(saved(PhoneCountry.nepal, '98 4123 4567'), '+977 98 4123 4567');
      expect(saved(PhoneCountry.taiwan, '0912 345 678'), '+886 912 345 678');
      expect(saved(PhoneCountry.france, '06 12 34 56 78'), '+33 6 12 34 56 78');
      expect(saved(PhoneCountry.australia, '0412 345 678'), '+61 412 345 678');
      expect(
        saved(PhoneCountry.switzerland, '079 123 45 67'),
        '+41 79 123 45 67',
      );
      expect(
        saved(PhoneCountry.unitedKingdom, '07911 123456'),
        '+44 7911 123456',
      );
    });

    test('loses that 0 when it is typed inside brackets too, so it can be '
        'dialled', () {
      final saved = PhoneNumbers.compose(
        PhoneCountry.australia,
        '(0412) 345 678',
      );

      expect(saved, '+61 (412) 345 678');
      expect(
        PhoneNumbers.dialable(saved, fallback: PhoneCountry.canada),
        '61412345678',
      );
      expect(
        PhoneNumbers.compose(PhoneCountry.unitedKingdom, '(020) 7946 0958'),
        '+44 (20) 7946 0958',
      );
    });

    test('left empty stays empty, and one typed with its own code is kept', () {
      expect(PhoneNumbers.compose(PhoneCountry.canada, '  '), isEmpty);
      expect(
        PhoneNumbers.compose(PhoneCountry.canada, '+91 98765 43210'),
        '+91 98765 43210',
      );
    });

    test('is taken apart again for editing', () {
      (PhoneCountry, String) parsed(String saved) =>
          PhoneNumbers.parse(saved, fallback: PhoneCountry.canada);

      expect(parsed('+91 98765 43210'), (PhoneCountry.india, '98765 43210'));
      expect(parsed('+977-98 4123 4567'), (PhoneCountry.nepal, '98 4123 4567'));
      expect(parsed('+886912345678'), (PhoneCountry.taiwan, '912345678'));
      expect(parsed('+44 7911 123456'), (
        PhoneCountry.unitedKingdom,
        '7911 123456',
      ));
      expect(parsed(''), (PhoneCountry.canada, ''));
    });

    test('with the code Canada and the United States share goes to the '
        'device\'s own country', () {
      expect(
        PhoneNumbers.parse('+1 416 555 0142', fallback: PhoneCountry.canada),
        (PhoneCountry.canada, '416 555 0142'),
      );
      expect(
        PhoneNumbers.parse(
          '+1 212 555 0142',
          fallback: PhoneCountry.unitedStates,
        ),
        (PhoneCountry.unitedStates, '212 555 0142'),
      );
      // Neither is the device's: the first of the two.
      expect(
        PhoneNumbers.parse('+1 416 555 0142', fallback: PhoneCountry.india),
        (PhoneCountry.canada, '416 555 0142'),
      );
    });

    test('saved without a code, or from a country the app does not know, is '
        'left as it was typed', () {
      expect(PhoneNumbers.parse('416 555 0142', fallback: PhoneCountry.india), (
        PhoneCountry.india,
        '416 555 0142',
      ));
      expect(
        PhoneNumbers.parse('+49 30 1234567', fallback: PhoneCountry.canada),
        (PhoneCountry.canada, '+49 30 1234567'),
      );
    });

    test('is dialled country code first, with nothing but digits', () {
      String dialled(String saved) =>
          PhoneNumbers.dialable(saved, fallback: PhoneCountry.canada);

      expect(dialled('+977 98-4123 4567'), '9779841234567');
      expect(dialled('+1 (416) 555-0142'), '14165550142');
      // Saved before numbers carried a code.
      expect(dialled('416 555 0142'), '14165550142');
      expect(
        PhoneNumbers.dialable('0412 345 678', fallback: PhoneCountry.australia),
        '61412345678',
      );
    });
  });

  group('Validators.optionalPhone', () {
    ValidationIssue? check(String typed, PhoneCountry country) =>
        Validators.optionalPhone(typed, country);

    test('lets the number be left out', () {
      expect(check('', PhoneCountry.canada), isNull);
      expect(check('   ', PhoneCountry.france), isNull);
    });

    test('checks the length against the country, however it is punctuated', () {
      expect(check('(416) 555-0142', PhoneCountry.canada), isNull);
      expect(
        check('416 555', PhoneCountry.canada),
        ValidationIssue.phoneTooShort,
      );
      expect(
        check('416 555 0142 9', PhoneCountry.canada),
        ValidationIssue.phoneTooLong,
      );
      // A number that is right in one country is wrong in another.
      expect(check('6 12 34 56 78', PhoneCountry.france), isNull);
      expect(
        check('6 12 34 56 78', PhoneCountry.canada),
        ValidationIssue.phoneTooShort,
      );
    });

    test('does not count the 0 typed in front', () {
      expect(check('06 12 34 56 78', PhoneCountry.france), isNull);
      expect(check('0412 345 678', PhoneCountry.australia), isNull);
      expect(check('07911 123456', PhoneCountry.unitedKingdom), isNull);
    });

    test('takes shorter landlines where a country has them', () {
      expect(check('01 4412345', PhoneCountry.nepal), isNull);
      expect(check('02 2345 6789', PhoneCountry.taiwan), isNull);
      expect(
        check('441234', PhoneCountry.nepal),
        ValidationIssue.phoneTooShort,
      );
    });

    test('checks a number typed with its own code as a whole', () {
      expect(check('+49 30 1234567', PhoneCountry.canada), isNull);
      expect(
        check('+49 30', PhoneCountry.canada),
        ValidationIssue.phoneTooShort,
      );
      expect(
        check('+49 30 1234567 1234567', PhoneCountry.canada),
        ValidationIssue.phoneTooLong,
      );
    });
  });

  group('Validators.memberNumber', () {
    test('takes digits above zero, however many zeros lead', () {
      for (final typed in ['1', '142', ' 0142 ', '194915308', '9' * 15]) {
        expect(Validators.memberNumber(typed), isNull, reason: typed);
      }
    });

    test('refuses anything else', () {
      for (final typed in ['', '0', '000', 'JC-0142', '12.5', '-3', '1' * 16]) {
        expect(
          Validators.memberNumber(typed),
          ValidationIssue.memberNumberInvalid,
          reason: typed,
        );
      }
    });
  });
}
