-- One SELECT policy per table. Behaviour is unchanged; this only merges policies that were
-- evaluated side by side (Supabase performance advisor: multiple permissive policies).

-- Diary-type tables: the owner / guardian, or an adult the owner explicitly shared with.
do $$
declare
  t text;
  scope text;
begin
  foreach t in array array['food_diaries', 'meal_entries', 'water_logs', 'nutrition_goals'] loop
    scope := case when t = 'nutrition_goals' then 'nutrition_insights' else 'food_diary' end;
    execute format('drop policy %I on public.%I', t || '_owner_access', t);
    execute format('drop policy %I on public.%I', t || '_shared_read', t);
    execute format(
      'create policy %I on public.%I for select to authenticated
         using (private.can_access(owner_id, child_id)
                or (child_id is null and private.has_family_permission(owner_id, %L)))',
      t || '_select', t, scope);
    execute format(
      'create policy %I on public.%I for insert to authenticated
         with check (private.can_access(owner_id, child_id))',
      t || '_insert', t);
    execute format(
      'create policy %I on public.%I for update to authenticated
         using (private.can_access(owner_id, child_id))
         with check (private.can_access(owner_id, child_id))',
      t || '_update', t);
    execute format(
      'create policy %I on public.%I for delete to authenticated
         using (private.can_access(owner_id, child_id))',
      t || '_delete', t);
  end loop;
end $$;

-- Ingredients of a product: readable with the product, writable only by the product's creator.
drop policy food_ingredients_write on public.food_ingredients;
create policy food_ingredients_insert on public.food_ingredients for insert to authenticated
  with check (exists (select 1 from public.food_products p
                      where p.id = product_id and p.created_by = (select auth.uid())));
create policy food_ingredients_update on public.food_ingredients for update to authenticated
  using (exists (select 1 from public.food_products p
                 where p.id = product_id and p.created_by = (select auth.uid())))
  with check (exists (select 1 from public.food_products p
                      where p.id = product_id and p.created_by = (select auth.uid())));
create policy food_ingredients_delete on public.food_ingredients for delete to authenticated
  using (exists (select 1 from public.food_products p
                 where p.id = product_id and p.created_by = (select auth.uid())));

-- Report results and analyses: readable by anyone who may read the report, writable by its owner.
drop policy medical_report_results_write on public.medical_report_results;
create policy medical_report_results_insert on public.medical_report_results for insert to authenticated
  with check (private.can_write_report(report_id));
create policy medical_report_results_update on public.medical_report_results for update to authenticated
  using (private.can_write_report(report_id)) with check (private.can_write_report(report_id));
create policy medical_report_results_delete on public.medical_report_results for delete to authenticated
  using (private.can_write_report(report_id));

drop policy medical_report_analyses_write on public.medical_report_analyses;
create policy medical_report_analyses_insert on public.medical_report_analyses for insert to authenticated
  with check (private.can_write_report(report_id));
create policy medical_report_analyses_update on public.medical_report_analyses for update to authenticated
  using (private.can_write_report(report_id)) with check (private.can_write_report(report_id));
create policy medical_report_analyses_delete on public.medical_report_analyses for delete to authenticated
  using (private.can_write_report(report_id));
