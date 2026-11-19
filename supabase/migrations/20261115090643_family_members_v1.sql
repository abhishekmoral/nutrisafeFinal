-- NutriSafe: Add Family Member feature (PRD "Add Family Member", v1.0, November 2026).
--
-- The PRD's recommended tables map onto tables that already exist:
--   family_memberships        -> family_members
--   family_member_profiles    -> child_profiles        (managed profiles: no login, no auth account)
--   child_guardians           -> guardian_assignments  (role: guardian | caregiver)
--   family_access_permissions -> family_permissions    (per-member data-sharing scopes)
--   activity_logs             -> audit_logs
-- New: family_invitations, profiles.nutrisafe_id, child_profiles.managed_id.
--
-- Subject of a health record: child_id set -> the managed profile; child_id null -> owner_id.

-- ============================================================================ 1. Codes
create or replace function private.random_code(p_prefix text)
returns text language plpgsql volatile set search_path = '' as $$
declare
  alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ'; -- no 0/O, 1/I/L
  bytes bytea := extensions.gen_random_bytes(6);
  code text := '';
begin
  for i in 0..5 loop
    code := code || substr(alphabet, (get_byte(bytes, i) % 31) + 1, 1);
  end loop;
  return p_prefix || '-' || code;
end $$;

-- Accepts "NS-84K92P", "ns 84k92p", "NS84K92P" or "84K92P"; null when it cannot be an ID.
create or replace function private.normalize_nutrisafe_id(p_value text)
returns text language sql immutable set search_path = '' as $$
  select case
    when c ~ '^NS[2-9A-HJKMNP-Z]{6}$' then 'NS-' || substr(c, 3)
    when c ~ '^[2-9A-HJKMNP-Z]{6}$' then 'NS-' || c
    else null
  end
  from (select regexp_replace(upper(coalesce(p_value, '')), '[^A-Z0-9]', '', 'g') as c) x;
$$;

create or replace function private.assign_unique_code()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  candidate text;
begin
  if TG_TABLE_NAME = 'profiles' then
    loop
      candidate := private.random_code('NS');
      exit when not exists (select 1 from public.profiles p where p.nutrisafe_id = candidate);
    end loop;
    new.nutrisafe_id := candidate;
  else
    loop
      candidate := private.random_code('MP');
      exit when not exists (select 1 from public.child_profiles c where c.managed_id = candidate);
    end loop;
    new.managed_id := candidate;
  end if;
  return new;
end $$;

create or replace function private.prevent_code_change()
returns trigger language plpgsql set search_path = '' as $$
begin
  if TG_TABLE_NAME = 'profiles' then
    if new.nutrisafe_id is distinct from old.nutrisafe_id then
      raise exception 'A NutriSafe ID cannot be changed.';
    end if;
  else
    if new.managed_id is distinct from old.managed_id then
      raise exception 'A managed profile ID cannot be changed.';
    end if;
  end if;
  return new;
end $$;

-- ============================================================================ 2. NutriSafe ID
alter table public.profiles add column nutrisafe_id text;
create unique index profiles_nutrisafe_id_key on public.profiles (nutrisafe_id);

do $$
declare
  r record;
  assigned boolean;
begin
  for r in select id from public.profiles where nutrisafe_id is null loop
    assigned := false;
    while not assigned loop
      begin
        update public.profiles set nutrisafe_id = private.random_code('NS') where id = r.id;
        assigned := true;
      exception when unique_violation then
        assigned := false;
      end;
    end loop;
  end loop;
end $$;

alter table public.profiles
  alter column nutrisafe_id set not null,
  add constraint profiles_nutrisafe_id_format check (nutrisafe_id ~ '^NS-[2-9A-HJKMNP-Z]{6}$');

create trigger profiles_assign_nutrisafe_id before insert on public.profiles
  for each row execute function private.assign_unique_code();
create trigger profiles_nutrisafe_id_immutable before update of nutrisafe_id on public.profiles
  for each row execute function private.prevent_code_change();

-- Users edit their own details but never their id or NutriSafe ID.
revoke insert, update on public.profiles from authenticated;
grant insert (id, full_name, date_of_birth, gender, height_cm, weight_kg, activity_level,
              dietary_preference, location, avatar_path, onboarding_completed)
  on public.profiles to authenticated;
grant update (full_name, date_of_birth, gender, height_cm, weight_kg, activity_level,
              dietary_preference, location, avatar_path, onboarding_completed)
  on public.profiles to authenticated;

-- ============================================================================ 3. Family: one per account, no join codes
create unique index family_members_one_family_key on public.family_members (user_id);

drop function public.join_family(text);
drop function public.regenerate_invite_code(uuid);
alter table public.families drop column invite_code;

-- Families are removed automatically when the last member leaves.
drop policy families_delete on public.families;
revoke delete on public.families from authenticated;

create or replace function private.check_new_family()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.family_members m where m.user_id = new.created_by) then
    raise exception 'You are already in a family. Leave it before creating a new one.';
  end if;
  return new;
end $$;
create trigger families_one_per_account before insert on public.families
  for each row execute function private.check_new_family();

