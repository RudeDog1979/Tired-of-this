# iCloud Sync — Design & Implementation Plan

**Target release:** 1.0.8 (deferred — do not implement before 1.0.7 ships)

> **For agentic workers:** When implementation starts, use superpowers:subagent-driven-development or superpowers:executing-plans. Break Phase 0–1 into a separate implementation plan under `docs/superpowers/plans/` if needed.

**Goal:** Sync the same owner’s BuxMuse data across iPhone and iPad automatically, without a BuxMuse server, with clear opt-in privacy.

**Architecture:** Hybrid sync — **SwiftData + CloudKit** for core financial records, **CloudKit custom records** (or iCloud Documents) for JSON stores and files. Reuse concepts from the existing `.buxmuse` archive payload as the sync contract.

**Privacy model:** User’s **private iCloud container** only. Opt-in toggle. No developer-readable cloud copy unless optional client-side encryption is added later.

**Tech stack:** Swift 6, SwiftUI, SwiftData, CloudKit, iOS 18+ (iOS 26 primary), existing `BuxMuseArchiveService` payload shape.

---

## Current state (inventory)

| Store | Location | Sync complexity |
|-------|----------|-----------------|
| Expenses, goals, subscriptions, categories, merchants, insights metadata | SwiftData (`BuxMuse_v3.store`) | Medium — best CloudKit fit |
| Settings, workspaces, feature flags | `settings_store_v1.json` + UserDefaults | Medium — JSON blob or migrate |
| Studio Pro | `studio_hub.json` | Medium |
| Simple Studio | `simple_studio.json` | Medium |
| Receipts, scans, agreement PDFs, business card photos | Application Support folders | High — binary assets |
| Money Map node positions | UserDefaults | Low |
| Tax preset catalog | Bundled + remote refresh | **Do not sync** |
| Manual backup | `.buxmuse` encrypted archive | Keep as escape hatch |

**North star:** `BuxMuseArchivePayload` already defines what “the app” means for export — use the same scope for sync.

---

## Product decisions (lock before Phase 0)

| Decision | Recommendation |
|----------|----------------|
| Opt-in | **Off by default.** Settings → “Sync with iCloud” with plain-language explanation. |
| Identity | Same **Apple ID** on both devices. |
| Encryption | **Phase 1:** Apple’s private CloudKit encryption. **Later:** optional client-side layer if needed. |
| Conflict policy | **Per-record `modifiedAt` + device ID.** Newer wins; duplicates flagged, not silently merged for money. |
| Deletes | **Soft tombstones** (`deletedAt`) so deletes propagate. |
| Coexist with manual backup | Keep `.buxmuse` backup/restore. Sync and backup are complementary. |
| Complete data wipe | Offer **“Delete from this device”** vs **“Delete from iCloud too.”** |
| Widget / Live Activity | Read from same synced store; no separate sync path. |

---

## Phased rollout

### Phase 0 — Foundation (1–2 weeks)

**Ship nothing user-visible except prep.**

- Add iCloud capability + CloudKit container (`iCloud.com.buxmuse.app`) to app + widget entitlements.
- Add `SyncCoordinator` / account-status monitoring (`CKAccountStatus`, network, low power).
- Settings UI shell: toggle (disabled), status (“Signed in to iCloud”, “Sync paused”, “Last synced …”).
- Add sync metadata fields to models: `syncRevision`, `modifiedAt`, `originDeviceId`, `isDeleted`.
- Document migration from `BuxMuse_v3` → new CloudKit-enabled store with one-time import.

**Exit criteria:** App builds with iCloud entitlements; no data movement yet; tests pass.

---

### Phase 1 — Core financial sync (MVP) (3–4 weeks)

**What syncs:**

- Expenses / transactions
- Goals + contributions
- Subscriptions, categories, merchants (SwiftData entities)
- Workspaces (`Hustle`) + selected workspace
- Core settings from `SettingsStore` (not every UserDefaults toggle on day one)

**How:**

- Enable **SwiftData + CloudKit** private database for financial entities.
- Mirror `HustleManager` + critical settings into SwiftData entities **or** one CloudKit “settings blob” record updated on save.
- On toggle ON: upload local → merge with cloud → refresh `BuxMuseBrain` snapshots.
- Background: SwiftData cloud mirroring handles push; add explicit “Sync now” for user confidence.

**Conflict rules (MVP):**

- Same UUID, different content → keep newer `modifiedAt`.
- Same UUID created on two devices offline → show **“Review duplicate”** in Settings (don’t auto-merge amounts).

**Exit criteria:** Add expense on iPhone → appears on iPad; delete propagates; offline edits reconcile on reconnect.

---

### Phase 2 — Studio & preferences (2–3 weeks)

**What syncs:**

- `StudioSnapshot` (studio_hub.json equivalent)
- `SimpleStudioSnapshot`
- Remaining settings / feature flags in UserDefaults
- Money Map layout offsets

**How:**

