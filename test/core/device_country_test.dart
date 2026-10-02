import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/core/services/device_country.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('device_region');
  const device = SimDeviceCountry();

  /// What the phone's SIM answers when asked its country.
  void simAnswers(Future<Object?> Function() answer) {
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) => answer());
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  String? region() => binding.platformDispatcher.locale.countryCode;

  group("the device's country", () {
    test('is the one its SIM is from', () async {
      simAnswers(() async => 'in');

      expect(await device.isoCode(), 'in');
    });

    test(
      'is the region the device is set to when the SIM has no answer',
      () async {
        simAnswers(() async => null);
        expect(await device.isoCode(), region());

        simAnswers(() async => '');
        expect(await device.isoCode(), region());
      },
    );

    test('is still that region where there is no SIM to ask', () async {
      simAnswers(() => throw PlatformException(code: 'unavailable'));

      expect(await device.isoCode(), region());
    });
  });
}
