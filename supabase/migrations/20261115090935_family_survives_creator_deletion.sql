-- A family belongs to its members, not to the account that created it:
-- deleting the creator's account must not delete the family of everyone else.
alter table public.families alter column created_by drop not null;
alter table public.families drop constraint families_created_by_fkey;
alter table public.families add constraint families_created_by_fkey
  foreign key (created_by) references auth.users (id) on delete set null;
