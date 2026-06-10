# WashDesk Store Submission Checklist

## Before Upload

- Rotate exposed Supabase secret key and database password.
- Confirm `washdesk_monthly` exists in App Store Connect and Google Play.
- Confirm subscription price is R499.99/month or the intended local equivalent.
- Host Privacy Policy publicly.
- Host Terms of Service publicly.
- Add support email or support website.
- Add final app icon without white padding.
- Confirm bundle IDs/application IDs:
  - iOS manager: `com.washdesk.manager`
  - Android manager: `com.washdesk.manager`
- Confirm Android release build uses a real upload keystore.
- Confirm iOS archive uses the correct Apple Developer Team.
- Confirm Supabase Storage backup policy is production-safe.

## App Store Connect

- App name: WashDesk
- Subtitle: Car wash bookings and wash history
- Category: Business
- Age rating: 4+
- Privacy Policy URL: TODO
- Support URL: TODO
- In-app purchase product ID: `washdesk_monthly`
- Review account: create a demo manager account or explain sign-up trial flow.

## Google Play Console

- App name: WashDesk
- Category: Business
- Privacy Policy URL: TODO
- Contact email: TODO
- Data Safety: use `store/privacy-declarations.md`
- Content rating: complete questionnaire as business/productivity app
- Subscription product ID: `washdesk_monthly`

## Final QA

- Fresh install opens to onboarding.
- Sign-up creates a 5-day trial.
- Sign-in works after app restart.
- Subscription screen loads without crashing when store products are missing.
- Record a wash requires all fields except notes.
- Wash history shows plate, car, service, employee and totals.
- Bookings queue only shows today's bookings.
- Settings cloud backup does not expose secrets.
- Offline backup export works.
- App icon has no white padding.
- Splash screen shows the WashDesk logo.
