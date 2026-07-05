import 'package:flutter/foundation.dart';

/// The store the current build bills through. Copy shown to users must
/// never say "App Store" on an Android build (Play review risk, and it
/// confuses owners). Use these helpers instead of hardcoded store names.
bool get isAppleStore => defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

String get storeName => isAppleStore ? 'App Store' : 'Google Play';

String get storeVendor => isAppleStore ? 'Apple' : 'Google';

String get storeAccountSettingsHint => isAppleStore
    ? 'your Apple account settings'
    : 'the Google Play subscriptions page';
