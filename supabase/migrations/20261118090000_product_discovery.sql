-- Product discovery: several product databases, package-label reading, and where every value came from.
--
-- 1. food_products keeps one confirmed copy per person per barcode (it was one row per barcode for everyone).
-- 2. Each saved product records the source, original value and verification status of every field.
-- 3. product_lookup_cache keeps answers from the outside databases so the same barcode is not fetched again
--    and again. Only the product-lookup Edge Function (server key) reads and writes it.
-- 4. Rows people create are deleted with their account. Before, they were kept with created_by = null,
--    which made them look like curated rows that everyone can read.

-- ---------------------------------------------------------------------------
-- 1. One saved product per person per barcode
-- ---------------------------------------------------------------------------
alter table public.food_products drop constraint food_products_barcode_key;
create unique index food_products_owner_barcode_key
  on public.food_products (created_by, barcode) nulls not distinct
  where barcode is not null;
create index food_products_barcode_idx on public.food_products (barcode);

-- ---------------------------------------------------------------------------
-- 2. More sources, more label fields, and the history of every field
-- ---------------------------------------------------------------------------
alter table public.food_products drop constraint food_products_source_check;
alter table public.food_products add constraint food_products_source_check check (source in (
  'open_food_facts', 'usda_fdc', 'nutritionix', 'fatsecret', 'manufacturer', 'label_ocr',
  'multiple', 'user', 'curated'));

alter table public.food_products
  add column net_quantity text,
  add column may_contain text[] not null default '{}',
  add column field_sources jsonb not null default '{}'::jsonb,
  add column verification_status text not null default 'user_confirmed'
    check (verification_status in ('user_confirmed', 'verified')),
  add column updated_at timestamptz not null default now();

comment on column public.food_products.net_quantity is 'Net quantity printed on the pack, e.g. "250 g".';
comment on column public.food_products.may_contain is 'Allergens from "may contain" / "traces of" statements.';
comment on column public.food_products.field_sources is
  'Per field: {"source", "original", "status", "confidence"}. status is user_confirmed (kept as found) or user_edited.';
comment on column public.food_products.verification_status is
  'user_confirmed = checked by the person who saved it; verified = checked against official manufacturer data (curated rows only).';

create trigger food_products_updated_at before update on public.food_products
  for each row execute function private.set_updated_at();

-- People can save their own products but never mark them verified or curated.
drop policy food_products_insert on public.food_products;
create policy food_products_insert on public.food_products for insert to authenticated
  with check (created_by = (select auth.uid()) and source <> 'curated' and verification_status = 'user_confirmed');
drop policy food_products_update on public.food_products;
create policy food_products_update on public.food_products for update to authenticated
  using (created_by = (select auth.uid()))
  with check (created_by = (select auth.uid()) and source <> 'curated' and verification_status = 'user_confirmed');

-- ---------------------------------------------------------------------------
-- 3. Cache of outside product databases (server only)
-- ---------------------------------------------------------------------------
create table public.product_lookup_cache (
  barcode text primary key,              -- GTIN-13 (UPC-A codes get a leading zero)
  found boolean not null,
  candidates jsonb not null default '[]'::jsonb, -- one normalised record per database that knew the barcode
  providers jsonb not null default '[]'::jsonb,  -- what each database answered
  fetched_at timestamptz not null default now(),
  expires_at timestamptz not null
);
comment on table public.product_lookup_cache is
  'Answers of outside product databases per barcode. Read and written only by the product-lookup Edge Function.';
-- RLS on with no policies: the app cannot read or change it; the server key can.
alter table public.product_lookup_cache enable row level security;
create index product_lookup_cache_expires_idx on public.product_lookup_cache (expires_at);

-- ---------------------------------------------------------------------------
-- 4. Rows people create go with their account
-- ---------------------------------------------------------------------------
delete from public.food_nutrition n where n.created_by is null and n.product_id is not null
  and exists (select 1 from public.food_products p where p.id = n.product_id and p.created_by is not null);

alter table public.food_products drop constraint food_products_created_by_fkey,
  add constraint food_products_created_by_fkey foreign key (created_by) references auth.users (id) on delete cascade;
