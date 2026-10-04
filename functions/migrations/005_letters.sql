-- Support letters: a temple's letterhead with a number, a last day and what
-- the letter says set on it.

-- Which letterhead a temple prints (see src/features/letters); null if it has
-- none. Letters are counted on their own, apart from membership numbers.
alter table temples add column letter_template text;
alter table temples
  add column letter_number_next bigint not null default 1 check (letter_number_next > 0);

-- Drepung Loseling Canada's hand-made letters end at number 195959.
update temples
   set letter_template = 'drepung-loseling-canada', letter_number_next = 195960
 where id = 'drepung-loseling-canada';

-- Every letter ever issued, exactly as it was printed. Rows are never changed.
create table letters (
  -- Chosen by the app, so that a request sent twice issues one letter.
  id uuid primary key,
  temple_id text not null references temples (id),
  number bigint not null,
  -- Who it is for, and which member if it is for one.
  name text not null,
  member_id uuid,
  valid_until date not null,
  issued_on date not null,
  -- What it says: lines of runs, as src/features/letters/letter.ts has them.
  body jsonb not null,
  template text not null,
  pdf_key text not null,
  -- The Firebase uid of whoever issued it.
  issued_by text not null,
  issued_at timestamptz not null default now(),
  unique (temple_id, number),
  foreign key (temple_id, member_id) references members (temple_id, id)
);

create index letters_by_issue on letters (temple_id, issued_at desc);

-- The Home card is for temples that have a letterhead.
delete from temple_features f
 using temples t
 where t.id = f.temple_id and f.feature = 'home.letter' and t.letter_template is null;
