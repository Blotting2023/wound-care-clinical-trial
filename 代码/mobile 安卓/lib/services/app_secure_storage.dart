import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// App-wide secure storage instance.
///
/// macOS: `useDataProtectionKeychain: false` is required because the
/// data-protection keychain demands a keychain-access-groups entitlement,
/// which ad-hoc signed debug builds don't have — SecItemAdd then fails
/// with -34018 and login breaks. The legacy (file-based) keychain works
/// without any extra entitlement.
const FlutterSecureStorage appSecureStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(useDataProtectionKeyChain: false),
);
