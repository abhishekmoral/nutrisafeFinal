-- NutriSafe: core accounts, family, consent and settings tables.
-- Helper functions live in the `private` schema so they are not callable through the API.

create schema if not exists private;
grant usage on schema private to authenticated;

create or replace function private.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  date_of_birth date,
  gender text check (gender in ('male', 'female', 'other', 'prefer_not_to_say')),
  height_cm numeric(5, 1) check (height_cm between 30 and 272),
  weight_kg numeric(5, 1) check (weight_kg between 1 and 500),
  activity_level text check (activity_level in ('sedentary', 'light', 'moderate', 'active')),
  dietary_preference text check (dietary_preference in
    ('vegetarian', 'non_vegetarian', 'vegan', 'eggetarian', 'jain', 'pescatarian', 'other')),
  location text,
  avatar_path text,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger profiles_updated_at before update on public.profiles
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------
-- user_settings / user_consents
-- ---------------------------------------------------------------------------
create table public.user_settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  preferred_language text not null default 'en' check (preferred_language in
    ('en', 'hi', 'hinglish', 'bn', 'ta', 'te', 'mr', 'gu', 'pa', 'ur', 'kn', 'ml')),
  auto_detect_language boolean not null default true,
  voice_response boolean not null default false,
  save_ai_history boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger user_settings_updated_at before update on public.user_settings
  for each row execute function private.set_updated_at();

create table public.user_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  consent_type text not null check (consent_type in
    ('terms', 'privacy_policy', 'health_data_processing', 'ai_processing', 'analytics')),
  version text not null default '1',
  granted boolean not null,
  granted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, consent_type, version)
);

-- ---------------------------------------------------------------------------
-- families
-- ---------------------------------------------------------------------------
create table public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  created_by uuid not null references auth.users (id) on delete cascade,
  invite_code text not null unique
    default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index families_created_by_idx on public.families (created_by);
create trigger families_updated_at before update on public.families
  for each row execute function private.set_updated_at();

create table public.family_members (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('admin', 'member')),
  joined_at timestamptz not null default now(),
  unique (family_id, user_id)
);
create index family_members_user_idx on public.family_members (user_id);

create table public.child_profiles (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references public.families (id) on delete set null,
  created_by uuid not null references auth.users (id) on delete cascade,
  full_name text not null check (char_length(full_name) between 1 and 80),
  date_of_birth date,
  gender text check (gender in ('male', 'female', 'other', 'prefer_not_to_say')),
  height_cm numeric(5, 1) check (height_cm between 30 and 272),
  weight_kg numeric(5, 1) check (weight_kg between 1 and 500),
  dietary_preference text,
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index child_profiles_family_idx on public.child_profiles (family_id);
create index child_profiles_created_by_idx on public.child_profiles (created_by);
create trigger child_profiles_updated_at before update on public.child_profiles
  for each row execute function private.set_updated_at();

create table public.guardian_assignments (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.child_profiles (id) on delete cascade,
  guardian_id uuid not null references auth.users (id) on delete cascade,
  assigned_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (child_id, guardian_id)
);
create index guardian_assignments_guardian_idx on public.guardian_assignments (guardian_id);
create index guardian_assignments_assigned_by_idx on public.guardian_assignments (assigned_by);

-- Adult-to-adult sharing of non-medical data. Medical reports use medical_report_permissions.
create table public.family_permissions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  owner_id uuid not null references auth.users (id) on delete cascade,
  grantee_id uuid not null references auth.users (id) on delete cascade,
  scope text not null check (scope in ('food_diary', 'nutrition_insights')),
  created_at timestamptz not null default now(),
  unique (owner_id, grantee_id, scope),
  check (owner_id <> grantee_id)
);
create index family_permissions_grantee_idx on public.family_permissions (grantee_id);
create index family_permissions_family_idx on public.family_permissions (family_id);

-- ---------------------------------------------------------------------------
-- Access helper functions (security definer so RLS policies can call them
-- without recursing into the tables they protect)
-- ---------------------------------------------------------------------------
create or replace function private.is_family_member(p_family uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.family_members m
    where m.family_id = p_family and m.user_id = (select auth.uid())
  );
$$;