-- ============================================================================ 4. Managed profiles
alter table public.child_profiles
  add column relationship text check (relationship in ('child', 'parent', 'grandparent', 'spouse', 'sibling', 'other')),
  add column notes text check (char_length(notes) <= 500),
  add column managed_id text;
create unique index child_profiles_managed_id_key on public.child_profiles (managed_id);

do $$
declare
  r record;
  assigned boolean;
begin
  for r in select id from public.child_profiles where managed_id is null loop
    assigned := false;
    while not assigned loop
      begin
        update public.child_profiles set managed_id = private.random_code('MP') where id = r.id;
        assigned := true;
      exception when unique_violation then
        assigned := false;
      end;
    end loop;
  end loop;
end $$;

alter table public.child_profiles
  alter column managed_id set not null,
  add constraint child_profiles_managed_id_format check (managed_id ~ '^MP-[2-9A-HJKMNP-Z]{6}$'),
  alter column date_of_birth set not null,
  add constraint child_profiles_dob_range check (date_of_birth >= date '1900-01-01'),
  add constraint child_profiles_diet_check check (dietary_preference in
    ('vegetarian', 'non_vegetarian', 'vegan', 'eggetarian', 'jain', 'pescatarian', 'other'));

-- The creator can leave or delete their account; the profile stays with its other guardians.
alter table public.child_profiles alter column created_by drop not null;
alter table public.child_profiles drop constraint child_profiles_created_by_fkey;
alter table public.child_profiles add constraint child_profiles_created_by_fkey
  foreign key (created_by) references auth.users (id) on delete set null;

create trigger child_profiles_assign_managed_id before insert on public.child_profiles
  for each row execute function private.assign_unique_code();
create trigger child_profiles_managed_id_immutable before update of managed_id on public.child_profiles
  for each row execute function private.prevent_code_change();

-- Guardian = full management. Caregiver = can view the profile and keep its food diary.
alter table public.guardian_assignments
  add column role text not null default 'guardian' check (role in ('guardian', 'caregiver'));

create or replace function private.is_guardian(p_child uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.guardian_assignments g
    where g.child_id = p_child and g.guardian_id = (select auth.uid()) and g.role = 'guardian'
  );
$$;

create or replace function private.can_care_for(p_child uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.guardian_assignments g
    where g.child_id = p_child and g.guardian_id = (select auth.uid())
  );
$$;

