import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/presentation/view_models/preferences_view_model.dart';

/// The three introduction slides, in order.
enum OnboardingSlide { members, offerings, volunteers }

class OnboardingViewModel extends Notifier<OnboardingSlide> {
  @override
  OnboardingSlide build() => OnboardingSlide.values.first;

  bool get isLast => state == OnboardingSlide.values.last;

  /// Advances one slide. Returns true when the introduction is finished.
  bool next() {
    if (isLast) {
      finish();
      return true;
    }
    state = OnboardingSlide.values[state.index + 1];
    return false;
  }

  /// Records that the introduction has been seen (also used by Skip), so it
  /// is not shown again.
  void finish() => ref.read(preferencesProvider.notifier).markOnboardingSeen();
}

final onboardingViewModelProvider =
    NotifierProvider.autoDispose<OnboardingViewModel, OnboardingSlide>(
      OnboardingViewModel.new,
    );
