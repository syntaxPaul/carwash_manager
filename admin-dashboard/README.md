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

3. Create a Supabase Auth user with the same email in
   `Authentication > Users`. This is separate from your Supabase dashboard or
   GitHub login.
4. Open `admin-dashboard/index.html` or host the folder on your site.
5. Sign in with the same Supabase Auth user email and password, or use the
   magic-link button if email redirects are configured for the hosted URL.

Only users listed in `public.admin_users` can load dashboard data.
