import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/calendar/tibetan_calendar.dart';
import '../../../../core/error/command.dart';
import '../../../../core/error/validation_issue.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/validators.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../data/offering_repositories.dart';
import '../../domain/offering.dart';
import 'offering_providers.dart';

enum PujaStep { ceremony, names, sponsor, review }

/// Which list of names a prayer is for.
enum PrayerGroup { living, deceased }

@immutable
class PujaState {
  const PujaState({
    required this.ceremonies,
    required this.dates,
    required this.ceremony,
    required this.date,
    this.step = PujaStep.ceremony,
    this.living = const [],
    this.deceased = const [],
    this.livingInput = '',
    this.deceasedInput = '',
    this.sponsor = '',
    this.contact = '',
    this.dedication = '',
    this.amount = 108,
    this.sponsorIssue,
    this.submitting = false,
    this.receipt,
  });

  /// Auspicious numbers are the usual offering amounts.
  static const amounts = [25, 54, 108, 216];

  final List<Ceremony> ceremonies;

  /// The next few practice days the ceremony can be requested for.
  final List<DateTime> dates;
  final Ceremony ceremony;
  final DateTime date;
  final PujaStep step;
  final List<String> living;
  final List<String> deceased;

  /// Text in the "add a name" box of each group.
  final String livingInput;
  final String deceasedInput;
  final String sponsor;
  final String contact;
  final String dedication;
  final int amount;
  final ValidationIssue? sponsorIssue;
  final bool submitting;
  final Receipt? receipt;

  List<String> names(PrayerGroup group) =>
      group == PrayerGroup.living ? living : deceased;

  String input(PrayerGroup group) =>
      group == PrayerGroup.living ? livingInput : deceasedInput;

  PujaState copyWith({
    Ceremony? ceremony,
    DateTime? date,
    PujaStep? step,
    List<String>? living,
    List<String>? deceased,
    String? livingInput,
    String? deceasedInput,
    String? sponsor,
    String? contact,
    String? dedication,
    int? amount,
    ValidationIssue? Function()? sponsorIssue,
    bool? submitting,
    Receipt? receipt,
  }) {
    return PujaState(
      ceremonies: ceremonies,
      dates: dates,
      ceremony: ceremony ?? this.ceremony,
      date: date ?? this.date,
      step: step ?? this.step,
      living: living ?? this.living,
      deceased: deceased ?? this.deceased,
      livingInput: livingInput ?? this.livingInput,
      deceasedInput: deceasedInput ?? this.deceasedInput,
      sponsor: sponsor ?? this.sponsor,
      contact: contact ?? this.contact,
      dedication: dedication ?? this.dedication,
      amount: amount ?? this.amount,
      sponsorIssue: sponsorIssue == null ? this.sponsorIssue : sponsorIssue(),
      submitting: submitting ?? this.submitting,
      receipt: receipt ?? this.receipt,
    );
  }
}

/// The Puja / Tsok request flow. [_tsok] picks which ceremony starts
/// selected (the Tsok tile opens on the feast offering).
class PujaViewModel extends AsyncNotifier<PujaState> {
  PujaViewModel(this._tsok);

  final bool _tsok;

  @override
  Future<PujaState> build() async {
    final ceremonies = await ref.watch(ceremoniesProvider.future);
    final dates = ref
        .watch(tibetanCalendarProvider)
        .upcomingPracticeDays(ref.watch(todayProvider));
    return PujaState(
      ceremonies: ceremonies,
      dates: dates,
      ceremony: ceremonies.firstWhere(
        (c) => c.isTsok == _tsok,
        orElse: () => ceremonies.first,
      ),
      date: dates.first,
    );
  }

  PujaState get _state => state.requireValue;

  void _set(PujaState next) => state = AsyncData(next);

  void setCeremony(Ceremony ceremony) =>
      _set(_state.copyWith(ceremony: ceremony));

  void setDate(DateTime date) => _set(_state.copyWith(date: date));

  void setNameInput(PrayerGroup group, String value) => _set(
    group == PrayerGroup.living
        ? _state.copyWith(livingInput: value)
        : _state.copyWith(deceasedInput: value),
  );

  void addName(PrayerGroup group) {
    final name = _state.input(group).trim();
    if (name.isEmpty) return;
    _setNames(group, [..._state.names(group), name]);
    setNameInput(group, '');
  }

  /// Removes the name at [index] and returns the list as it was, so the view
  /// can offer Undo via [restoreNames].
  List<String> removeName(PrayerGroup group, int index) {
    final before = _state.names(group);
    _setNames(group, [...before]..removeAt(index));
    return before;
  }

  void restoreNames(PrayerGroup group, List<String> names) =>
      _setNames(group, names);

  void _setNames(PrayerGroup group, List<String> names) => _set(
    group == PrayerGroup.living
        ? _state.copyWith(living: names)
        : _state.copyWith(deceased: names),
  );

  void setSponsor(String value) =>
      _set(_state.copyWith(sponsor: value, sponsorIssue: () => null));

  void setContact(String value) => _set(_state.copyWith(contact: value));

  void setDedication(String value) => _set(_state.copyWith(dedication: value));

  void setAmount(int amount) => _set(_state.copyWith(amount: amount));

  /// Returns false when already on the first step, so the screen can leave.
  bool back() {
    if (_state.step == PujaStep.ceremony) return false;
    _set(_state.copyWith(step: PujaStep.values[_state.step.index - 1]));
    return true;
  }

  Future<void> next() async {
    switch (_state.step) {
      case PujaStep.ceremony || PujaStep.names:
        _advance();
      case PujaStep.sponsor:
        final issue = Validators.required(
          _state.sponsor,
          ValidationIssue.sponsorRequired,
        );
        _set(_state.copyWith(sponsorIssue: () => issue));
        if (issue == null) _advance();
      case PujaStep.review:
        await _submit();
    }
  }

  void _advance() =>
      _set(_state.copyWith(step: PujaStep.values[_state.step.index + 1]));

  Future<void> _submit() async {
    final draft = _state;
    _set(draft.copyWith(submitting: true));
    final templeId = ref.read(activeTempleIdProvider);
    final request = PujaRequest(
      ceremony: draft.ceremony,
      date: draft.date,
      living: draft.living,
      deceased: draft.deceased,
      sponsor: draft.sponsor.trim(),
      contact: draft.contact.trim(),
      dedication: draft.dedication.trim(),
      amount: draft.amount,
    );
    final result = await runCommand(
      ref,
      () => ref
          .read(offeringRepositoryProvider)
          .recordPujaRequest(templeId, request),
      source: 'offerings.recordPujaRequest',
    );
    if (!ref.mounted) return;
    // The Geshe's lists now include these names.
    if (result.isOk) ref.invalidate(prayerListsProvider);
    _set(_state.copyWith(submitting: false, receipt: result.valueOrNull));
  }
}

final pujaViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<PujaViewModel, PujaState, bool>(PujaViewModel.new);
