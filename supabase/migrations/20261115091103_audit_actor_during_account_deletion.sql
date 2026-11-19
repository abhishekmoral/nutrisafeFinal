-- While an account is being deleted, it cannot be recorded as the actor of the changes
-- that the deletion causes (its row is already gone).
create or replace function private.audit_family_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_row jsonb;
  v_actor uuid := (select auth.uid());
begin
  if v_actor::text = coalesce(current_setting('nutrisafe.deleting_user', true), '') then
    v_actor := null;
  end if;
  if TG_OP = 'DELETE' then
    v_row := to_jsonb(old);
  else
    v_row := to_jsonb(new);
  end if;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    v_actor,
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
