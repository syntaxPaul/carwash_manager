# WashDesk Admin Dashboard

This is a static operational dashboard for WashDesk. It signs in with Supabase
Auth and reads the protected `admin_get_dashboard()` RPC.

## Setup

1. Deploy `supabase/production_schema.sql`.
2. Add your admin email in Supabase SQL Editor:

   ```sql
   insert into public.admin_users (email)
   values ('YOUR_ADMIN_EMAIL')
   on conflict (email) do nothing;
   ```

3. Open `admin-dashboard/index.html` or host the folder on your site.
4. Sign in with the same Supabase user email and password.

Only users listed in `public.admin_users` can load dashboard data.