create or replace function private.is_family_admin(p_family uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.family_members m
    where m.family_id = p_family and m.user_id = (select auth.uid()) and m.role = 'admin'
  );
$$;

create or replace function private.user_in_family(p_user uuid, p_family uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.family_members m
    where m.family_id = p_family and m.user_id = p_user
  );
$$;

create or replace function private.shares_family_with(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.family_members me
    join public.family_members them on them.family_id = me.family_id
    where me.user_id = (select auth.uid()) and them.user_id = p_user
  );
$$;

create or replace function private.is_guardian(p_child uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.guardian_assignments g
    where g.child_id = p_child and g.guardian_id = (select auth.uid())
  );
$$;

-- Owner access to a health record: the adult themself, or an assigned guardian for a child row.
create or replace function private.can_access(p_owner uuid, p_child uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when p_child is null then p_owner = (select auth.uid())
    else private.is_guardian(p_child)
  end;
$$;

-- True when p_owner has shared `p_scope` with the caller and both are still in that family.
create or replace function private.has_family_permission(p_owner uuid, p_scope text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.family_permissions fp
    where fp.owner_id = p_owner
      and fp.grantee_id = (select auth.uid())
      and fp.scope = p_scope
      and private.user_in_family(fp.owner_id, fp.family_id)
      and private.user_in_family(fp.grantee_id, fp.family_id)
  );
$$;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------
-- New auth user -> profile + settings rows.
create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'));
  insert into public.user_settings (user_id) values (new.id);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

-- Family creator becomes its admin.
create or replace function private.handle_new_family()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.family_members (family_id, user_id, role)
  values (new.id, new.created_by, 'admin');
  return new;
end $$;
create trigger on_family_created after insert on public.families
  for each row execute function private.handle_new_family();

-- Child creator becomes its first guardian.
create or replace function private.handle_new_child()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.guardian_assignments (child_id, guardian_id, assigned_by)
  values (new.id, new.created_by, new.created_by);
  return new;
end $$;
create trigger on_child_created after insert on public.child_profiles
  for each row execute function private.handle_new_child();

-- A child must always keep at least one guardian (unless the child itself is being deleted).
create or replace function private.prevent_last_guardian_removal()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.child_profiles c where c.id = old.child_id)
     and exists (select 1 from auth.users u where u.id = old.guardian_id)
     and not exists (
       select 1 from public.guardian_assignments g
       where g.child_id = old.child_id and g.id <> old.id
     ) then
    raise exception 'A child profile must have at least one guardian';
  end if;
  return old;
end $$;
create trigger guardian_keep_one before delete on public.guardian_assignments
  for each row execute function private.prevent_last_guardian_removal();

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------
create or replace function public.join_family(p_invite_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_family uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  select f.id into v_family from public.families f
  where f.invite_code = upper(trim(p_invite_code));
  if v_family is null then
    raise exception 'Invalid invite code';
  end if;
  insert into public.family_members (family_id, user_id, role)
  values (v_family, (select auth.uid()), 'member')
  on conflict (family_id, user_id) do nothing;
  return v_family;
end $$;

create or replace function public.regenerate_invite_code(p_family uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_code text;
begin
  if not private.is_family_admin(p_family) then
    raise exception 'Only the family admin can do this';
  end if;
  update public.families
  set invite_code = upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
  where id = p_family
  returning invite_code into v_code;
  return v_code;
end $$;

-- Family roster: names and avatars only, never health fields.
create or replace function public.get_family_members(p_family uuid)
returns table (user_id uuid, role text, full_name text, avatar_path text, joined_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select m.user_id, m.role, p.full_name, p.avatar_path, m.joined_at
  from public.family_members m
  join public.profiles p on p.id = m.user_id
  where m.family_id = p_family and private.is_family_member(p_family)
  order by m.joined_at;
$$;

revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;
revoke execute on function public.join_family(text) from public, anon;
revoke execute on function public.regenerate_invite_code(uuid) from public, anon;
revoke execute on function public.get_family_members(uuid) from public, anon;
grant execute on function public.join_family(text) to authenticated;
grant execute on function public.regenerate_invite_code(uuid) to authenticated;
grant execute on function public.get_family_members(uuid) to authenticated;
