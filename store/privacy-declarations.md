# Store Privacy Declarations

Use this as the source of truth when filling App Store Connect privacy details
and the Google Play Data Safety form.

## Data Collected By WashDesk

### Contact Info

- Email address
- Owner or manager name

Purpose:

- Account management
- Subscription access
- Support

Linked to user:

- Yes

Used for tracking:

- No

### User Content / Business Records

- Business name
- Employee names
- Services and prices
- Bookings
- Wash history
- Vehicle details
- Number plates
- Expenses
- Reports and daily totals
- Notes entered by the business

Purpose:

- App functionality
- Business operations
- Backup and restore when cloud backup is enabled

Linked to user:

- Yes, because the data belongs to the manager account/business.

Used for tracking:

- No

### Purchases

- Subscription status
- Product ID
- Purchase ID / verification data from the app store

Purpose:

- Subscription access
- Restore purchases

Linked to user:

- Yes

Used for tracking:

- No

### Location

The customer side uses location permission to show nearby car washes.

Purpose:

- App functionality

Linked to user:

- No, unless later stored with a customer account.

Used for tracking:

- No

## Data Shared With Third Parties

### App Store / Google Play

Subscriptions are processed by the app store. WashDesk does not collect card
details.

### Supabase

If cloud backup is configured, the app uploads a copy of the local SQLite
database to Supabase Storage.

## Security

- Data is stored locally on the device.
- Cloud backup uses HTTPS.
- Store billing is handled by Apple or Google.

## Deletion

Users can delete local app data by deleting the app or clearing app storage.
Cloud backups must be deleted from the configured Supabase project until a
self-service cloud deletion flow is added.

## App Store Connect Notes

Declare the app collects:

- Contact Info: Email Address, Name
- User Content: Other User Content
- Purchases: Purchase History
- Location: Precise Location and Coarse Location only if shipping the customer
  locator flow in that app target. Do not select Location for the manager-only
  `com.washdesk.manager` release.

Do not mark any category as tracking.

## Google Play Data Safety Notes

Mark:

- Data collected: Personal info, App activity or app info/performance if asked,
  Financial info for purchase history/subscription status, Location if shipping
  customer locator
- Data shared: app store billing and Supabase backup service as service
  providers
- Data encrypted in transit: Yes
- Users can request deletion: Yes, through support until self-service deletion
  is added
