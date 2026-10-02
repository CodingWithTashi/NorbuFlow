import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/command.dart';
import '../../../../core/models/phone_country.dart';
import '../../../../core/models/photo_source.dart';
import '../../../../core/services/contact_launcher.dart';
import '../../../../core/services/device_country.dart';
import '../../../../core/services/document_printer.dart';
import '../../../../core/services/file_cache.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../data/member_repositories.dart';
import '../../domain/card.dart';
import '../../domain/member.dart';
import 'members_view_model.dart';

/// A member's card on file, as their screen shows it.
typedef CardOnFile = ({IssuedCard card, List<MemoryPhoto> pages});

/// The card a member holds, with its pages as pictures, kept on the device
/// after the first look. One provider on purpose: see CLAUDE.md, layer rules.
final memberCardProvider = FutureProvider.autoDispose
    .family<CardOnFile, String>((ref, memberId) async {
      final member = ref.watch(
        memberProvider(memberId).select((member) => member.value),
      );
      if (member == null) throw const NotFoundFailure();
      final printer = ref.watch(documentPrinterProvider);
      final cache = ref.watch(fileCacheProvider);
      final card = await ref
          .watch(cardRepositoryProvider)
          .fetch(ref.watch(activeTempleIdProvider), member);
      return (card: card, pages: await _pagesOf(card, printer, cache));
    });

/// The pictures of [card]'s sides: the ones kept from last time, or drawn
/// now and kept for the next.
Future<List<MemoryPhoto>> _pagesOf(
  IssuedCard card,
  DocumentPrinter printer,
  FileCache cache,
) async {
  final cardId = card.member.cardId;
  if (cardId == null) return printer.photos(card.pdf);

  final kept = await [
    for (var side = 0; side < CardFiles.sides; side++)
      cache.read(CardFiles.page(cardId, side)),
  ].wait;
  if (kept.every((page) => page != null)) {
    return [for (final page in kept) MemoryPhoto(page!)];
  }
  final drawn = await printer.photos(card.pdf);
  await [
    for (final (side, page) in drawn.take(CardFiles.sides).indexed)
      cache.write(CardFiles.page(cardId, side), page.bytes),
  ].wait;
  return drawn;
}

/// What a member's screen can do with their card and their contact details.
/// Failures have already been shown, so callers have nothing to handle.
class MemberActions {
  MemberActions(this._ref);

  final Ref _ref;

  /// Sends the member's card to a printer, as a print job called [title].
  Future<void> printCard(String memberId, String title) => runCommand(
    _ref,
    () async => _ref
        .read(documentPrinterProvider)
        .print(await _pdfOf(memberId), name: title),
    source: 'members.printCard',
  );

  /// Opens the share sheet with the card, as a file named after [title].
  Future<void> shareCard(String memberId, String title) => runCommand(
    _ref,
    () async => _ref
        .read(documentPrinterProvider)
        .share(await _pdfOf(memberId), fileName: '$title.pdf'),
    source: 'members.shareCard',
  );

  /// Opens the mail app with a new message to the member.
  Future<void> email(Member member) => runCommand(
    _ref,
    () => _ref.read(contactLauncherProvider).email(member.email),
    source: 'members.email',
  );

  /// Opens a WhatsApp chat with the member. A number saved without a
  /// country's code is taken to be from this device's country.
  Future<void> whatsApp(Member member) => runCommand(
    _ref,
    () => _ref
        .read(contactLauncherProvider)
        .whatsApp(
          PhoneNumbers.dialable(
            member.phone,
            fallback: _ref.read(homePhoneCountryProvider),
          ),
        ),
    source: 'members.whatsApp',
  );

  Future<Uint8List> _pdfOf(String memberId) async =>
      (await _ref.read(memberCardProvider(memberId).future)).card.pdf;
}

final memberActionsProvider = Provider<MemberActions>(MemberActions.new);
