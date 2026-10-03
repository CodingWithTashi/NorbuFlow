-- What each temple's app shows: a row for each tab or Home card it has on.
-- Home and More are always shown. The names are listed in
-- src/features/temples/temple.ts, which is what checks them.

create table temple_features (
  temple_id text not null references temples (id) on delete cascade,
  feature text not null,
  primary key (temple_id, feature)
);

-- Temples already registered start where a new one does: members, and two
-- Home cards.
insert into temple_features (temple_id, feature)
select t.id, f.feature
  from temples t
 cross join unnest(array['tab.members', 'home.addMember', 'home.letter']) as f (feature);
