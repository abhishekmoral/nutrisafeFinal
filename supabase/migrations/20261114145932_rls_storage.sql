-- NutriSafe: Row Level Security for every table + private storage buckets.

-- ---------------------------------------------------------------------------
-- Extra helper functions
-- ---------------------------------------------------------------------------
create or replace function private.report_shared_with_me(p_report uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.medical_report_permissions p
    where p.report_id = p_report
      and p.grantee_id = (select auth.uid())
      and private.shares_family_with(p.owner_id)
  );
$$;

create or replace function private.can_write_report(p_report uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.medical_reports r
    where r.id = p_report and private.can_access(r.owner_id, r.child_id)
  );
$$;

create or replace function private.can_read_report(p_report uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.can_write_report(p_report) or private.report_shared_with_me(p_report);
$$;

-- A new guardian must belong to the child's family.
create or replace function private.can_be_guardian(p_child uuid, p_guardian uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.child_profiles c
    where c.id = p_child
      and c.family_id is not null
      and private.user_in_family(p_guardian, c.family_id)
  );
$$;

-- A record keeps the owner (and child) it was created with.
create or replace function private.prevent_owner_change()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.owner_id is distinct from old.owner_id or new.child_id is distinct from old.child_id then
    raise exception 'The owner of a record cannot be changed';
  end if;
  return new;
end $$;

-- Leaving / being removed from a family revokes everything shared inside it.
create or replace function private.handle_family_member_removed()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
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
  return old;
end $$;
create trigger on_family_member_removed after delete on public.family_members
  for each row execute function private.handle_family_member_removed();

revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;

-- ---------------------------------------------------------------------------
-- Enable RLS everywhere
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Accounts
-- ---------------------------------------------------------------------------
create policy profiles_select_own on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy profiles_insert_own on public.profiles for insert to authenticated
  with check (id = (select auth.uid()));
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy user_settings_own on public.user_settings for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy user_consents_select_own on public.user_consents for select to authenticated
  using (user_id = (select auth.uid()));
create policy user_consents_insert_own on public.user_consents for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy user_consents_update_own on public.user_consents for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Family
-- ---------------------------------------------------------------------------
create policy families_select on public.families for select to authenticated
  using (private.is_family_member(id) or created_by = (select auth.uid()));
create policy families_insert on public.families for insert to authenticated
  with check (created_by = (select auth.uid()));
create policy families_update on public.families for update to authenticated
  using (private.is_family_admin(id)) with check (private.is_family_admin(id));
create policy families_delete on public.families for delete to authenticated
  using (private.is_family_admin(id));

-- Membership rows are created only by triggers / join_family(); no insert or update policy.
create policy family_members_select on public.family_members for select to authenticated
  using (private.is_family_member(family_id));
create policy family_members_delete on public.family_members for delete to authenticated
  using (user_id = (select auth.uid()) or private.is_family_admin(family_id));

create policy child_profiles_select on public.child_profiles for select to authenticated
  using (private.is_guardian(id) or created_by = (select auth.uid()));
create policy child_profiles_insert on public.child_profiles for insert to authenticated
  with check (created_by = (select auth.uid())
    and (family_id is null or private.is_family_member(family_id)));
create policy child_profiles_update on public.child_profiles for update to authenticated
  using (private.is_guardian(id))
  with check (private.is_guardian(id)
    and (family_id is null or private.is_family_member(family_id)));
create policy child_profiles_delete on public.child_profiles for delete to authenticated
  using (private.is_guardian(id));

create policy guardian_assignments_select on public.guardian_assignments for select to authenticated
  using (guardian_id = (select auth.uid()) or private.is_guardian(child_id));
create policy guardian_assignments_insert on public.guardian_assignments for insert to authenticated
  with check (private.is_guardian(child_id)
    and assigned_by = (select auth.uid())
    and private.can_be_guardian(child_id, guardian_id));
create policy guardian_assignments_delete on public.guardian_assignments for delete to authenticated
  using (private.is_guardian(child_id));

create policy family_permissions_select on public.family_permissions for select to authenticated
  using (owner_id = (select auth.uid()) or grantee_id = (select auth.uid()));
create policy family_permissions_insert on public.family_permissions for insert to authenticated
  with check (owner_id = (select auth.uid())
    and private.is_family_member(family_id)
    and private.user_in_family(grantee_id, family_id));
create policy family_permissions_delete on public.family_permissions for delete to authenticated
  using (owner_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- User-owned health tables: the adult themself, or an assigned guardian for child rows
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
  owner_tables text[] := array[
    'food_diaries', 'meal_entries', 'nutrition_goals', 'allergy_profiles', 'intolerance_profiles',
    'water_logs', 'user_health_goals', 'ai_conversations', 'ai_messages',
    'ai_user_context_permissions', 'user_symptoms', 'symptom_assessments',
    'nutrition_recommendations', 'personalized_meal_plans', 'meal_plan_items',
    'health_progress_logs', 'ai_follow_up_logs'
  ];
begin
  foreach t in array owner_tables loop
    execute format(
      'create policy %I on public.%I for all to authenticated
         using (private.can_access(owner_id, child_id))
         with check (private.can_access(owner_id, child_id))',
      t || '_owner_access', t);
    -- New rows are always created in the name of the signed-in user, also for child records.
    execute format(
      'create policy %I on public.%I as restrictive for insert to authenticated
         with check (owner_id = (select auth.uid()))',
      t || '_insert_as_self', t);
  end loop;

  -- The owner and child of an existing record can never be changed.
  foreach t in array owner_tables || array['ai_safety_events', 'medical_reports'] loop
    execute format(
      'create trigger %I before update of owner_id, child_id on public.%I
         for each row execute function private.prevent_owner_change()',
      t || '_owner_immutable', t);
  end loop;
end $$;

-- Safety events are append-only for the user.
create policy ai_safety_events_select on public.ai_safety_events for select to authenticated
  using (private.can_access(owner_id, child_id));
create policy ai_safety_events_insert on public.ai_safety_events for insert to authenticated
  with check (owner_id = (select auth.uid()) and private.can_access(owner_id, child_id));

-- Read-only access for adults the owner explicitly shared with (never child rows, never reports).
create policy food_diaries_shared_read on public.food_diaries for select to authenticated
  using (child_id is null and private.has_family_permission(owner_id, 'food_diary'));
create policy meal_entries_shared_read on public.meal_entries for select to authenticated
  using (child_id is null and private.has_family_permission(owner_id, 'food_diary'));
create policy water_logs_shared_read on public.water_logs for select to authenticated
  using (child_id is null and private.has_family_permission(owner_id, 'food_diary'));
create policy nutrition_goals_shared_read on public.nutrition_goals for select to authenticated
  using (child_id is null and private.has_family_permission(owner_id, 'nutrition_insights'));

-- ---------------------------------------------------------------------------
-- Food catalog: curated rows (created_by is null) are readable by everyone signed in;
-- user-submitted rows stay private to their creator and can never be marked verified.
-- ---------------------------------------------------------------------------
create policy foods_select on public.foods for select to authenticated
  using (created_by is null or created_by = (select auth.uid()));
create policy foods_insert on public.foods for insert to authenticated
  with check (created_by = (select auth.uid()) and is_verified = false);
create policy foods_update on public.foods for update to authenticated
  using (created_by = (select auth.uid()))
  with check (created_by = (select auth.uid()) and is_verified = false);
create policy foods_delete on public.foods for delete to authenticated
  using (created_by = (select auth.uid()));

create policy food_products_select on public.food_products for select to authenticated
  using (created_by is null or created_by = (select auth.uid()));
create policy food_products_insert on public.food_products for insert to authenticated
  with check (created_by = (select auth.uid()) and source <> 'curated');
create policy food_products_update on public.food_products for update to authenticated
  using (created_by = (select auth.uid()))
  with check (created_by = (select auth.uid()) and source <> 'curated');
create policy food_products_delete on public.food_products for delete to authenticated
  using (created_by = (select auth.uid()));

create policy food_ingredients_select on public.food_ingredients for select to authenticated
  using (exists (select 1 from public.food_products p where p.id = product_id));
create policy food_ingredients_write on public.food_ingredients for all to authenticated
  using (exists (select 1 from public.food_products p
                 where p.id = product_id and p.created_by = (select auth.uid())))
  with check (exists (select 1 from public.food_products p
                      where p.id = product_id and p.created_by = (select auth.uid())));

create policy food_nutrition_select on public.food_nutrition for select to authenticated
  using (created_by is null or created_by = (select auth.uid()));
create policy food_nutrition_insert on public.food_nutrition for insert to authenticated
  with check (created_by = (select auth.uid()));
create policy food_nutrition_update on public.food_nutrition for update to authenticated
  using (created_by = (select auth.uid())) with check (created_by = (select auth.uid()));
create policy food_nutrition_delete on public.food_nutrition for delete to authenticated
  using (created_by = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Medical reports: private by default, shared only per report
-- ---------------------------------------------------------------------------
create policy medical_reports_select on public.medical_reports for select to authenticated
  using (private.can_access(owner_id, child_id) or private.report_shared_with_me(id));
create policy medical_reports_insert on public.medical_reports for insert to authenticated
  with check (owner_id = (select auth.uid()) and private.can_access(owner_id, child_id));
create policy medical_reports_update on public.medical_reports for update to authenticated
  using (private.can_access(owner_id, child_id))
  with check (private.can_access(owner_id, child_id));
create policy medical_reports_delete on public.medical_reports for delete to authenticated
  using (private.can_access(owner_id, child_id));

create policy medical_report_results_select on public.medical_report_results for select to authenticated
  using (private.can_read_report(report_id));
create policy medical_report_results_write on public.medical_report_results for all to authenticated
  using (private.can_write_report(report_id)) with check (private.can_write_report(report_id));

create policy medical_report_analyses_select on public.medical_report_analyses for select to authenticated
  using (private.can_read_report(report_id));
create policy medical_report_analyses_write on public.medical_report_analyses for all to authenticated
  using (private.can_write_report(report_id)) with check (private.can_write_report(report_id));

create policy medical_report_permissions_select on public.medical_report_permissions for select to authenticated
  using (owner_id = (select auth.uid()) or grantee_id = (select auth.uid()));
create policy medical_report_permissions_insert on public.medical_report_permissions for insert to authenticated
  with check (owner_id = (select auth.uid())
    and private.shares_family_with(grantee_id)
    and exists (select 1 from public.medical_reports r
                where r.id = report_id and r.owner_id = (select auth.uid()) and r.child_id is null));
create policy medical_report_permissions_delete on public.medical_report_permissions for delete to authenticated
  using (owner_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Application tables
-- ---------------------------------------------------------------------------
create policy notifications_own on public.notifications for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy notification_preferences_own on public.notification_preferences for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy audit_logs_select_own on public.audit_logs for select to authenticated
  using (actor_id = (select auth.uid()));
create policy audit_logs_insert_own on public.audit_logs for insert to authenticated
  with check (actor_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Table privileges: signed-in users only (RLS decides which rows); nothing for anonymous callers.
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- Columns that must never be edited directly (creator, invite code, ids).
revoke update on public.families from authenticated;
grant update (name) on public.families to authenticated;
revoke update on public.child_profiles from authenticated;
grant update (family_id, full_name, date_of_birth, gender, height_cm, weight_kg,
              dietary_preference, avatar_path)
  on public.child_profiles to authenticated;

-- ---------------------------------------------------------------------------
-- Private storage buckets. Object names start with the uploader's user id: "<uid>/<file>".
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('medical-reports', 'medical-reports', false, 10485760,
   array['application/pdf', 'image/jpeg', 'image/png']),
  ('avatars', 'avatars', false, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy medical_reports_files_owner on storage.objects for all to authenticated
  using (bucket_id = 'medical-reports'
    and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'medical-reports'
    and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Co-guardians and adults the report was explicitly shared with can read the file.
create policy medical_reports_files_shared_read on storage.objects for select to authenticated
  using (bucket_id = 'medical-reports'
    and exists (select 1 from public.medical_reports r where r.storage_path = objects.name));

create policy avatars_files_owner on storage.objects for all to authenticated
  using (bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text);
