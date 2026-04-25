# Supabase schema and migrations

When we need to change Supabase tables (new columns, tables, RLS, indexes), the SQL will be added here. **You run these in your Supabase project**—the app cannot connect to your database directly.

## How to apply changes

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project.
2. Go to **SQL Editor**.
3. Copy the contents of the migration file (from `migrations/` or root SQL files).
4. Paste and click **Run**.

Run migrations in order (oldest first) if they depend on each other.

## Existing SQL in this repo

- **Project root:** `supabase_schema.sql`, `update_logs_schema.sql`, `update_schema.sql`, `fix_permissions.sql`, `backfill_profiles.sql` — run these in the SQL Editor if you haven’t already.
- **`migrations/`** — future schema changes will be added here as dated files (e.g. `20250227_user_favorites.sql`).

## Tables the app expects

- **auth.users** (Supabase Auth)
- **public.profiles** (id, email, is_premium, is_admin, …)
- **public.workouts** (id, title, description, video_id, duration, difficulty, is_premium, type, clips, …)
- **public.programs** (id, title, description, total_weeks, difficulty_level, image_url, type, …)
- **public.program_days** (id, program_id, day_number, week_number, workout_id, is_rest_day, …)
- **public.user_progress** (user_id, workout_id, completed_at) — for completion history and stats
- **public.clip_logs** (user_id, program_id, clip_index, …) — for sequence workout logs

If you use the Supabase CLI (`supabase link` + `supabase db push`), you can also run the SQL in `migrations/` as part of your deployment pipeline.