- CloudKit custom record type with JSON field (monitor ~1MB limits), **or** iCloud Documents folder `Studio/` with coordinated file sync.

**Exit criteria:** Invoice draft on iPad visible on iPhone; workspace theme selection consistent.

---

### Phase 3 — Binary assets (3–5 weeks)

**What syncs:**

- Receipt images, Simple Studio scans, agreement PDFs, business card photos, merchant logos

**How:**

- **CKAsset** per file with metadata record (path, parent ID, checksum, modifiedAt).
- Background upload/download queue; Wi‑Fi-only option in Settings.
- Dedupe by content hash where possible.

**Exit criteria:** Receipt photo on one device opens on the other; storage audit totals stay sane.

---

### Phase 4 — Polish & trust (1–2 weeks)

- Sync status dashboard in Settings (pending uploads, conflicts, last error).
- Privacy copy aligned with `BuxStorageAuditEngine` / Data Guard.
- Widget reads synced data without stale cache bugs.
- “Pause sync” / “Sync on Wi‑Fi only”.
- Localization (EN + ES).

---

## Architecture

```
Each Device                          User Private iCloud
───────────                          ───────────────────
BuxMuse UI / Brain
    │
    ├── SwiftData + CloudKit Mirror ◄──► CloudKit Private DB
    ├── Studio / Settings JSON      ◄──► CloudKit records / Documents
    ├── Receipts & PDFs             ◄──► CKAssets
    └── SyncCoordinator (orchestrates enable/disable, account status, brain refresh)
```

**Key principle:** One `SyncCoordinator` owns enable/disable, account status, and “refresh brain after merge” — don’t scatter CloudKit calls across views.

---

## Files / areas likely touched

| Area | Role |
|------|------|
| `PersistenceController.swift` | CloudKit-enabled `ModelConfiguration` |
| `SwiftDataModels.swift` | Sync metadata fields |
| `BuxMuseBrain.swift` | Reload after remote changes |
| `SettingsStore.swift` | Sync toggle + export slice for cloud |
| `StudioStore.swift` / `SimpleStudioStore.swift` | Push/pull hooks |
| `BuxMuseArchiveService.swift` | Reuse payload shape for initial bulk upload |
| `BackupRestoreSettingsView.swift` | Copy explaining sync vs backup |
| `BuxMuse.entitlements` | iCloud + CloudKit |
| **New:** `Core/Sync/BuxCloudSyncCoordinator.swift` | Orchestration |
| **New:** `BuxMuseTests/CloudSyncTests.swift` | Conflict + migration tests |

---

## Risks & mitigations

| Risk | Mitigation |
|------|------------|
| SwiftData + CloudKit schema migration breaks existing users | New store name + one-time import; keep v3 fallback |
| JSON + SwiftData double source of truth | Phase 1: clear ownership rules; long-term migrate JSON into SwiftData |
| Large Studio PDFs blow CloudKit quotas | Wi‑Fi-only asset sync; size caps; user warning |
| User disables iCloud mid-sync | Graceful pause; local data remains |
| Financial duplicate conflicts | Never silent double-count; review queue |
| Widget stale data | `WidgetCenter.reloadTimelines` on sync completion |

---

## Testing plan

- Two simulators / devices, same Apple ID sandbox account
- Offline edit on both → reconnect → verify conflict policy
- Toggle sync off/on → no data loss
- Complete wipe with “remove from iCloud”
- Restore `.buxmuse` over synced account → explicit “Replace iCloud data?” prompt
- Performance: 5k expenses initial upload
- Regression: existing backup/restore tests still pass

---

## Settings UX (copy direction)

- **Toggle label:** “Sync with iCloud”
- **Subtitle:** “Keeps your expenses, goals, and Studio data up to date across your devices. Stored in your private iCloud account — not on BuxMuse servers.”
- **States:** Off · Syncing · Up to date · Paused (no iCloud account) · Conflict needs review

---

## Timeline estimate

| Phase | Duration | User-visible |
|-------|----------|--------------|
| 0 Foundation | 1–2 wk | No |
| 1 Core sync | 3–4 wk | Yes (MVP TestFlight) |
| 2 Studio | 2–3 wk | Yes |
| 3 Assets | 3–5 wk | Yes |
| 4 Polish | 1–2 wk | Yes |

**Total:** ~10–16 weeks for full parity with manual backup scope.

---

## First steps when 1.0.8 work begins

1. Lock product decisions (opt-in, conflict UX, wipe behavior).
2. Spike: SwiftData + CloudKit with **one entity** (`ExpenseEntity`) on a branch.
3. If spike is stable, implement Phase 0 + Phase 1 behind a feature flag for internal TestFlight.

---

## Out of scope for 1.0.8 unless explicitly added

- BuxMuse-operated sync server
- Family Sharing / multi-user accounts
- Syncing tax preset catalog (bundled/remote only)
- Replacing manual `.buxmuse` backup (keep both)
