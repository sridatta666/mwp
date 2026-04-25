# Supabase setup for MWP

Use this checklist so users can log in successfully and the app can reach your Supabase project.

---

## 1. Project status (connection errors)

If users see **"Connection problem"** or **"Software caused the connection to abort"** when logging in:

- **Unpause the project**  
  Free-tier projects are paused after inactivity.  
  - Open [Supabase Dashboard](https://supabase.com/dashboard) → your project.  
  - If the project is **Paused**, click **Restore project** and wait until it is running.

- **Check project URL and anon key**  
  In the app, `lib/main.dart` must use the same **Project URL** and **anon public** key as in the dashboard:  
  - Dashboard → **Project Settings** → **API** → **Project URL** and **anon public**.

- **Network / firewall**  
  The device must be able to reach `https://<your-project-ref>.supabase.co` on HTTPS (port 443). Corporate VPNs or firewalls sometimes block this.

---

## 2. Authentication (login / sign-up)

- **Email provider**  
  - Dashboard → **Authentication** → **Providers** → **Email** → ensure **Email** is **Enabled**.

- **Confirm email (optional)**  
  - If **Confirm email** is **ON**: users must click the confirmation link in the email before they can sign in.  
  - If **OFF**: users can sign in immediately after sign-up.  
  - Location: **Authentication** → **Providers** → **Email** → **Confirm email**.

- **Sign-up allowed**  
  - **Authentication** → **Providers** → **Email** → **Sign up** should be enabled if you want new users to register from the app.

- **Password reset (forgot password)**  
  - Dashboard → **Authentication** → **URL Configuration** → **Redirect URLs**  
  - Add: `mwp://reset-password` so the "reset password" email link can open the app.  
  - Without this, the reset link may not open the app on device.

---

## 3. Schema / tables (for app features)

The app expects these (create them in the SQL editor or via migrations if missing):

- **Auth users**  
  Handled by Supabase Auth (no extra schema required for login).

- **profiles** (optional but recommended)  
  Used for `is_admin` and `is_premium`.  
  - Table: `public.profiles` with at least `id` (uuid, references `auth.users`), `is_admin` (boolean), `is_premium` (boolean).  
  - RLS: users can read/update their own row; service role can manage all.

- **workouts**, **programs**, **program_days**, **user_progress**, **clip_logs**  
  Used by the rest of the app; define per your feature set and existing migrations.

---

## 4. Quick checklist

| Item | Where to check |
|------|----------------|
| Project is **Running** (not Paused) | Dashboard → project home |
| **Project URL** and **anon key** match the app | Dashboard → Settings → API |
| **Email** provider enabled | Authentication → Providers → Email |
| **Confirm email** setting matches your flow | Authentication → Providers → Email |
| App can reach `https://<project>.supabase.co` | Device network / VPN / firewall |

After changing **Confirm email** or restoring a **Paused** project, try logging in again from the app.
