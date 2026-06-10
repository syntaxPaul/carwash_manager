# WashDesk

This repository hosts two Flutter apps that share code:

- Manager app: back-office for recording washes, expenses, services, reports.
- Customer app: browsing carwashes, booking, and tracking.

## Running

- Manager app
  - `flutter run -t lib/main_manager.dart`

- Customer app
  - `flutter run -t lib/main_customer.dart`

Both apps share widgets, data, and themes. Each entrypoint wires only the
routes relevant to that app and sets an appropriate initial route.

## Optional: Flavors (separate bundle IDs)

If you want two installable apps with different names/IDs:

1) Android: define productFlavors `manager` and `customer` in `android/app/build.gradle`
   and update the `applicationId`/`resValue("string","app_name", ...)`.

2) iOS: add two schemes/targets in Xcode (e.g. Manager, Customer) with unique
   bundle IDs. Map schemes to Flutter flavors and run with:
   `flutter run --flavor manager -t lib/main_manager.dart` and
   `flutter run --flavor customer -t lib/main_customer.dart`.

If you want, open an issue and we can set up flavors for you.
