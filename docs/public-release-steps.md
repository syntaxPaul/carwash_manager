# WashDesk Public Release Steps

This checklist covers the remaining work that cannot be completed from the
local codebase because it requires account ownership, banking details, or store
dashboard access.

## 1. Rotate Exposed Supabase Secrets

The Supabase secret key and database password were shared in chat. Rotate them
before any public release.

1. Open the Supabase dashboard.
2. Select the WashDesk project.
3. Go to `Project Settings` > `API`.
4. Rotate/regenerate any secret/service-role key that was exposed.
5. Go to `Project Settings` > `Database`.
6. Reset the database password.
7. Keep the public anon key only in app build settings. Never put a secret or
   service-role key in the app.

## 2. Finish Supabase Production Setup

1. In Supabase, go to `Authentication` > `Providers`.
2. Enable `Email`.
3. Keep email confirmation off until the app has a confirmed-email flow, or add
   redirect URLs before enabling confirmation.
4. Go to `Storage`.
5. Create the private bucket `washdesk-backups` if it does not already exist.
6. Go to `SQL Editor`.
7. Run `supabase/storage_policies.sql`.
8. Run `supabase/account_deletion.sql`. This creates the authenticated
   `delete_current_user` RPC used by Settings > Delete account.
9. If Supabase blocks SQL ownership on `storage.objects`, create equivalent
   Storage policies in the dashboard for authenticated users only:
   - `SELECT`: `bucket_id = 'washdesk-backups' and (storage.foldername(name))[1] = 'manager' and (storage.foldername(name))[2] = auth.uid()::text`
   - `INSERT`: same expression in `WITH CHECK`
   - `UPDATE`: same expression in both `USING` and `WITH CHECK`
   - `DELETE`: same expression in `USING`

## 3. Create Apple App Store Subscription

If `com.washdesk.manager` is not listed under Apple Developer
`Certificates, Identifiers & Profiles` > `Identifiers`, create it first. Do
not use the old `com.example.carwash.manager` identifier for the public app.

1. Open Apple Developer.
2. Go to `Certificates, Identifiers & Profiles` > `Identifiers`.
3. Click `+`.
4. Select `App IDs`, then click `Continue`.
5. Select `App`, then click `Continue`.
6. Description: `WashDesk Manager`.
7. Bundle ID: choose `Explicit`.
8. Bundle ID value: `com.washdesk.manager`.
9. Enable `In-App Purchase`.
10. Click `Continue`, then `Register`.

After that, create the App Store Connect app:

1. Open App Store Connect.
2. Go to `My Apps` > `+` > `New App`.
3. App name: `WashDesk`.
4. Platform: `iOS`.
5. Bundle ID: `com.washdesk.manager`.
6. SKU: `washdesk-manager`.
7. Go to the new app's `In-App Purchases` section.
8. Create an auto-renewable subscription group.
9. Add subscription product ID `washdesk_monthly`.
   Type it manually if App Store Connect rejects it; hidden spaces or pasted
   characters can trigger the validation error. The underscore is allowed.
10. Set the price to `R499.99` per month or the closest Apple price tier.
11. Add required subscription screenshots, review notes, and localization.

## 4. Complete Apple Business Requirements

1. In App Store Connect, open `Agreements, Tax, and Banking`.
2. Complete the Paid Apps agreement.
3. Add banking details for where Apple should pay subscription revenue.
4. Add tax details.
5. Add contact details for legal, financial, and technical contacts.

## 5. Fill App Privacy

Use `store/privacy-declarations.md` as the source of truth.

1. In App Store Connect, open the WashDesk app.
2. Go to `App Privacy`.
3. Select that the app does not track users.
4. For the WashDesk Manager app, declare:
   - Contact Info: `Name`, `Email Address`
   - Purchases: `Purchase History`
   - User Content: `Other User Content`
5. Do not declare Location for the manager app unless you submit the combined
   customer locator build that asks customers for location permission.
6. Make the answers match the current app behavior exactly before submitting.

## 6. Add Store Metadata

1. Use `store/app_store/listing.md` for the title, subtitle, description,
   keywords, and review notes.
2. Support URL: `https://roim4ads.com/washdesk-support`
3. Privacy Policy URL: `https://roim4ads.com/washdesk-privacy-policy`
4. Terms of Service URL: `https://roim4ads.com/washdesk-terms-of-service`
5. Marketing URL: `https://roim4ads.com/washdesk`
6. Upload screenshots following `store/screenshot-plan.md`.
7. Make sure the App Description includes:
   `Terms of Use (EULA): https://roim4ads.com/washdesk-terms-of-service`

## 7. Build and Upload iOS

Use this command for a production manager build:

```sh
flutter build ipa --flavor manager -t lib/main_manager.dart --release \
  --dart-define=WASHDESK_SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=WASHDESK_SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

Then upload from Xcode Organizer or Transporter.

## 8. Final Release QA

Test these on a fresh install and with a real App Store sandbox account:

1. Launch screen shows the WashDesk logo.
2. First screen is the WashDesk introduction page.
3. Sign up creates a Supabase authenticated manager.
4. Sign in works after uninstall/reinstall.
5. The 5-day trial starts correctly.
6. The monthly subscription purchase works in sandbox.
7. Restore purchases works.
8. The subscription screen shows title, one-month period, price, included
   service, Terms of Use and Privacy Policy before purchase.
9. Settings > Delete account completes account deletion and returns to
   onboarding.
10. Cloud backup uploads and restores for the signed-in manager only.
11. Wash recording, bookings, wash history totals, staff, services, and reports
   all work with real sample data.
