-- 1. Create 'profiles' table
create table public.profiles (
  id uuid not null references auth.users on delete cascade,
  email text,
  is_premium boolean default false,
  is_admin boolean default false, -- Added Admin Flag
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (id)
);

-- 2. Enable Row Level Security (RLS)
alter table public.profiles enable row level security;

-- 3. Create Policy: Users can view their own profile
create policy "Users can view own profile"
  on public.profiles for select
  using ( auth.uid() = id );

-- 4. Create Policy: Users can update their own profile
create policy "Users can update own profile"
  on public.profiles for update
  using ( auth.uid() = id );

-- 5. Auto-create profile on signup (Trigger)
-- This function runs every time a new user is created in auth.users
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, is_premium, is_admin)
  values (new.id, new.email, false, false);
  return new;
end;
$$ language plpgsql security definer;

-- Trigger the function
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ==========================================
-- OPTIONAL: Add columns for other features
-- ==========================================

-- Add 'is_premium' to workouts table (if not exists)
alter table public.workouts 
add column if not exists is_premium boolean default false;

-- Add 'image_url' to programs table (if not exists)
alter table public.programs 
add column if not exists image_url text;
