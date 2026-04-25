-- Insert profiles for existing users who don't have one
insert into public.profiles (id, email, is_premium, is_admin)
select id, email, false, false
from auth.users
where id not in (select id from public.profiles);

-- Verify the user has the row (optional check)
-- select * from public.profiles;
