import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/command.dart';
import '../../../../core/error/result.dart';
import '../../../../core/error/validation_issue.dart';
import '../../../../core/models/photo_source.dart';
import '../../../../core/services/photo_picker.dart';
import '../../../../core/theme/accent_preset.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/temple.dart';
import 'temple_session.dart';

@immutable
class TempleSettingsState {
  const TempleSettingsState({
    required this.draft,
    this.nameIssue,
    this.saving = false,
  });

  /// Edits not yet saved.
  final Temple draft;
  final ValidationIssue? nameIssue;
  final bool saving;

  TempleSettingsState copyWith({
    Temple? draft,
    ValidationIssue? Function()? nameIssue,
    bool? saving,
  }) {
    return TempleSettingsState(
      draft: draft ?? this.draft,
      nameIssue: nameIssue == null ? this.nameIssue : nameIssue(),
      saving: saving ?? this.saving,
    );
  }
}

class TempleSettingsViewModel extends Notifier<TempleSettingsState> {
  @override
  TempleSettingsState build() {
    // Read, not watch: saving must not reset a draft that is being edited.
    final temple = ref.read(currentTempleProvider);
    if (temple == null) throw const NoTempleSelectedFailure();
    return TempleSettingsState(draft: temple);
  }

  void setNameEn(String value) => state = state.copyWith(
    draft: state.draft.copyWith(nameEn: value),
    nameIssue: () => null,
  );

  void setNameBo(String value) => _edit(state.draft.copyWith(nameBo: value));

  void setTradition(String value) =>
      _edit(state.draft.copyWith(tradition: value));

  void setAddress(String value) => _edit(state.draft.copyWith(address: value));

  void setCharityRegistration(String value) =>
      _edit(state.draft.copyWith(charityRegistration: value));

  void setSignatory(String value) =>
      _edit(state.draft.copyWith(signatory: value));

  void setAccent(AccentPreset accent) =>
      _edit(state.draft.copyWith(accent: accent));

  void _edit(Temple draft) => state = state.copyWith(draft: draft);

  /// Picks a logo and applies it straight away, independently of the other
  /// unsaved fields. Returns whether the logo changed.
  Future<bool> pickLogo() async {
    final picked = await runCommand(
      ref,
      () => ref.read(photoPickerProvider).pick(PhotoOrigin.gallery),
      source: 'temple.pickLogo',
    );
    final bytes = picked.valueOrNull;
    if (bytes == null || !ref.mounted) return false;

    final saved = ref.read(currentTempleProvider);
    if (saved == null) return false;
    final logo = MemoryPhoto(bytes);
    final result = await ref
        .read(templesProvider.notifier)
        .saveTemple(saved.copyWith(logo: logo));
    if (result.isOk && ref.mounted) _edit(state.draft.copyWith(logo: logo));
    return result.isOk;
  }

  Future<bool> save() async {
    final issue = Validators.required(
      state.draft.nameEn,
      ValidationIssue.templeNameRequired,
    );
    if (issue != null) {
      state = state.copyWith(nameIssue: () => issue);
      return false;
    }
    state = state.copyWith(saving: true);
    final Result<Temple> result = await ref
        .read(templesProvider.notifier)
        .saveTemple(state.draft);
    if (ref.mounted) state = state.copyWith(saving: false);
    return result.isOk;
  }
}

final templeSettingsViewModelProvider =
    NotifierProvider.autoDispose<TempleSettingsViewModel, TempleSettingsState>(
      TempleSettingsViewModel.new,
    );
