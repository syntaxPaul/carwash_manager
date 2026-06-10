# WashDesk Cloud Backup

WashDesk can back up the local SQLite database to Supabase Storage. The app is
offline-first, so this is a device backup/restore feature, not live multi-device
sync. Production backups require Supabase Auth; anonymous Storage access must
not be used.

## App build config

Build the app with these values:

```sh
flutter build ios \
  --dart-define=WASHDESK_SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=WASHDESK_SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY \
  --dart-define=WASHDESK_BACKUP_BUCKET=washdesk-backups
```

`WASHDESK_BACKUP_BUCKET` is optional and defaults to `washdesk-backups`.
`WASHDESK_BACKUP_PATH_PREFIX` is optional and defaults to `manager`.

## Supabase setup

1. Create a private Storage bucket named `washdesk-backups`.
2. Keep the bucket private for production.
3. Enable email/password auth in Authentication > Providers.
4. For the current app flow, disable email confirmation until an email
   confirmation screen is added.
5. Run `supabase/storage_policies.sql` in the Supabase SQL Editor, or create
   equivalent Storage policies in the dashboard.

Backups are written to:

```text
manager/{supabase_auth_user_id}/carwash_manager.db
manager/{supabase_auth_user_id}/metadata.json
```

Do not enable unrestricted anonymous read/write policies on a production bucket.

## Restore behavior

Restore replaces the local SQLite database on the device, reloads settings, and
refreshes the signed-in manager account. If the restored database does not
contain the current account, the app signs the manager out.
