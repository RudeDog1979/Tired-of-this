# App Store Connect — App Privacy & metadata (BuxMuse)

Copy these answers into **App Store Connect → Your App → App Privacy** (and related fields). Adjust only if product behavior changes.

**Privacy Policy URL:** Host `docs/legal/PRIVACY_POLICY.md` (GitHub Pages, Notion, or your site) and paste the public HTTPS URL in Connect.

---

## App Privacy questionnaire (recommended answers)

### Data collection overview

| Question | Answer |
|----------|--------|
| Do you or your third-party partners collect data from this app? | **Yes** — data exists on device; user controls optional Health link |
| Is data used to track users? | **No** |
| Is data linked to the user’s identity? | **No** — no BuxMuse account, no server upload of finances |

### Data types

#### Health & Fitness

| Field | Answer |
|-------|--------|
| Collect? | **Yes** (only when user enables HealthKit sleep sync) |
| Data | **Health** (e.g. sleep analysis) |
| Linked to user? | **No** (no account) |
| Used for tracking? | **No** |
| Purpose | **App functionality** |
| Collected by you / sent off device? | **No** — processed on device via Apple Health; BuxMuse does not operate a backend that receives health data |

#### Financial Info

| Field | Answer |
|-------|--------|
| Collect? | **Yes** |
| Data | Purchase history / other financial info (expenses, income, budgets user enters) |
| Linked to user? | **No** |
| Tracking? | **No** |
| Purpose | **App functionality** |
| Off device? | **No** — stored locally (SwiftData, JSON, encrypted `.buxmuse` backups user exports themselves) |

#### Photos or Videos

| Field | Answer |
|-------|--------|
| Collect? | **Yes** (when user scans or picks receipt images) |
| Linked / tracking | **No** |
| Purpose | **App functionality** |
| Off device? | **No** — images stay on device unless user exports backup |

#### Precise Location

| Field | Answer |
|-------|--------|
| Collect? | **Yes** (optional — Studio mileage “auto-location”) |
| When | Only when user uses mileage location capture |
| Linked / tracking | **No** |
| Purpose | **App functionality** |
| Off device? | **No** |

#### Other data you can mark **No** (unless you add features)

- Contact Info, Identifiers, Usage Data, Diagnostics (unless you ship opt-in diagnostic export in Build 2), Browsing History, Search History, Sensitive Info (beyond what user types into expenses), etc.

### Photos / Camera (usage, not always “collection”)

Camera is used for receipt scan; treat under **Photos or Videos** or **Other User Content** if Connect groups it that way — still **on device only**.

---

## Capabilities vs privacy (sanity check)

| Feature | Portal capability | Privacy label |
|---------|-------------------|---------------|
| HealthKit sleep | HealthKit on App ID | Health, on-device |
| Local notifications | None | Usually not “collected” |
| Live Activities | None | N/A |
| iCloud Drive share of `.buxmuse` | None | User-initiated export, not app collection |
| **Personal iCloud sync (CloudKit)** | iCloud + CloudKit on App ID | User’s **private** iCloud container; BuxMuse does not operate a server that receives sync payloads |
| Face ID lock | None | On-device Keychain |

---

## Review notes (optional field for Apple)

> BuxMuse is offline-first with no user account. Financial data and receipt images are stored on device. Optional **Personal iCloud sync** (Settings) stores encrypted sync records in the user’s private iCloud container via Apple CloudKit — not on BuxMuse servers. Optional HealthKit sleep read (Pro) improves Creative Energy locally. Encrypted `.buxmuse` backups are exported by the user via the system share sheet.

---

## TestFlight “What to test”

1. First launch region (UK → GBP) and clean Apple theme.  
2. Add expense, receipt scan (camera / library).  
3. Settings → Backup → create `.buxmuse` → Share to Files.  
4. Pro → Creative Energy → enable Health sleep sync.  
5. Studio timer → Lock Screen Live Activity.  
6. **1.0.9** — Settings → iCloud sync → enable on two devices; verify budget/expenses/Studio restore.  
7. **1.0.9** — Delete all local data (with sync off: no iCloud prompt; with sync on: keep/delete cloud paths).  
8. **1.0.9** — Complete onboarding → app tour; tab bar must not cover coach marks.
