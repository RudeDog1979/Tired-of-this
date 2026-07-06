# Apple Developer Portal — BuxMuse (`com.buxmuse.app`)

Do this in [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) **before** archiving for TestFlight.

## 1. App IDs (Identifiers → +)

| Bundle ID | Type | Capabilities to enable |
|-----------|------|-------------------------|
| `com.buxmuse.app` | App | **iCloud** + CloudKit container `iCloud.com.buxmuse.app` (if using Personal iCloud sync); **FinanceKit** if Wallet import is enabled |
| `com.buxmuse.app.TimerWidget` | App | *(none required today)* |

Do **not** enable on the main app unless you have the feature: Push, App Groups, Sign in with Apple, Associated Domains, **HealthKit** (removed — Creative Energy is manual-only).

## 2. Live Activities

- No separate portal checkbox.
- Xcode: `NSSupportsLiveActivities` = YES (already in project).
- Entitlements: ActivityKit is driven by Info.plist + extension; widget target `com.buxmuse.app.TimerWidget` registered.

## 3. iCloud backup (today)

- **Manual** `.buxmuse` export via Share → iCloud Drive: **no** iCloud capability needed.
- **Personal iCloud sync:** enable **iCloud** + container on App ID, then Xcode.

## 4. Profiles

Use **Automatic Signing** in Xcode (Team `8J85UK6P84`). After changing App ID capabilities, open Xcode once so it refreshes provisioning profiles.

## 5. Xcode targets (repo already configured)

| Target | Entitlements file |
|--------|-------------------|
| BuxMuse | `BuxMuse.entitlements` (FinanceKit, iCloud) |
| BuxMuseTimerWidget | `BuxMuseTimerWidget.entitlements` (empty) |

See `docs/APP_STORE_CONNECT_PRIVACY.md` for App Store Connect privacy answers.
