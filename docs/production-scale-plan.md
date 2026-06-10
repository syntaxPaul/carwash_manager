# WashDesk 200+ Business Readiness Plan

This app can serve early customers now, but reliable 200+ business operation
requires the backend controls below to be deployed and monitored.

## Completed in this codebase

- Added `supabase/production_schema.sql` for:
  - authenticated business profiles
  - subscription entitlements
  - subscription event history
  - backup health tracking
  - app error event tracking
  - an `admin_business_overview` view for operational support
  - an `admin_attention_overview` view for issues needing action
  - an `admin_users` allow-list for admin-only operational access
  - an `admin_get_dashboard()` RPC for the admin dashboard
  - RLS so each manager reads only their own business/subscription rows
  - RPCs for manager profile sync, entitlement fetch, and purchase logging
- Added `admin-dashboard/`, a static admin dashboard for:
  - active businesses
  - subscription status
  - backup status
  - recent app errors
  - recent subscription events
- Added `supabase/functions/app-store-notifications` for Apple App Store Server
  Notifications V2. This function verifies Apple signed notifications and
  updates Supabase subscription entitlements.
- Updated the app to:
  - sync manager profile data to Supabase after registration/sign-in
  - fetch cloud entitlement status when signing in
  - record App Store purchase data to Supabase after StoreKit success
  - keep working if the new backend SQL has not been deployed yet

## Required Supabase deployment

1. Open Supabase Dashboard > SQL Editor.
2. Run `supabase/production_schema.sql`.
3. Confirm these tables exist:
   - `businesses`
   - `subscription_entitlements`
   - `subscription_events`
   - `backup_health`
   - `app_error_events`
   - `admin_users`
4. Confirm these RPCs exist:
   - `upsert_manager_profile`
   - `get_manager_access_state`
   - `record_app_store_purchase`
   - `record_backup_health`
   - `record_app_error`
   - `admin_get_dashboard`
   - `is_admin`
5. Confirm this view exists:
   - `admin_business_overview`
   - `admin_attention_overview`

## Required Apple server notification setup

Deploy the Edge Function:

```sh
supabase functions deploy app-store-notifications
```

Set required secrets:

```sh
supabase secrets set APPLE_BUNDLE_ID=com.washdesk.manager
supabase secrets set APPLE_ENVIRONMENT=PRODUCTION
supabase secrets set APPLE_ROOT_CA_PEM="$(cat AppleRootCA-G3.pem)"
```

Then in App Store Connect:

1. Open `Users and Access` > `Integrations` or the app's subscription server
   notification settings.
2. Add the Production Server Notification URL:
   `https://<project-ref>.functions.supabase.co/app-store-notifications`
3. Send a test notification and confirm a row appears in
   `subscription_events`.

## Admin dashboard setup

1. Add your Supabase admin account email:

   ```sql
   insert into public.admin_users (email)
   values ('YOUR_ADMIN_EMAIL')
   on conflict (email) do nothing;
   ```

2. Open or host `admin-dashboard/index.html`.
3. Sign in with the same Supabase email and password.

Only authenticated users listed in `public.admin_users` can read operational
dashboard data.

## Remaining work before calling it seamless at 200+

- Add crash/error monitoring such as Sentry or Firebase Crashlytics.
- Add scheduled backup-health checks.
- Add database usage alerts in Supabase.
- Add load tests with large local databases:
  - 50,000 washes
  - 5,000 bookings
  - 100 employees/services
  - repeated CSV/PDF exports
- Add customer support operating procedures for:
  - refunds
  - account deletion
  - subscription restore problems
  - business owner device loss

## Important note

The mobile app can optimistically unlock after StoreKit reports a successful
purchase. Production entitlement correctness depends on App Store Server
Notifications keeping `subscription_entitlements` current for renewals,
expiries, refunds, grace periods, and billing retry.
