# Apple Developer Portal — BuxMuse (`com.buxmuse.app`)

Do this in [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) **before** archiving for TestFlight.

## 1. App IDs (Identifiers → +)

| Bundle ID | Type | Capabilities to enable |
|-----------|------|-------------------------|
| `com.buxmuse.app` | App | **HealthKit** only |
| `com.buxmuse.app.TimerWidget` | App | *(none required today)* |

Do **not** enable on the main app unless you have the feature: Push, iCloud, CloudKit, App Groups, Sign in with Apple, Associated Domains, FinanceKit.

## 2. HealthKit (main app only)

1. Open `com.buxmuse.app` → **Capabilities** → enable **HealthKit** → Save.
2. In Xcode → BuxMuse target → **Signing & Capabilities** → **HealthKit** → check **Clinical Health Records** = **off**.
3. Request **read** access for **Sleep Analysis** only (matches `BurnoutEngine`).

## 3. Live Activities

- No separate portal checkbox.
- Xcode: `NSSupportsLiveActivities` = YES (already in project).
- Entitlements: ActivityKit is driven by Info.plist + extension; widget target `com.buxmuse.app.TimerWidget` registered.

## 4. iCloud backup (today)

- **Manual** `.buxmuse` export via Share → iCloud Drive: **no** iCloud capability needed.
- When you add **auto** iCloud backup later: enable **iCloud** + container on App ID, then Xcode.

## 5. Profiles

Use **Automatic Signing** in Xcode (Team `8J85UK6P84`). After changing App ID capabilities, open Xcode once so it refreshes provisioning profiles.

## 6. Xcode targets (repo already configured)

| Target | Entitlements file |
|--------|-------------------|
| BuxMuse | `BuxMuse.entitlements` (HealthKit) |
| BuxMuseTimerWidget | `BuxMuseTimerWidget.entitlements` (empty) |

See `docs/APP_STORE_CONNECT_PRIVACY.md` for App Store Connect privacy answers.
