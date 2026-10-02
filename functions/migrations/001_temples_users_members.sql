-- One database, many temples. Every row that belongs to a temple carries its
-- temple_id, its indexes lead with it, and it may only point at rows of that temple.

-- A temple is the tenant. What differs between temples is configuration on
-- this row, not code.
create table temples (
  id text primary key check (id ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name text not null,
  -- Where "today" is decided for the temple's dates, e.g. America/Toronto.
  time_zone text not null,
  -- Which card artwork and layout to print (see src/features/cards).
  card_template text not null,

  -- How long a membership runs: to the same day every year ('fixed_year_end'),
  -- or a number of months from the day it is bought or renewed ('rolling').
  membership_term text not null check (membership_term in ('fixed_year_end', 'rolling')),
  membership_year_end_month smallint check (membership_year_end_month between 1 and 12),
  membership_year_end_day smallint check (membership_year_end_day between 1 and 31),
  membership_months smallint check (membership_months > 0),
  check (
    (membership_term = 'fixed_year_end'
      and membership_year_end_month is not null and membership_year_end_day is not null)
    or (membership_term = 'rolling' and membership_months is not null)
  ),

  -- Membership numbers: the next one to hand out, and how it is written.
  -- Prefix 'JC-' with 4 digits prints number 142 as JC-0142.
  member_number_next bigint not null default 1 check (member_number_next > 0),
  member_number_prefix text not null default '',
  member_number_min_digits smallint not null default 0 check (member_number_min_digits >= 0),

  created_at timestamptz not null default now()
);

-- Everyone who has signed in. The id is their Firebase Auth uid.
create table users (
  id text primary key,
  -- Not unique: an account deleted in Firebase and made again comes back
  -- with a new id and the same address.
  email text not null check (email = lower(email)),
  display_name text not null,
  created_at timestamptz not null default now(),
  last_sign_in_at timestamptz not null default now()
);

create index users_by_email on users (email);

-- Who may work in a temple's portal, and as what. Matched on the email they
-- sign in with, so this is also the invitation list.
create table temple_staff (
  temple_id text not null references temples (id) on delete cascade,
  email text not null check (email = lower(email)),
  role text not null check (
    role in ('admin', 'geshe', 'accountant', 'frontDesk', 'coordinator', 'volunteer', 'member')
  ),
  added_at timestamptz not null default now(),
  primary key (temple_id, email)
);

create index temple_staff_by_email on temple_staff (email);

-- A member as they stand today.
create table members (
  id uuid primary key default gen_random_uuid(),
  temple_id text not null references temples (id),
  number bigint not null,
  name text not null,
  email text check (email = lower(email)),
  phone text,
  -- Where their photo is in the file store.
  photo_key text not null,
  joined_on date not null,
  -- The current membership: when it was last bought or renewed, and its last day.
  renewed_on date not null,
  expires_on date not null,
  -- The Firebase uid of whoever added them.
  created_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (temple_id, number),
  -- Lets other tables point at a member of the same temple (see member_cards).
  unique (temple_id, id)
);

create index members_by_name on members (temple_id, lower(name));
create index members_by_expiry on members (temple_id, expires_on);

-- Every ID card ever issued, exactly as it was printed. Rows are never
-- changed: a renewal or a reprint adds another.
create table member_cards (
  id uuid primary key default gen_random_uuid(),
  temple_id text not null,
  member_id uuid not null,
  number text not null,
  name text not null,
  valid_from date not null,
  valid_until date not null,
  template text not null,
  photo_key text not null,
  pdf_key text not null,
  issued_by text not null,
  issued_at timestamptz not null default now(),
  foreign key (temple_id, member_id) references members (temple_id, id) on delete cascade
);

create index member_cards_by_member on member_cards (temple_id, member_id, issued_at desc);
