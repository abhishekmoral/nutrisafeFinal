-- Food catalog: words that find a food (English, Hinglish, Hindi) and where its numbers come from.
alter table public.foods
  add column search_terms text not null default '',
  add column source text,
  add column source_ref text;

comment on column public.foods.search_terms is 'Extra words that find this food: English, Hinglish and Hindi names.';
comment on column public.foods.source is 'Where the nutrition values come from, e.g. USDA FoodData Central.';
comment on column public.foods.source_ref is 'Id of the food in that source (dataset prefix + FDC id).';

-- One curated row per source food; lets the seed be re-run safely.
create unique index foods_curated_source_ref_key on public.foods (source_ref) where created_by is null;
