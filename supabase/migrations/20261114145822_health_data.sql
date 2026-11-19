-- NutriSafe: food, nutrition, AI agent, medical report and application tables.
-- Convention for user-owned health rows:
--   owner_id = the adult account that owns/created the row
--   child_id = set when the row is about a dependent child profile (null = the adult's own data)

-- ---------------------------------------------------------------------------
-- Food catalog
-- ---------------------------------------------------------------------------
create table public.foods (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  local_names jsonb not null default '{}'::jsonb,
  category text,
  default_unit text not null default 'g',
  unit_weights jsonb not null default '{}'::jsonb, -- e.g. {"piece": 40, "katori": 150} in grams
  region text,
  is_verified boolean not null default false,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
create index foods_name_idx on public.foods (lower(name) text_pattern_ops);
create index foods_created_by_idx on public.foods (created_by);

create table public.food_products (
  id uuid primary key default gen_random_uuid(),
  barcode text unique,
  name text not null,
  brand text,
  serving_size numeric check (serving_size > 0),
  serving_unit text,
  image_url text,
  allergens text[] not null default '{}',
  ingredients_text text,
  source text not null default 'user' check (source in ('open_food_facts', 'user', 'curated')),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
create index food_products_created_by_idx on public.food_products (created_by);

create table public.food_ingredients (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.food_products (id) on delete cascade,
  name text not null,
  kind text not null default 'ingredient'
    check (kind in ('ingredient', 'additive', 'sweetener', 'preservative')),
  allergen_tag text,
  position int,
  created_at timestamptz not null default now()
);
create index food_ingredients_product_idx on public.food_ingredients (product_id);

-- Every nutrient is nullable: an unknown value stays NULL, it is never guessed.
create table public.food_nutrition (
  id uuid primary key default gen_random_uuid(),
  food_id uuid references public.foods (id) on delete cascade,
  product_id uuid references public.food_products (id) on delete cascade,
  basis text not null check (basis in ('per_100g', 'per_100ml', 'per_serving', 'per_package')),
  basis_quantity numeric check (basis_quantity > 0),
  basis_unit text,
  calories numeric check (calories >= 0),
  protein_g numeric check (protein_g >= 0),
  carbs_g numeric check (carbs_g >= 0),
  fat_g numeric check (fat_g >= 0),
  saturated_fat_g numeric check (saturated_fat_g >= 0),
  fiber_g numeric check (fiber_g >= 0),
  sugar_g numeric check (sugar_g >= 0),
  sodium_mg numeric check (sodium_mg >= 0),
  source text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  check (num_nonnulls(food_id, product_id) = 1)
);
create index food_nutrition_food_idx on public.food_nutrition (food_id);
create index food_nutrition_product_idx on public.food_nutrition (product_id);
create index food_nutrition_created_by_idx on public.food_nutrition (created_by);

-- ---------------------------------------------------------------------------
-- Food diary
-- ---------------------------------------------------------------------------
create table public.food_diaries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  diary_date date not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (owner_id, child_id, diary_date)
);
create index food_diaries_child_idx on public.food_diaries (child_id, diary_date);
create trigger food_diaries_updated_at before update on public.food_diaries
  for each row execute function private.set_updated_at();

create table public.meal_entries (
  id uuid primary key default gen_random_uuid(),
  diary_id uuid not null references public.food_diaries (id) on delete cascade,
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  entry_date date not null, -- the user's local calendar date
  meal_type text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  food_id uuid references public.foods (id) on delete set null,
  product_id uuid references public.food_products (id) on delete set null,
  food_name text not null,
  quantity numeric not null check (quantity > 0),
  unit text not null,
  consumed_at timestamptz not null default now(),
  calories numeric check (calories >= 0),
  protein_g numeric check (protein_g >= 0),
  carbs_g numeric check (carbs_g >= 0),
  fat_g numeric check (fat_g >= 0),
  saturated_fat_g numeric check (saturated_fat_g >= 0),
  fiber_g numeric check (fiber_g >= 0),
  sugar_g numeric check (sugar_g >= 0),
  sodium_mg numeric check (sodium_mg >= 0),
  entry_source text not null default 'manual' check (entry_source in
    ('manual', 'barcode', 'label_ocr', 'catalog', 'ai_image', 'meal_plan', 'voice', 'ai_chat')),
  nutrition_quality text not null default 'estimated' check (nutrition_quality in
    ('verified', 'calculated', 'estimated', 'user_entered', 'unknown')),
  client_entry_id uuid, -- idempotency key from the app, prevents duplicate saves
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, client_entry_id)
);
create index meal_entries_owner_date_idx on public.meal_entries (owner_id, entry_date);
create index meal_entries_child_date_idx on public.meal_entries (child_id, entry_date);
create index meal_entries_diary_idx on public.meal_entries (diary_id);
create index meal_entries_food_idx on public.meal_entries (food_id);
create index meal_entries_product_idx on public.meal_entries (product_id);
create trigger meal_entries_updated_at before update on public.meal_entries
  for each row execute function private.set_updated_at();

-- Attach each entry to its day's diary, creating the diary row when needed.
create or replace function private.attach_meal_entry_diary()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.diary_id is null then
    insert into public.food_diaries (owner_id, child_id, diary_date)
    values (new.owner_id, new.child_id, new.entry_date)
    on conflict (owner_id, child_id, diary_date) do update set updated_at = now()
    returning id into new.diary_id;
  end if;
  return new;
end $$;
create trigger meal_entries_attach_diary before insert on public.meal_entries
  for each row execute function private.attach_meal_entry_diary();

create table public.nutrition_goals (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  calories numeric check (calories > 0),
  protein_g numeric check (protein_g >= 0),
  carbs_g numeric check (carbs_g >= 0),
  fat_g numeric check (fat_g >= 0),
  fiber_g numeric check (fiber_g >= 0),
  sugar_g numeric check (sugar_g >= 0),
  sodium_mg numeric check (sodium_mg >= 0),
  water_ml numeric check (water_ml > 0),
  is_custom boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (owner_id, child_id)
);
create index nutrition_goals_child_idx on public.nutrition_goals (child_id);
create trigger nutrition_goals_updated_at before update on public.nutrition_goals
  for each row execute function private.set_updated_at();

create table public.allergy_profiles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  allergen text not null,
  severity text check (severity in ('mild', 'moderate', 'severe', 'unknown')),
  notes text,
  created_at timestamptz not null default now(),
  unique nulls not distinct (owner_id, child_id, allergen)
);
create index allergy_profiles_child_idx on public.allergy_profiles (child_id);

