-- FIX PERMISSIONS SCRIPT

-- 1. Ensure RLS is enabled
alter table public.profiles enable row level security;

-- 2. Clean up old policies
drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Public profiles access" on public.profiles;

-- 3. Create READ policy (Allow users to see THEIR OWN row)
create policy "Users can view own profile"
  on public.profiles for select
  to authenticated
  using ( auth.uid() = id );

-- 4. Create UPDATE policy (Allow users to update THEIR OWN row)
create policy "Users can update own profile"
  on public.profiles for update
  to authenticated
  using ( auth.uid() = id );

-- 5. Grant permissions to the authenticated role
grant select, update on table public.profiles to authenticated;

-- 6. Verify Backfill (Run this again just in case)
insert into public.profiles (id, email, is_premium, is_admin)
select id, email, false, false
from auth.users
where id not in (select id from public.profiles);