-- Read / log access to a health record.
create or replace function private.can_access(p_owner uuid, p_child uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when p_child is null then p_owner = (select auth.uid())
    else private.can_care_for(p_child)
  end;
$$;

-- Managing sensitive settings (allergies, goals, medical reports): guardians only for managed profiles.
create or replace function private.can_manage(p_owner uuid, p_child uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when p_child is null then p_owner = (select auth.uid())
    else private.is_guardian(p_child)
  end;
$$;

-- A managed profile always keeps at least one guardian.
create or replace function private.prevent_last_guardian_removal()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(current_setting('nutrisafe.deleting_user', true), '') = old.guardian_id::text then
    if TG_OP = 'DELETE' then return old; end if;
    return new;
  end if;
  if old.role = 'guardian' then
    if TG_OP = 'UPDATE' then
      if new.role = 'guardian' then return new; end if;
    end if;
    if exists (select 1 from public.child_profiles c where c.id = old.child_id)
       and not exists (
         select 1 from public.guardian_assignments g
         where g.child_id = old.child_id and g.id <> old.id and g.role = 'guardian'
       ) then
      raise exception 'Each managed profile needs at least one guardian. Make someone else a guardian first.';
    end if;
  end if;
  if TG_OP = 'DELETE' then return old; end if;
  return new;
end $$;
drop trigger guardian_keep_one on public.guardian_assignments;
create trigger guardian_keep_one before delete or update of role on public.guardian_assignments
  for each row execute function private.prevent_last_guardian_removal();

drop policy child_profiles_select on public.child_profiles;
drop policy child_profiles_insert on public.child_profiles;
drop policy child_profiles_update on public.child_profiles;
drop policy child_profiles_delete on public.child_profiles;
create policy child_profiles_select on public.child_profiles for select to authenticated
  using (private.can_care_for(id));
-- Created only through create_managed_profile() (checks the family admin role).
create policy child_profiles_update on public.child_profiles for update to authenticated
  using (private.is_guardian(id)) with check (private.is_guardian(id));
create policy child_profiles_delete on public.child_profiles for delete to authenticated
  using (private.is_guardian(id));
revoke insert, update on public.child_profiles from authenticated;
grant update (full_name, date_of_birth, gender, height_cm, weight_kg, dietary_preference,
              avatar_path, relationship, notes)
  on public.child_profiles to authenticated;

drop policy guardian_assignments_select on public.guardian_assignments;
drop policy guardian_assignments_insert on public.guardian_assignments;
drop policy guardian_assignments_delete on public.guardian_assignments;
create policy guardian_assignments_select on public.guardian_assignments for select to authenticated
  using (guardian_id = (select auth.uid()) or private.can_care_for(child_id));
create policy guardian_assignments_insert on public.guardian_assignments for insert to authenticated
  with check (private.is_guardian(child_id)
    and assigned_by = (select auth.uid())
    and private.can_be_guardian(child_id, guardian_id));
create policy guardian_assignments_update on public.guardian_assignments for update to authenticated
  using (private.is_guardian(child_id)) with check (private.is_guardian(child_id));
create policy guardian_assignments_delete on public.guardian_assignments for delete to authenticated
  using (private.is_guardian(child_id) or guardian_id = (select auth.uid()));
revoke update on public.guardian_assignments from authenticated;
grant update (role) on public.guardian_assignments to authenticated;

-- ============================================================================ 5. Records belong to the managed profile
-- Uniqueness for managed-profile rows is per profile, not per adult who entered them.
do $$
declare
  spec record;
begin
  for spec in
    select * from (values
      ('food_diaries', 'food_diaries_owner_id_child_id_diary_date_key', 'diary_date'),
      ('nutrition_goals', 'nutrition_goals_owner_id_child_id_key', null),
      ('allergy_profiles', 'allergy_profiles_owner_id_child_id_allergen_key', 'allergen'),
      ('intolerance_profiles', 'intolerance_profiles_owner_id_child_id_food_key', 'food'),
      ('user_health_goals', 'user_health_goals_owner_id_child_id_goal_type_key', 'goal_type'),
      ('ai_user_context_permissions', 'ai_user_context_permissions_owner_id_child_id_context_type_key', 'context_type'),
      ('health_progress_logs', 'health_progress_logs_owner_id_child_id_log_date_key', 'log_date')
    ) as s(tbl, con, col)
  loop
    execute format('alter table public.%I drop constraint %I', spec.tbl, spec.con);
    execute format('create unique index %I on public.%I (owner_id%s) where child_id is null',
                   spec.tbl || '_own_key', spec.tbl, coalesce(', ' || spec.col, ''));
    execute format('create unique index %I on public.%I (child_id%s) where child_id is not null',
                   spec.tbl || '_managed_key', spec.tbl, coalesce(', ' || spec.col, ''));
  end loop;
end $$;

-- Who entered a food entry (the subject is owner_id / child_id).
alter table public.meal_entries
  add column added_by uuid default auth.uid() references auth.users (id) on delete set null;
create index meal_entries_added_by_idx on public.meal_entries (added_by);

create or replace function private.attach_meal_entry_diary()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.added_by := coalesce((select auth.uid()), new.added_by);
  -- The diary row is always derived from the entry's subject and date, never taken from the client.
  if new.child_id is null then
    insert into public.food_diaries (owner_id, child_id, diary_date)
    values (new.owner_id, null, new.entry_date)
    on conflict (owner_id, diary_date) where child_id is null do update set updated_at = now()
    returning id into new.diary_id;
  else
    insert into public.food_diaries (owner_id, child_id, diary_date)
    values (new.owner_id, new.child_id, new.entry_date)
    on conflict (child_id, diary_date) where child_id is not null do update set updated_at = now()
    returning id into new.diary_id;
  end if;
  return new;
end $$;

-- The owner of a record cannot be changed, except when records move to another guardian
-- because the adult who entered them deletes their account.
create or replace function private.prevent_owner_change()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.owner_id is distinct from old.owner_id or new.child_id is distinct from old.child_id then
    if new.child_id is not distinct from old.child_id
       and coalesce(current_setting('nutrisafe.deleting_user', true), '') = old.owner_id::text then
      return new;
    end if;
    raise exception 'The owner of a record cannot be changed';
  end if;
  return new;
end $$;

-- ============================================================================ 6. Per-member sharing permissions
alter table public.family_permissions drop constraint family_permissions_scope_check;
update public.family_permissions set scope = case scope
  when 'food_diary' then 'view_food_diary'
  when 'nutrition_insights' then 'view_insights'
  else scope end;
alter table public.family_permissions add constraint family_permissions_scope_check check (scope in
  ('view_profile', 'view_food_diary', 'add_food', 'edit_food', 'delete_food', 'view_allergies', 'view_insights'));

drop policy profiles_select_own on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.has_family_permission(id, 'view_profile'));

do $$
declare
  t text;
begin
  foreach t in array array['food_diaries', 'water_logs'] loop
    execute format('drop policy %I on public.%I', t || '_select', t);
    execute format(
      'create policy %I on public.%I for select to authenticated
         using (private.can_access(owner_id, child_id)
                or (child_id is null and private.has_family_permission(owner_id, %L)))',
      t || '_select', t, 'view_food_diary');
  end loop;
end $$;

drop policy meal_entries_select on public.meal_entries;
drop policy meal_entries_insert on public.meal_entries;
drop policy meal_entries_update on public.meal_entries;
drop policy meal_entries_delete on public.meal_entries;
drop policy meal_entries_insert_as_self on public.meal_entries;
create policy meal_entries_select on public.meal_entries for select to authenticated
  using (private.can_access(owner_id, child_id)
         or (child_id is null and private.has_family_permission(owner_id, 'view_food_diary')));
create policy meal_entries_insert on public.meal_entries for insert to authenticated
  with check (private.can_access(owner_id, child_id)
              or (child_id is null and private.has_family_permission(owner_id, 'add_food')));
create policy meal_entries_insert_as_self on public.meal_entries as restrictive for insert to authenticated
  with check ((child_id is not null and owner_id = (select auth.uid()))
              or (child_id is null and (owner_id = (select auth.uid())
                                        or private.has_family_permission(owner_id, 'add_food'))));
create policy meal_entries_update on public.meal_entries for update to authenticated
  using (private.can_access(owner_id, child_id)
         or (child_id is null and private.has_family_permission(owner_id, 'edit_food')))
  with check (private.can_access(owner_id, child_id)
              or (child_id is null and private.has_family_permission(owner_id, 'edit_food')));
create policy meal_entries_delete on public.meal_entries for delete to authenticated
  using (private.can_access(owner_id, child_id)
         or (child_id is null and private.has_family_permission(owner_id, 'delete_food')));

-- Allergies, intolerances, goals: carers can read; only guardians (or the adult) can change them.
do $$
declare
  t text;
begin
  foreach t in array array['allergy_profiles', 'intolerance_profiles', 'user_health_goals'] loop
    execute format('drop policy %I on public.%I', t || '_owner_access', t);
    execute format(
      'create policy %I on public.%I for select to authenticated using (private.can_access(owner_id, child_id)%s)',
      t || '_select', t,
      case when t = 'user_health_goals' then ''
           else ' or (child_id is null and private.has_family_permission(owner_id, ''view_allergies''))' end);
    execute format('create policy %I on public.%I for insert to authenticated with check (private.can_manage(owner_id, child_id))', t || '_insert', t);
    execute format('create policy %I on public.%I for update to authenticated using (private.can_manage(owner_id, child_id)) with check (private.can_manage(owner_id, child_id))', t || '_update', t);
    execute format('create policy %I on public.%I for delete to authenticated using (private.can_manage(owner_id, child_id))', t || '_delete', t);
  end loop;
end $$;

drop policy nutrition_goals_select on public.nutrition_goals;
drop policy nutrition_goals_insert on public.nutrition_goals;
drop policy nutrition_goals_update on public.nutrition_goals;
drop policy nutrition_goals_delete on public.nutrition_goals;
create policy nutrition_goals_select on public.nutrition_goals for select to authenticated
  using (private.can_access(owner_id, child_id)
         or (child_id is null and private.has_family_permission(owner_id, 'view_insights')));
create policy nutrition_goals_insert on public.nutrition_goals for insert to authenticated
  with check (private.can_manage(owner_id, child_id));
create policy nutrition_goals_update on public.nutrition_goals for update to authenticated
  using (private.can_manage(owner_id, child_id)) with check (private.can_manage(owner_id, child_id));
create policy nutrition_goals_delete on public.nutrition_goals for delete to authenticated
  using (private.can_manage(owner_id, child_id));

-- Medical reports of a managed profile: guardians only.
create or replace function private.can_write_report(p_report uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.medical_reports r
    where r.id = p_report and private.can_manage(r.owner_id, r.child_id)
  );
$$;
drop policy medical_reports_select on public.medical_reports;
drop policy medical_reports_insert on public.medical_reports;
drop policy medical_reports_update on public.medical_reports;
drop policy medical_reports_delete on public.medical_reports;
create policy medical_reports_select on public.medical_reports for select to authenticated
  using (private.can_manage(owner_id, child_id) or private.report_shared_with_me(id));
create policy medical_reports_insert on public.medical_reports for insert to authenticated
  with check (owner_id = (select auth.uid()) and private.can_manage(owner_id, child_id));
create policy medical_reports_update on public.medical_reports for update to authenticated
  using (private.can_manage(owner_id, child_id)) with check (private.can_manage(owner_id, child_id));
create policy medical_reports_delete on public.medical_reports for delete to authenticated
  using (private.can_manage(owner_id, child_id));

-- ============================================================================ 7. Invitations
create table public.family_invitations (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  invited_by uuid references auth.users (id) on delete set null,
  invitee_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected', 'expired', 'revoked')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  responded_at timestamptz,
  check (invited_by is null or invited_by <> invitee_id)
);
create unique index family_invitations_one_pending_key on public.family_invitations (family_id, invitee_id)
  where status = 'pending';
create index family_invitations_invitee_idx on public.family_invitations (invitee_id, status);
create index family_invitations_invited_by_idx on public.family_invitations (invited_by);

alter table public.family_invitations enable row level security;
revoke all on public.family_invitations from anon, authenticated;
grant select on public.family_invitations to authenticated;
-- Created, answered and cancelled only through the functions below.
create policy family_invitations_select on public.family_invitations for select to authenticated
  using (invitee_id = (select auth.uid())
         or invited_by = (select auth.uid())
         or private.is_family_admin(family_id));

create or replace function private.expire_invitations()
returns void language sql security definer set search_path = '' as $$
  update public.family_invitations
  set status = 'expired', responded_at = now()
  where status = 'pending' and expires_at <= now();
$$;

-- ============================================================================ 8. Notifications and activity log
alter table public.notifications drop constraint notifications_category_check;
alter table public.notifications add constraint notifications_category_check check (category in
  ('water', 'meal', 'food_tracking', 'health_check_in', 'meal_plan',
   'ai_follow_up', 'report', 'goal', 'weekly_summary', 'family'));
alter table public.notification_preferences drop constraint notification_preferences_category_check;
alter table public.notification_preferences add constraint notification_preferences_category_check check (category in
  ('water', 'meal', 'food_tracking', 'health_check_in', 'meal_plan',
   'ai_follow_up', 'report', 'goal', 'weekly_summary', 'family'));

-- Notification text never contains health or nutrition details.
create or replace function private.notify(p_user uuid, p_title text, p_body text, p_dedupe boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_user is null then return; end if;
  if p_dedupe and exists (
    select 1 from public.notifications n
    where n.user_id = p_user and n.title = p_title and n.read_at is null
      and n.created_at > now() - interval '30 minutes'
  ) then
    return;
  end if;
  insert into public.notifications (user_id, category, title, body, sent_at)
  values (p_user, 'family', p_title, p_body, now());
end $$;

create or replace function private.audit_family_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_row jsonb;
begin
  if TG_OP = 'DELETE' then
    v_row := to_jsonb(old);
  else
    v_row := to_jsonb(new);
  end if;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    (select auth.uid()),
    TG_TABLE_NAME || '.' || lower(TG_OP),
    TG_TABLE_NAME,
    (v_row ->> 'id')::uuid,
    jsonb_strip_nulls(jsonb_build_object(
      'family_id', v_row ->> 'family_id', 'child_id', v_row ->> 'child_id',
      'user_id', v_row ->> 'user_id', 'guardian_id', v_row ->> 'guardian_id',
      'grantee_id', v_row ->> 'grantee_id', 'invitee_id', v_row ->> 'invitee_id',
      'status', v_row ->> 'status', 'role', v_row ->> 'role', 'scope', v_row ->> 'scope'))
  );
  return null;
end $$;

create trigger family_members_audit after insert or delete or update of role on public.family_members
  for each row execute function private.audit_family_change();
create trigger family_invitations_audit after insert or update of status on public.family_invitations
  for each row execute function private.audit_family_change();
create trigger guardian_assignments_audit after insert or delete or update of role on public.guardian_assignments
  for each row execute function private.audit_family_change();
create trigger family_permissions_audit after insert or delete on public.family_permissions
  for each row execute function private.audit_family_change();
create trigger child_profiles_audit after insert or delete on public.child_profiles
  for each row execute function private.audit_family_change();

create or replace function private.notify_family_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  m record;
begin
  if TG_TABLE_NAME = 'family_permissions' then
    perform private.notify(
      case when TG_OP = 'DELETE' then old.grantee_id else new.grantee_id end,
      'Your family data permissions were updated',
      'Open Family in NutriSafe to see what is shared with you.', true);
  elsif TG_TABLE_NAME = 'child_profiles' and new.family_id is not null then
    for m in
      select user_id from public.family_members
      where family_id = new.family_id and user_id is distinct from new.created_by
    loop
      perform private.notify(m.user_id, 'A new managed profile was created',
                             'Open Family in NutriSafe to see your family members.');
    end loop;
  end if;
  return null;
end $$;
create trigger family_permissions_notify after insert or delete on public.family_permissions
  for each row execute function private.notify_family_change();
create trigger child_profiles_notify after insert on public.child_profiles
  for each row execute function private.notify_family_change();

-- Simple per-account limit, counted in the activity log (which users cannot delete).
create or replace function private.check_rate(p_action text, p_limit int)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.audit_logs a
      where a.actor_id = (select auth.uid()) and a.action = p_action
        and a.created_at > now() - interval '1 hour') >= p_limit then
    raise exception 'Too many attempts. Please try again in an hour.';
  end if;
  insert into public.audit_logs (actor_id, action, entity_type) values ((select auth.uid()), p_action, 'family');
