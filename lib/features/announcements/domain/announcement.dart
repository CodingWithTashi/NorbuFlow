import 'package:flutter/foundation.dart';

/// A starting point for an announcement, with sensible wording filled in.
@immutable
class AnnouncementTemplate {
  const AnnouncementTemplate({
    required this.id,
    required this.name,
    required this.title,
    required this.when,
    required this.details,
  });

  final String id;

  /// Kind of announcement: "Puja schedule", "Teaching", …
  final String name;
  final String title;
  final String when;
  final String details;
}

/// A set of people an announcement can be sent to.
@immutable
class AudienceGroup {
  const AudienceGroup({
    required this.id,
    required this.name,
    required this.size,
  });

  final String id;
  final String name;
  final int size;
}

@immutable
class Announcement {
  const Announcement({
    required this.templateName,
    required this.title,
    required this.when,
    required this.details,
    required this.groupIds,
  });

  final String templateName;
  final String title;
  final String when;
  final String details;
  final List<String> groupIds;
}

/// An announcement written by a team member, waiting for the Geshe's
/// approval before it can go out.
@immutable
class PendingAnnouncement {
  const PendingAnnouncement({
    required this.id,
    required this.templateName,
    required this.title,
    required this.when,
    required this.author,
    required this.audience,
    required this.details,
  });

  final String id;
  final String templateName;
  final String title;
  final String when;
  final String author;
  final String audience;
  final String details;
}

abstract interface class AnnouncementRepository {
  Future<List<AnnouncementTemplate>> fetchTemplates(String templeId);

  Future<List<AudienceGroup>> fetchAudienceGroups(String templeId);

  /// Sends the poster, email and WhatsApp message to the chosen groups.
  Future<void> send(String templeId, Announcement announcement);

  Future<List<PendingAnnouncement>> fetchPending(String templeId);

  Future<void> approve(String templeId, String announcementId);

  /// Returns the announcement to its author asking for changes.
  Future<void> requestChanges(String templeId, String announcementId);
}
