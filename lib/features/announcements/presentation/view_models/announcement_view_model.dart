import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/command.dart';
import '../../../../core/error/result.dart';
import '../../../assistant/data/assistant_repositories.dart';
import '../../../assistant/domain/writing_assistant.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../data/announcement_repositories.dart';
import '../../domain/announcement.dart';

/// How the announcement is previewed before sending.
enum AnnouncementPreview { poster, email, whatsApp }

@immutable
class AnnouncementState {
  const AnnouncementState({
    required this.templates,
    required this.groups,
    required this.template,
    required this.title,
    required this.when,
    required this.details,
    this.preview = AnnouncementPreview.poster,
    this.groupIds = const {},
    this.improving = false,
    this.sending = false,
  });

  final List<AnnouncementTemplate> templates;
  final List<AudienceGroup> groups;
  final AnnouncementTemplate template;
  final String title;
  final String when;
  final String details;
  final AnnouncementPreview preview;
  final Set<String> groupIds;
  final bool improving;
  final bool sending;

  List<AudienceGroup> get selectedGroups =>
      groups.where((group) => groupIds.contains(group.id)).toList();

  /// How many people the chosen groups add up to.
  int get audienceSize =>
      selectedGroups.fold(0, (sum, group) => sum + group.size);

  AnnouncementState copyWith({
    AnnouncementTemplate? template,
    String? title,
    String? when,
    String? details,
    AnnouncementPreview? preview,
    Set<String>? groupIds,
    bool? improving,
    bool? sending,
  }) {
    return AnnouncementState(
      templates: templates,
      groups: groups,
      template: template ?? this.template,
      title: title ?? this.title,
      when: when ?? this.when,
      details: details ?? this.details,
      preview: preview ?? this.preview,
      groupIds: groupIds ?? this.groupIds,
      improving: improving ?? this.improving,
      sending: sending ?? this.sending,
    );
  }
}

class AnnouncementViewModel extends AsyncNotifier<AnnouncementState> {
  AnnouncementRepository get _repository =>
      ref.read(announcementRepositoryProvider);

  @override
  Future<AnnouncementState> build() async {
    final templeId = ref.watch(activeTempleIdProvider);
    final repository = ref.watch(announcementRepositoryProvider);
    final (templates, groups) = await (
      repository.fetchTemplates(templeId),
      repository.fetchAudienceGroups(templeId),
    ).wait;
    final first = templates.first;
    return AnnouncementState(
      templates: templates,
      groups: groups,
      template: first,
      title: first.title,
      when: first.when,
      details: first.details,
      groupIds: {groups.first.id},
    );
  }

  AnnouncementState get _state => state.requireValue;

  void _set(AnnouncementState next) => state = AsyncData(next);

  /// Choosing a template replaces the wording with that template's.
  void selectTemplate(AnnouncementTemplate template) => _set(
    _state.copyWith(
      template: template,
      title: template.title,
      when: template.when,
      details: template.details,
    ),
  );

  void setTitle(String value) => _set(_state.copyWith(title: value));

  void setWhen(String value) => _set(_state.copyWith(when: value));

  void setDetails(String value) => _set(_state.copyWith(details: value));

  void setPreview(AnnouncementPreview preview) =>
      _set(_state.copyWith(preview: preview));

  void toggleGroup(String groupId) {
    final ids = {..._state.groupIds};
    if (!ids.remove(groupId)) ids.add(groupId);
    _set(_state.copyWith(groupIds: ids));
  }

  /// Returns whether the wording was improved; the draft is untouched on
  /// failure.
  Future<bool> improve() async {
    if (_state.improving) return false;
    _set(_state.copyWith(improving: true));
    final draft = _state.details;
    final result = await runCommand(
      ref,
      () => ref
          .read(writingAssistantProvider)
          .improve(draft, WritingKind.announcement),
      source: 'announcement.improve',
    );
    if (!ref.mounted) return false;
    _set(_state.copyWith(improving: false, details: result.valueOrNull));
    return result.isOk;
  }

  Future<Result<void>> send() async {
    final draft = _state;
    _set(draft.copyWith(sending: true));
    final templeId = ref.read(activeTempleIdProvider);
    final result = await runCommand(
      ref,
      () => _repository.send(
        templeId,
        Announcement(
          templateName: draft.template.name,
          title: draft.title.trim(),
          when: draft.when.trim(),
          details: draft.details.trim(),
          groupIds: draft.groupIds.toList(),
        ),
      ),
      source: 'announcement.send',
    );
    if (ref.mounted) _set(_state.copyWith(sending: false));
    return result;
  }
}

final announcementViewModelProvider =
    AsyncNotifierProvider.autoDispose<AnnouncementViewModel, AnnouncementState>(
      AnnouncementViewModel.new,
    );

/// Announcements waiting for the Geshe. Approving or sending one back
/// removes it from the list.
class ApprovalsViewModel extends AsyncNotifier<List<PendingAnnouncement>> {
  late String _templeId;

  @override
  Future<List<PendingAnnouncement>> build() {
    _templeId = ref.watch(activeTempleIdProvider);
    return ref.watch(announcementRepositoryProvider).fetchPending(_templeId);
  }

  Future<bool> approve(String id) => _resolve(
    id,
    () => ref.read(announcementRepositoryProvider).approve(_templeId, id),
  );

  Future<bool> requestChanges(String id) => _resolve(
    id,
    () =>
        ref.read(announcementRepositoryProvider).requestChanges(_templeId, id),
  );

  Future<bool> _resolve(String id, Future<void> Function() action) async {
    final result = await runCommand(ref, action, source: 'announcement.review');
    if (result.isOk && ref.mounted) {
      state = AsyncData([
        for (final item in state.value ?? const <PendingAnnouncement>[])
          if (item.id != id) item,
      ]);
    }
    return result.isOk;
  }
}

final approvalsProvider =
    AsyncNotifierProvider.autoDispose<
      ApprovalsViewModel,
      List<PendingAnnouncement>
    >(ApprovalsViewModel.new);