end $$;

-- ============================================================================ 9. Leaving, removal, account deletion
create or replace function private.before_family_member_removed()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_name text;
begin
  if coalesce(current_setting('nutrisafe.deleting_user', true), '') = old.user_id::text then
    return old;
  end if;
  select c.full_name into v_name
  from public.child_profiles c
  join public.guardian_assignments g on g.child_id = c.id and g.guardian_id = old.user_id and g.role = 'guardian'
  where c.family_id = old.family_id
    and not exists (
      select 1 from public.guardian_assignments o
      where o.child_id = c.id and o.role = 'guardian' and o.guardian_id <> old.user_id
    )
  limit 1;
  if v_name is not null then
    raise exception 'This member is the only guardian of %. Make another family member a guardian of % first.', v_name, v_name;
  end if;
  return old;
end $$;
create trigger before_family_member_removed before delete on public.family_members
  for each row execute function private.before_family_member_removed();

create or replace function private.handle_family_member_removed()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  -- Everything shared inside the family stops.
  delete from public.family_permissions fp
  where fp.family_id = old.family_id
    and (fp.owner_id = old.user_id or fp.grantee_id = old.user_id);

  delete from public.medical_report_permissions p
  where (p.owner_id = old.user_id or p.grantee_id = old.user_id)
    and not exists (
      select 1
      from public.family_members a
      join public.family_members b on b.family_id = a.family_id
      where a.user_id = p.owner_id and b.user_id = p.grantee_id
        and a.id <> old.id and b.id <> old.id
    );

  -- Their guardian / caregiver roles for this family's managed profiles end.
  if coalesce(current_setting('nutrisafe.deleting_user', true), '') <> old.user_id::text then
    delete from public.guardian_assignments g
    using public.child_profiles c
    where g.child_id = c.id and c.family_id = old.family_id and g.guardian_id = old.user_id;
  end if;

  -- Invitations they sent for this family are withdrawn.
  update public.family_invitations
  set status = 'revoked', responded_at = now()
  where family_id = old.family_id and invited_by = old.user_id and status = 'pending';

  -- A family always keeps an admin; an empty family is removed.
  if not exists (select 1 from public.family_members where family_id = old.family_id and role = 'admin') then
    update public.family_members set role = 'admin'
    where id = (select id from public.family_members where family_id = old.family_id order by joined_at limit 1);
  end if;
  if not exists (select 1 from public.family_members where family_id = old.family_id) then
    delete from public.families where id = old.family_id;
  end if;
  return old;
