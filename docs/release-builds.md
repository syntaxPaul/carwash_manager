# WashDesk Release Builds

## App identifiers

Manager app:

```text
iOS bundle ID: com.washdesk.manager
Android application ID: com.washdesk.manager
```

Customer app:

```text
iOS bundle ID: com.washdesk.customer
Android application ID: com.washdesk.customer
```

Default development target:

```text
iOS bundle ID: com.washdesk.app
Android application ID: com.washdesk.app
```

## iOS manager release build

```sh
flutter build ios --flavor manager -t lib/main_manager.dart --release \
  --dart-define=WASHDESK_SUPABASE_URL=https://thiaeudcwpbmhnbukous.supabase.co \
  --dart-define=WASHDESK_SUPABASE_ANON_KEY=YOUR_ROTATED_ANON_KEY \
  --dart-define=WASHDESK_BACKUP_BUCKET=washdesk-backups
```

Open `ios/Runner.xcworkspace`, select the `manager` scheme, set the Apple Team,
then archive from Xcode for App Store Connect.

## Android manager release build

Before uploading to Google Play, create an upload keystore and add
`android/key.properties`. Do not commit `android/key.properties`.

```sh
keytool -genkey -v -keystore android/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias washdesk-upload
cp android/key.properties.example android/key.properties
```

Then edit `android/key.properties` with the passwords you entered.

```sh
flutter build appbundle --flavor manager -t lib/main_manager.dart --release \
  --dart-define=WASHDESK_SUPABASE_URL=https://thiaeudcwpbmhnbukous.supabase.co \
  --dart-define=WASHDESK_SUPABASE_ANON_KEY=YOUR_ROTATED_ANON_KEY \
  --dart-define=WASHDESK_BACKUP_BUCKET=washdesk-backups
```

Output:

```text
build/app/outputs/bundle/managerRelease/app-manager-release.aab
```

## Store signing still required

Do not publish Android with debug signing. If `android/key.properties` is
missing, the local release build falls back to debug signing only so development
commands do not break.

Do not publish iOS without selecting the final Apple Developer Team and
provisioning profile.
