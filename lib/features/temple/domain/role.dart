/// Something a person can start from their Home screen.
enum HomeAction {
  addMember,
  renew,
  donate,
  receipt,
  checkIn,
  volunteers,
  announce,
  assign,
  letter,
  hours,
  reports,
  tax,
  team,
  prayers,
  pujaRequests,
  calendar,
  approve,
  plan,
  myShifts,
  myCard,
}

/// What a person does at a temple. Each role gets its own short Home screen,
/// so nobody is shown tools they do not use.
enum Role {
  admin([
    HomeAction.addMember,
    HomeAction.donate,
    HomeAction.checkIn,
    HomeAction.letter,
    HomeAction.volunteers,
    HomeAction.announce,
    HomeAction.team,
  ]),
  geshe([
    HomeAction.prayers,
    HomeAction.pujaRequests,
    HomeAction.calendar,
    HomeAction.approve,
  ]),
  accountant([
    HomeAction.donate,
    HomeAction.receipt,
    HomeAction.reports,
    HomeAction.tax,
    HomeAction.renew,
    HomeAction.announce,
  ]),
  frontDesk([
    HomeAction.addMember,
    HomeAction.renew,
    HomeAction.donate,
    HomeAction.receipt,
    HomeAction.checkIn,
    HomeAction.letter,
    HomeAction.volunteers,
  ]),
  coordinator([
    HomeAction.volunteers,
    HomeAction.assign,
    HomeAction.plan,
    HomeAction.letter,
    HomeAction.hours,
    HomeAction.announce,
  ]),
  volunteer([
    HomeAction.myShifts,
    HomeAction.hours,
    HomeAction.calendar,
    HomeAction.announce,
  ]),
  member([
    HomeAction.myCard,
    HomeAction.renew,
    HomeAction.donate,
    HomeAction.pujaRequests,
  ]);

  const Role(this.homeActions);

  /// Home tiles for this role, in display order.
  final List<HomeAction> homeActions;

  bool get canManageTemple => this == Role.admin;
}
