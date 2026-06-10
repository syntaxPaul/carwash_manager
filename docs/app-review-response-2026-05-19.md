# App Review Response - May 19, 2026

## What Changed

- The subscription purchase screen now shows:
  - subscription title: `WashDesk Monthly Subscription`
  - subscription length: `1 month`
  - auto-renewal text: billed every 1 month until cancelled
  - subscription price and price per 1-month period
  - the WashDesk services included during each subscription period
  - functional Terms of Use and Privacy Policy links
- The App Store description now includes:
  - `Terms of Use (EULA): https://roim4ads.com/washdesk-terms-of-service`
  - `Privacy Policy: https://roim4ads.com/washdesk-privacy-policy`
- Settings now includes `Delete account`.
- The delete-account flow confirms the action, requires typing the signed-in
  email address, deletes the Supabase account/backups when configured, deletes
  the local WashDesk database from the device, and returns to onboarding.

## App Review Reply

Hello App Review,

Thank you for the review. We have updated WashDesk in build 3.

For Guideline 3.1.2(c), build 4 now displays a prominent required-information
block before purchase. It states:

- Subscription title: WashDesk Monthly Subscription
- Length of subscription: 1 month
- Renewal: Auto-renewable subscription, billed every 1 month until cancelled
- Services provided each subscription period: one car wash business workspace
  with bookings, walk-ins, wash history, employees, services, expenses,
  reports, daily totals and cloud backup when enabled
- Price for each 1-month subscription period
- Functional Terms of Use and Privacy Policy links

For Guideline 5.1.1(v), account deletion is now available in the app from:
Settings > Account > Delete account. The flow requires confirmation, asks the
user to type the signed-in email address, deletes the account and associated
local app data, removes cloud account/backup data when configured, and returns
the user to onboarding.

The App Store description also includes the Terms of Use (EULA) link:
https://roim4ads.com/washdesk-terms-of-service

Privacy Policy:
https://roim4ads.com/washdesk-privacy-policy

We have attached a screen recording showing sign-in, the subscription details
screen, and the complete account deletion flow.

Thank you.

## Recording Checklist

1. Install/open build 3 on a physical iPad or iPhone.
2. Sign in with the demo account or create a new account.
3. Show the subscription screen with title, length, price, included service,
   Terms of Use and Privacy Policy.
4. Go to `Settings`.
5. Tap `Delete account`.
6. Confirm the warning.
7. Type the signed-in email address.
8. Tap `Delete account`.
9. Show that the app returns to onboarding/sign-in.

## Manual Supabase Step

Run `supabase/account_deletion.sql` in the Supabase SQL Editor before recording
the deletion flow in the production build.