create table public.intolerance_profiles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  food text not null,
  notes text,
  created_at timestamptz not null default now(),
  unique nulls not distinct (owner_id, child_id, food)
);
create index intolerance_profiles_child_idx on public.intolerance_profiles (child_id);

create table public.water_logs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  log_date date not null, -- the user's local calendar date
  amount_ml int not null check (amount_ml between 1 and 5000),
  logged_at timestamptz not null default now()
);
create index water_logs_owner_date_idx on public.water_logs (owner_id, log_date);
create index water_logs_child_date_idx on public.water_logs (child_id, log_date);

create table public.user_health_goals (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  goal_type text not null check (goal_type in
    ('healthy_routine', 'dietary_variety', 'increase_fiber', 'hydration',
     'protein_goal', 'track_weight', 'monitor_nutrition', 'meal_consistency')),
  target jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique nulls not distinct (owner_id, child_id, goal_type)
);
create index user_health_goals_child_idx on public.user_health_goals (child_id);

-- ---------------------------------------------------------------------------
-- AI agent
-- ---------------------------------------------------------------------------
create table public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  title text,
  language text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index ai_conversations_owner_idx on public.ai_conversations (owner_id, updated_at desc);
create index ai_conversations_child_idx on public.ai_conversations (child_id);
create trigger ai_conversations_updated_at before update on public.ai_conversations
  for each row execute function private.set_updated_at();

create table public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations (id) on delete cascade,
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index ai_messages_conversation_idx on public.ai_messages (conversation_id, created_at);
create index ai_messages_owner_idx on public.ai_messages (owner_id);
create index ai_messages_child_idx on public.ai_messages (child_id);

-- What the AI agent may read. No row / allowed = false means the agent must not fetch it.
create table public.ai_user_context_permissions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  context_type text not null check (context_type in
    ('profile', 'body_metrics', 'dietary_preferences', 'allergies', 'food_diary',
     'medical_reports', 'symptoms', 'health_goals', 'ai_history', 'progress')),
  allowed boolean not null default false,
  updated_at timestamptz not null default now(),
  unique nulls not distinct (owner_id, child_id, context_type)
);
create index ai_ctx_permissions_child_idx on public.ai_user_context_permissions (child_id);
create trigger ai_ctx_permissions_updated_at before update on public.ai_user_context_permissions
  for each row execute function private.set_updated_at();