end $$;

-- When an account is deleted: managed profiles with no other guardian go with it; records it
-- entered for other managed profiles move to another guardian, so those profiles keep them.
create or replace function private.handle_account_deletion()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  t text;
begin
  perform set_config('nutrisafe.deleting_user', old.id::text, true);

  delete from public.child_profiles c
  where exists (select 1 from public.guardian_assignments g
                where g.child_id = c.id and g.guardian_id = old.id and g.role = 'guardian')
    and not exists (select 1 from public.guardian_assignments g
                    where g.child_id = c.id and g.guardian_id <> old.id and g.role = 'guardian');

  -- Report files are stored in the deleted account's folder and are removed with it.
  delete from public.medical_reports where owner_id = old.id;

  foreach t in array array[
    'food_diaries', 'meal_entries', 'nutrition_goals', 'allergy_profiles', 'intolerance_profiles',
    'water_logs', 'user_health_goals', 'ai_conversations', 'ai_messages',
    'ai_user_context_permissions', 'user_symptoms', 'symptom_assessments',
    'nutrition_recommendations', 'personalized_meal_plans', 'meal_plan_items',
    'health_progress_logs', 'ai_follow_up_logs', 'ai_safety_events'
  ] loop
    execute format(
      'update public.%I x set owner_id = (
         select g.guardian_id from public.guardian_assignments g
         where g.child_id = x.child_id and g.guardian_id <> $1
         order by (g.role = ''guardian'') desc, g.created_at
         limit 1)
       where x.owner_id = $1 and x.child_id is not null', t)
    using old.id;
  end loop;
  return old;
