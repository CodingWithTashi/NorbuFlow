import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;

import '../../../core/data/fake_repository.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/models/photo_source.dart';
import '../../../core/utils/clock.dart';
import '../domain/card.dart';
import '../domain/member.dart';
import 'fake_member_repository.dart';

/// Issues cards without a backend, to the demo members: numbers carry on
/// from theirs, and the "card" is a plain placeholder, not a temple's artwork.
final class FakeCardRepository extends FakeRepository
    implements CardRepository {
  FakeCardRepository(super.latency, this._clock, this._members);

  final Clock _clock;
  final FakeMemberRepository _members;

  /// What each request made, so that one sent twice makes one card.
  final _issued = <String, IssuedCard>{};

  /// The card each member was last issued.
  final _cards = <String, IssuedCard>{};

  @override
  Future<CardPreview> preview(String templeId, CardRequest request) async {
    final label = await respond(() => _numberFor(templeId, request));
    return CardPreview(
      number: Member.digitsOf(label),
      label: label,
      pdf: await _placeholder(request.name, label),
    );
  }

  @override
  Future<CardOutcome> issue(
    String templeId,
    CardRequest request, {
    bool replace = false,
  }) async {
    if (_issued[request.id] case final card?) return CardIssued(card);

    final label = await respond(() => _numberFor(templeId, request));
    final members = _members.membersOf(templeId);
    final onFile = _onFile(members, request.memberId);
    final holder = members
        .where((member) => member.number == label && member.id != onFile?.id)
        .firstOrNull;
    // Only a new member can take over someone's number, and only when asked.
    if (holder != null && (onFile != null || !replace)) {
      return NumberTaken(name: holder.nameEn, number: label);
    }

    final record = onFile ?? holder;
    final photo = request.photo;
    final member = Member(
      id: record?.id ?? request.id,
      nameEn: request.name,
      nameBo: onFile?.nameBo ?? '',
      number: label,
      phone: request.phone,
      email: request.email,
      type: record?.type ?? MembershipType.individual,
      // A member on file keeps their dates; anyone else starts a year today.
      expiresOn: onFile != null
          ? onFile.expiresOn
          : _clock().dateOnly.plusOneYear,
      photo: photo == null ? record?.photo : MemoryPhoto(photo),
    );
    final card = IssuedCard(
      member: member,
      pdf: await _placeholder(member.nameEn, label),
    );
    _members.save(templeId, member);
    return CardIssued(_issued[request.id] = _cards[member.id] = card);
  }

  @override
  Future<IssuedCard> fetch(String templeId, Member asked) async {
    final memberId = asked.id;
    final member = await respond(
      () => _onFile(_members.membersOf(templeId), memberId)!,
    );
    final card = _cards[memberId];
    if (card != null && card.member == member) return card;
    // A demo member who was never issued a card here gets one drawn now.
    return _cards[memberId] = IssuedCard(
      member: member,
      pdf: await _placeholder(member.nameEn, member.number),
    );
  }

  /// The number [request]'s card carries: the one typed, the member's own,
  /// or the temple's next, each written the way the temple writes them.
  String _numberFor(String templeId, CardRequest request) {
    final members = _members.membersOf(templeId);
    final onFile = _onFile(members, request.memberId);
    final next = Member.numberAfter(
      members.map((member) => member.number),
      whenNone: FakeMemberRepository.firstNumber,
    );
    return switch (request.number) {
      final digits? => Member.rewritten(next, digits),
      null => onFile?.number ?? next,
    };
  }

  static Member? _onFile(List<Member> members, String? memberId) {
    if (memberId == null) return null;
    return members.firstWhere(
      (member) => member.id == memberId,
      orElse: () => throw const NotFoundFailure(),
    );
  }

  /// A front and a back the size of a real card.
  static Future<Uint8List> _placeholder(String name, String number) {
    const small = pdf.TextStyle(fontSize: 7);
    pdf.Page side(List<pdf.Widget> lines) => pdf.Page(
      pageFormat: const PdfPageFormat(159.75, 252, marginAll: 12),
      build: (context) => pdf.Center(
        child: pdf.Column(mainAxisSize: pdf.MainAxisSize.min, children: lines),
      ),
    );
    final document = pdf.Document()
      ..addPage(
        side([
          pdf.Text('DEMO CARD', style: small),
          pdf.SizedBox(height: 10),
          pdf.Text(name, style: const pdf.TextStyle(fontSize: 9)),
          pdf.Text(number, style: const pdf.TextStyle(fontSize: 10)),
        ]),
      )
      ..addPage(side([pdf.Text('DEMO CARD, BACK', style: small)]));
    return guardFailures(document.save);
  }
}