alter table public.food_nutrition drop constraint food_nutrition_created_by_fkey,
  add constraint food_nutrition_created_by_fkey foreign key (created_by) references auth.users (id) on delete cascade;
alter table public.foods drop constraint foods_created_by_fkey,
  add constraint foods_created_by_fkey foreign key (created_by) references auth.users (id) on delete cascade;

-- ---------------------------------------------------------------------------
-- 5. Save a product the person checked, in one step (product + nutrition)
-- ---------------------------------------------------------------------------
create or replace function public.save_confirmed_product(p jsonb)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  v_id uuid;
  n jsonb := coalesce(p -> 'nutrition', '{}'::jsonb);
  v_barcode text := nullif(trim(p ->> 'barcode'), '');
  v_name text := nullif(trim(p ->> 'name'), '');
  v_basis text := coalesce(n ->> 'basis', 'per_100g');
begin
  if uid is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;
  if v_name is null then
    raise exception 'Enter the product name.' using errcode = 'P0001';
  end if;
  if v_barcode is not null and v_barcode !~ '^[0-9]{8,14}$' then
    raise exception 'The barcode is not valid.' using errcode = 'P0001';
  end if;
  if v_basis not in ('per_100g', 'per_100ml', 'per_serving', 'per_package') then
    raise exception 'The nutrition basis is not valid.' using errcode = 'P0001';
  end if;

  insert into public.food_products as fp (
    barcode, name, brand, net_quantity, serving_size, serving_unit, image_url,
    allergens, may_contain, ingredients_text, source, field_sources, verification_status, created_by)
  values (
    v_barcode, v_name,
    nullif(trim(p ->> 'brand'), ''),
    nullif(trim(p ->> 'net_quantity'), ''),
    nullif(p ->> 'serving_size', '')::numeric,
    nullif(trim(p ->> 'serving_unit'), ''),
    nullif(trim(p ->> 'image_url'), ''),
    coalesce(array(select jsonb_array_elements_text(coalesce(p -> 'allergens', '[]'::jsonb))), '{}'),
    coalesce(array(select jsonb_array_elements_text(coalesce(p -> 'may_contain', '[]'::jsonb))), '{}'),
    nullif(trim(p ->> 'ingredients_text'), ''),
    coalesce(p ->> 'source', 'user'),
    coalesce(p -> 'field_sources', '{}'::jsonb),
    'user_confirmed',
    uid)
  on conflict (created_by, barcode) where barcode is not null do update set
    name = excluded.name, brand = excluded.brand, net_quantity = excluded.net_quantity,
    serving_size = excluded.serving_size, serving_unit = excluded.serving_unit, image_url = excluded.image_url,
    allergens = excluded.allergens, may_contain = excluded.may_contain,
    ingredients_text = excluded.ingredients_text, source = excluded.source,
    field_sources = excluded.field_sources
  returning fp.id into v_id;

  delete from public.food_nutrition fn where fn.product_id = v_id;
  insert into public.food_nutrition (
    product_id, basis, basis_quantity, basis_unit, calories, protein_g, carbs_g, fat_g,
    saturated_fat_g, fiber_g, sugar_g, sodium_mg, source, created_by)
  values (
    v_id, v_basis,
    nullif(n ->> 'basis_quantity', '')::numeric,
    nullif(n ->> 'basis_unit', ''),
    nullif(n ->> 'calories', '')::numeric,
    nullif(n ->> 'protein_g', '')::numeric,
    nullif(n ->> 'carbs_g', '')::numeric,
    nullif(n ->> 'fat_g', '')::numeric,
    nullif(n ->> 'saturated_fat_g', '')::numeric,
    nullif(n ->> 'fiber_g', '')::numeric,
    nullif(n ->> 'sugar_g', '')::numeric,
    nullif(n ->> 'sodium_mg', '')::numeric,
    nullif(n ->> 'source', ''),
    uid);

  return v_id;
end;
$$;

revoke execute on function public.save_confirmed_product(jsonb) from public, anon;
grant execute on function public.save_confirmed_product(jsonb) to authenticated;
