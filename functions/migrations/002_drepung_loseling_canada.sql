-- The first temple. Its hand-made cards run to July 31 and end at number
-- 194915307: new numbers carry on from there, leaving the old ones for import.

insert into temples (
  id,
  name,
  time_zone,
  card_template,
  membership_term,
  membership_year_end_month,
  membership_year_end_day,
  member_number_next
) values (
  'drepung-loseling-canada',
  'Drepung Loseling Canada',
  'America/Toronto',
  'drepung-loseling-canada',
  'fixed_year_end',
  7,
  31,
  194915308
);