create table public.user_symptoms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  symptom text not null,
  severity int check (severity between 1 and 10),
  started_on date,
  notes text,
  source text not null default 'text' check (source in ('text', 'voice', 'chat', 'check_in')),
  recorded_at timestamptz not null default now()
);
create index user_symptoms_owner_idx on public.user_symptoms (owner_id, recorded_at desc);
create index user_symptoms_child_idx on public.user_symptoms (child_id);

create table public.symptom_assessments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  conversation_id uuid references public.ai_conversations (id) on delete set null,
  symptom_ids uuid[] not null default '{}',
  summary text not null,
  red_flags jsonb not null default '[]'::jsonb,
  escalated boolean not null default false,
  created_at timestamptz not null default now()
);
create index symptom_assessments_owner_idx on public.symptom_assessments (owner_id, created_at desc);
create index symptom_assessments_child_idx on public.symptom_assessments (child_id);
create index symptom_assessments_conversation_idx on public.symptom_assessments (conversation_id);

create table public.nutrition_recommendations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  conversation_id uuid references public.ai_conversations (id) on delete set null,
  food_name text not null,
  reason text not null,
  estimated_nutrition jsonb,
  status text not null default 'suggested'
    check (status in ('suggested', 'added_to_plan', 'dismissed')),
  created_at timestamptz not null default now()
);
create index nutrition_recs_owner_idx on public.nutrition_recommendations (owner_id, created_at desc);
create index nutrition_recs_child_idx on public.nutrition_recommendations (child_id);
create index nutrition_recs_conversation_idx on public.nutrition_recommendations (conversation_id);

create table public.personalized_meal_plans (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  title text not null,
  plan_type text not null check (plan_type in ('daily', 'weekly')),
  start_date date not null,
  end_date date not null,
  preferences jsonb not null default '{}'::jsonb,
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  check (end_date >= start_date)
);
create index meal_plans_owner_idx on public.personalized_meal_plans (owner_id, start_date desc);
create index meal_plans_child_idx on public.personalized_meal_plans (child_id);

create table public.meal_plan_items (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.personalized_meal_plans (id) on delete cascade,
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  plan_date date not null,
  meal_type text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  food_name text not null,
  quantity numeric check (quantity > 0),
  unit text,
  calories numeric check (calories >= 0),
  protein_g numeric check (protein_g >= 0),
  carbs_g numeric check (carbs_g >= 0),
  fat_g numeric check (fat_g >= 0),
  fiber_g numeric check (fiber_g >= 0),
  explanation text,
  substitutions jsonb not null default '[]'::jsonb,
  -- Set only after the user confirms they actually ate it (rule: plans never auto-log).
  consumed_entry_id uuid references public.meal_entries (id) on delete set null,
  created_at timestamptz not null default now()
);
create index meal_plan_items_plan_idx on public.meal_plan_items (plan_id, plan_date);
create index meal_plan_items_owner_idx on public.meal_plan_items (owner_id);
create index meal_plan_items_child_idx on public.meal_plan_items (child_id);
create index meal_plan_items_entry_idx on public.meal_plan_items (consumed_entry_id);

create table public.health_progress_logs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  log_date date not null,
  weight_kg numeric(5, 1) check (weight_kg between 1 and 500),
  bowel_movements int check (bowel_movements between 0 and 30),
  energy_level int check (energy_level between 1 and 5),
  followed_meal_plan boolean,
  symptom_change text check (symptom_change in ('improved', 'worse', 'unchanged')),
  notes text,
  created_at timestamptz not null default now(),
  unique nulls not distinct (owner_id, child_id, log_date)
);
create index health_progress_child_idx on public.health_progress_logs (child_id, log_date);

create table public.ai_follow_up_logs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  conversation_id uuid references public.ai_conversations (id) on delete set null,
  question text not null,
  scheduled_for timestamptz not null,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'sent', 'answered', 'skipped', 'cancelled')),
  response text,
  answered_at timestamptz,
  created_at timestamptz not null default now()
);
create index ai_follow_ups_owner_idx on public.ai_follow_up_logs (owner_id, scheduled_for);
create index ai_follow_ups_child_idx on public.ai_follow_up_logs (child_id);
create index ai_follow_ups_conversation_idx on public.ai_follow_up_logs (conversation_id);

