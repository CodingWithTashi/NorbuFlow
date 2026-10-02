-- What a temple shows of itself: in the app's temple list and on the
-- standard card.

alter table temples add column description text not null default '';

-- Where its logo is in the file store. Null until one is uploaded.
alter table temples add column logo_key text;
