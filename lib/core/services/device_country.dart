import 'dart:ui';

import 'package:device_region/device_region.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/phone_country.dart';

/// Which country this device is in, as two letters (`CA`), or null if it
/// cannot say.
abstract interface class DeviceCountry {
  Future<String?> isoCode();
}

final class SimDeviceCountry implements DeviceCountry {
  const SimDeviceCountry();

  @override
  Future<String?> isoCode() async {
    try {
      // The SIM's country on Android. iPhones no longer tell apps theirs, so
      // there this is the region the phone is set to.
      final sim = await DeviceRegion.getSIMCountryCode();
      if (sim != null && sim.isNotEmpty) return sim;
    } on Object {
      // No SIM, or a platform without one (web, desktop).
    }
    return PlatformDispatcher.instance.locale.countryCode;
  }
}

final deviceCountryProvider = Provider<DeviceCountry>(
  (ref) => const SimDeviceCountry(),
);

/// The country a new phone number is taken to be from until someone picks
/// another. `bootstrap` overrides this with the device's own.
final homePhoneCountryProvider = Provider<PhoneCountry>(
  (ref) => PhoneCountry.canada,
);