end $$;
create trigger on_auth_user_deleting before delete on auth.users
  for each row execute function private.handle_account_deletion();

-- ============================================================================ 10. Functions the app calls
drop function public.get_family_members(uuid);
create or replace function public.get_family_members(p_family uuid)
returns table (user_id uuid, role text, full_name text, nutrisafe_id text, avatar_path text, joined_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select m.user_id, m.role, p.full_name, p.nutrisafe_id, p.avatar_path, m.joined_at
  from public.family_members m
  join public.profiles p on p.id = m.user_id
  where m.family_id = p_family and private.is_family_member(p_family)
  order by m.joined_at;
$$;

-- Names and IDs only; health details stay behind each profile's own access rules.
create or replace function public.get_family_managed_profiles(p_family uuid)
returns table (id uuid, full_name text, relationship text, managed_id text, my_role text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select c.id, c.full_name, c.relationship, c.managed_id,
         (select g.role from public.guardian_assignments g
          where g.child_id = c.id and g.guardian_id = (select auth.uid())),
         c.created_at
  from public.child_profiles c
  where c.family_id = p_family and private.is_family_member(p_family)
  order by c.created_at;
$$;

create or replace function public.get_managed_profile_carers(p_child uuid)
returns table (user_id uuid, full_name text, nutrisafe_id text, role text, assigned_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select g.guardian_id, p.full_name, p.nutrisafe_id, g.role, g.created_at
  from public.guardian_assignments g
  join public.profiles p on p.id = g.guardian_id
  where g.child_id = p_child and private.can_care_for(p_child)
  order by (g.role = 'guardian') desc, g.created_at;
$$;

-- Look up an account by NutriSafe ID: name and relation only (no email, phone or internal id).
create or replace function public.find_account_by_nutrisafe_id(p_nutrisafe_id text)
returns table (nutrisafe_code text, display_name text, relation text)
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_code text;
  v_target_id uuid;
  v_target_name text;
  v_family uuid;
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  v_code := private.normalize_nutrisafe_id(p_nutrisafe_id);
  if v_code is null then raise exception 'Enter a NutriSafe ID like NS-84K92P.'; end if;
  perform private.check_rate('family.lookup', 30);

  select p.id, p.full_name into v_target_id, v_target_name
  from public.profiles p where p.nutrisafe_id = v_code;
  if v_target_id is null then return; end if; -- no row = not found

  select m.family_id into v_family from public.family_members m where m.user_id = v_uid;
  perform private.expire_invitations();

  return query select
    v_code,
    coalesce(nullif(trim(v_target_name), ''), 'NutriSafe user'),
    case
      when v_target_id = v_uid then 'self'
      when v_family is not null and exists (
        select 1 from public.family_members m where m.family_id = v_family and m.user_id = v_target_id) then 'member'
      when v_family is not null and exists (
        select 1 from public.family_invitations i
        where i.family_id = v_family and i.invitee_id = v_target_id and i.status = 'pending') then 'invited'
      else 'none'
    end;
end $$;

create or replace function public.invite_to_family(p_nutrisafe_id text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_family uuid;
  v_role text;
  v_code text;
  v_target uuid;
  v_id uuid;
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  select m.family_id, m.role into v_family, v_role from public.family_members m where m.user_id = v_uid;
  if v_family is null then raise exception 'Create a family first.'; end if;
  if v_role <> 'admin' then raise exception 'Only the family admin can add members.'; end if;

  v_code := private.normalize_nutrisafe_id(p_nutrisafe_id);
  if v_code is null then raise exception 'Enter a NutriSafe ID like NS-84K92P.'; end if;
  perform private.check_rate('family.invite', 20);

  select p.id into v_target from public.profiles p where p.nutrisafe_id = v_code;
  if v_target is null then raise exception 'No NutriSafe account has this ID.'; end if;
  if v_target = v_uid then raise exception 'This is your own NutriSafe ID.'; end if;
  if exists (select 1 from public.family_members m where m.family_id = v_family and m.user_id = v_target) then
    raise exception 'This person is already in your family.';
  end if;
  perform private.expire_invitations();
  if exists (select 1 from public.family_invitations i
             where i.family_id = v_family and i.invitee_id = v_target and i.status = 'pending') then
    raise exception 'An invitation to this person is already pending.';
  end if;

  insert into public.family_invitations (family_id, invited_by, invitee_id)
  values (v_family, v_uid, v_target)
  returning id into v_id;
  perform private.notify(v_target, 'You have received a family invitation',
                         'Open Family in NutriSafe to accept or decline it.');
  return v_id;
end $$;

-- Returns the new status: accepted, rejected or expired.
create or replace function public.respond_to_family_invitation(p_invitation uuid, p_accept boolean)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_inv public.family_invitations;
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  select * into v_inv from public.family_invitations i
  where i.id = p_invitation and i.invitee_id = v_uid
  for update;
  if not found then raise exception 'Invitation not found.'; end if;

  if v_inv.status = 'pending' and v_inv.expires_at <= now() then
    update public.family_invitations set status = 'expired', responded_at = now() where id = v_inv.id;
    return 'expired';
  end if;
  if v_inv.status <> 'pending' then raise exception 'This invitation is no longer open.'; end if;

  if p_accept then
    if exists (select 1 from public.family_members m where m.user_id = v_uid) then
      raise exception 'You are already in a family. Leave it before accepting this invitation.';
    end if;
    insert into public.family_members (family_id, user_id, role) values (v_inv.family_id, v_uid, 'member');
    update public.family_invitations set status = 'accepted', responded_at = now() where id = v_inv.id;
    perform private.notify(v_inv.invited_by, 'Your family invitation was accepted',
                           'Open Family in NutriSafe to see your family members.');
    return 'accepted';
  end if;

  update public.family_invitations set status = 'rejected', responded_at = now() where id = v_inv.id;
  perform private.notify(v_inv.invited_by, 'Your family invitation was rejected',
                         'The person you invited declined the invitation.');
  return 'rejected';
end $$;

create or replace function public.revoke_family_invitation(p_invitation uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_inv public.family_invitations;
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  select * into v_inv from public.family_invitations i where i.id = p_invitation for update;
  if not found or not (v_inv.invited_by = v_uid or private.is_family_admin(v_inv.family_id)) then
    raise exception 'Invitation not found.';
  end if;
  if v_inv.status <> 'pending' then raise exception 'This invitation is no longer pending.'; end if;
  update public.family_invitations set status = 'revoked', responded_at = now() where id = v_inv.id;
  perform private.notify(v_inv.invitee_id, 'Your invitation was cancelled',
                         'A family invitation sent to you was cancelled.');
end $$;

create or replace function public.get_my_family_invitations()
returns table (id uuid, family_name text, invited_by_name text, created_at timestamptz, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
  perform private.expire_invitations();
  return query
    select i.id, f.name, coalesce(nullif(trim(p.full_name), ''), 'A NutriSafe user'), i.created_at, i.expires_at
    from public.family_invitations i
    join public.families f on f.id = i.family_id
    left join public.profiles p on p.id = i.invited_by
    where i.invitee_id = (select auth.uid()) and i.status = 'pending'
    order by i.created_at desc;
end $$;

create or replace function public.get_family_invitations()
returns table (id uuid, invitee_name text, invitee_nutrisafe_id text, status text,
               created_at timestamptz, expires_at timestamptz, responded_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  v_family uuid;
begin
  select m.family_id into v_family from public.family_members m
  where m.user_id = (select auth.uid()) and m.role = 'admin';
  if v_family is null then return; end if;
  perform private.expire_invitations();
  return query
    select i.id, coalesce(nullif(trim(p.full_name), ''), 'NutriSafe user'), p.nutrisafe_id, i.status,
           i.created_at, i.expires_at, i.responded_at
    from public.family_invitations i
    join public.profiles p on p.id = i.invitee_id
    where i.family_id = v_family
      and (i.status = 'pending' or coalesce(i.responded_at, i.created_at) > now() - interval '30 days')
    order by i.created_at desc;
end $$;

-- Creates a managed profile (no login, no auth account) with its allergies, in one step.
create or replace function public.create_managed_profile(
  p_full_name text,
  p_date_of_birth date,
  p_gender text default null,
  p_relationship text default null,
  p_dietary_preference text default null,
  p_allergies text[] default '{}',
  p_notes text default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_family uuid;
  v_role text;
  v_id uuid;
  v_allergen text;
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  select m.family_id, m.role into v_family, v_role from public.family_members m where m.user_id = v_uid;
  if v_family is null then raise exception 'Create a family first.'; end if;
  if v_role <> 'admin' then raise exception 'Only the family admin can create managed profiles.'; end if;
  if p_full_name is null or char_length(trim(p_full_name)) not between 1 and 80 then
    raise exception 'Enter a name of up to 80 characters.';
  end if;
  if p_date_of_birth is null or p_date_of_birth > current_date or p_date_of_birth < date '1900-01-01' then
    raise exception 'Enter a valid date of birth.';
  end if;
  perform private.check_rate('family.managed_create', 20);

  insert into public.child_profiles
    (family_id, created_by, full_name, date_of_birth, gender, relationship, dietary_preference, notes)
  values
    (v_family, v_uid, trim(p_full_name), p_date_of_birth, nullif(p_gender, ''), nullif(p_relationship, ''),
     nullif(p_dietary_preference, ''), nullif(trim(coalesce(p_notes, '')), ''))
  returning id into v_id;

  foreach v_allergen in array coalesce(p_allergies, '{}'::text[]) loop
    if char_length(trim(v_allergen)) between 1 and 60 then
      insert into public.allergy_profiles (owner_id, child_id, allergen)
      values (v_uid, v_id, trim(v_allergen))
      on conflict do nothing;
    end if;
  end loop;
  return v_id;
end $$;

-- Day totals for a member's nutrition dashboard (no individual food items).
create or replace function public.get_daily_totals(p_owner uuid, p_child uuid, p_from date, p_to date)
returns table (day date, calories numeric, protein_g numeric, carbs_g numeric, fat_g numeric,
               fiber_g numeric, entries int)
language plpgsql stable security definer set search_path = '' as $$
begin
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 92 then
    raise exception 'Choose a period of up to three months.';
  end if;
  if p_child is not null then
    if not private.can_care_for(p_child) then raise exception 'Not allowed.'; end if;
    return query
      select m.entry_date, sum(m.calories), sum(m.protein_g), sum(m.carbs_g), sum(m.fat_g),
             sum(m.fiber_g), count(*)::int
      from public.meal_entries m
      where m.child_id = p_child and m.entry_date between p_from and p_to
      group by m.entry_date order by m.entry_date;
  else
    if not (p_owner = (select auth.uid())
            or private.has_family_permission(p_owner, 'view_insights')
            or private.has_family_permission(p_owner, 'view_food_diary')) then
      raise exception 'Not allowed.';
    end if;
    return query
      select m.entry_date, sum(m.calories), sum(m.protein_g), sum(m.carbs_g), sum(m.fat_g),
             sum(m.fiber_g), count(*)::int
      from public.meal_entries m
      where m.owner_id = p_owner and m.child_id is null and m.entry_date between p_from and p_to
      group by m.entry_date order by m.entry_date;
  end if;
end $$;

-- ============================================================================ 11. Function permissions
revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.get_family_members(uuid)', 'public.get_family_managed_profiles(uuid)',
    'public.get_managed_profile_carers(uuid)', 'public.find_account_by_nutrisafe_id(text)',
    'public.invite_to_family(text)', 'public.respond_to_family_invitation(uuid, boolean)',
    'public.revoke_family_invitation(uuid)', 'public.get_my_family_invitations()',
    'public.get_family_invitations()',
    'public.create_managed_profile(text, date, text, text, text, text[], text)',
    'public.get_daily_totals(uuid, uuid, date, date)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