-- Append-only record of safety rule hits (red-flag symptoms, critical lab values, ...).
create table public.ai_safety_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  conversation_id uuid references public.ai_conversations (id) on delete set null,
  event_type text not null check (event_type in
    ('red_flag_symptom', 'critical_lab_value', 'allergen_match', 'unsafe_request', 'emergency')),
  severity text not null check (severity in ('info', 'warning', 'urgent', 'emergency')),
  rule_id text,
  language text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index ai_safety_events_owner_idx on public.ai_safety_events (owner_id, created_at desc);
create index ai_safety_events_child_idx on public.ai_safety_events (child_id);
create index ai_safety_events_conversation_idx on public.ai_safety_events (conversation_id);

-- ---------------------------------------------------------------------------
-- Medical reports
-- ---------------------------------------------------------------------------
create table public.medical_reports (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  child_id uuid references public.child_profiles (id) on delete cascade,
  storage_path text not null unique, -- object name inside the private `medical-reports` bucket
  file_name text not null,
  mime_type text not null check (mime_type in ('application/pdf', 'image/jpeg', 'image/png')),
  file_size int check (file_size > 0),
  report_date date,
  lab_name text,
  category text check (category in
    ('cbc', 'vitamin_b12', 'vitamin_d', 'blood_glucose', 'hba1c', 'thyroid',
     'lipid', 'liver', 'kidney', 'iron', 'other')),
  status text not null default 'uploaded'
    check (status in ('uploaded', 'processing', 'needs_review', 'analyzed', 'failed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index medical_reports_owner_idx on public.medical_reports (owner_id, created_at desc);
create index medical_reports_child_idx on public.medical_reports (child_id);
create trigger medical_reports_updated_at before update on public.medical_reports
  for each row execute function private.set_updated_at();

-- Values are stored exactly as printed (value_text, unit, reference_text); nothing is inferred.
create table public.medical_report_results (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.medical_reports (id) on delete cascade,
  test_name text not null,
  value_text text not null,
  value_numeric numeric,
  unit text,
  reference_low numeric,
  reference_high numeric,
  reference_text text,
  flag text not null default 'unknown'
    check (flag in ('low', 'high', 'normal', 'critical', 'unknown')),
  is_user_verified boolean not null default false,
  created_at timestamptz not null default now()
);
create index medical_report_results_report_idx on public.medical_report_results (report_id);

create table public.medical_report_analyses (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.medical_reports (id) on delete cascade,
  language text not null default 'en',
  summary text not null,
  nutrition_guidance text,
  urgent_guidance text,
  model text,
  created_at timestamptz not null default now()
);
create index medical_report_analyses_report_idx on public.medical_report_analyses (report_id);

-- Separate, explicit, per-report sharing (never implied by family membership).
create table public.medical_report_permissions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.medical_reports (id) on delete cascade,
  owner_id uuid not null references auth.users (id) on delete cascade,
  grantee_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (report_id, grantee_id),
  check (owner_id <> grantee_id)
);
create index medical_report_permissions_grantee_idx on public.medical_report_permissions (grantee_id);
create index medical_report_permissions_owner_idx on public.medical_report_permissions (owner_id);

-- ---------------------------------------------------------------------------
-- Application tables
-- ---------------------------------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  category text not null check (category in
    ('water', 'meal', 'food_tracking', 'health_check_in', 'meal_plan',
     'ai_follow_up', 'report', 'goal', 'weekly_summary')),
  title text not null,       -- generic text that is safe on a lock screen
  body text,
  data jsonb not null default '{}'::jsonb,
  scheduled_for timestamptz,
  sent_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);

create table public.notification_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  category text not null check (category in
    ('water', 'meal', 'food_tracking', 'health_check_in', 'meal_plan',
     'ai_follow_up', 'report', 'goal', 'weekly_summary')),
  enabled boolean not null default true,
  schedule jsonb not null default '{}'::jsonb, -- e.g. {"times": ["09:00", "13:00"]}
  hide_details_on_lock_screen boolean not null default true,
  updated_at timestamptz not null default now(),
  unique (user_id, category)
);
create trigger notification_preferences_updated_at before update on public.notification_preferences
  for each row execute function private.set_updated_at();

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users (id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index audit_logs_actor_idx on public.audit_logs (actor_id, created_at desc);
