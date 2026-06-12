# BuxMuse session updates — 8 June 2026

Summary of features, fixes, and polish shipped in this development session.

---

## Tax savings (Tax Envelope) — worldwide

New **Tax savings** module (`BuxMuse/Features/Studio/TaxEnvelope/`) for Simple + Pro Studio:

- **Catalog-backed intelligence** — set-aside rates, jar targets, and coach copy from `buxmuse_tax_compute.json` / monthly tax catalog via `WorldTaxEngine`; no hardcoded tax advice.
- **TaxEnvelopeBrain** — single refresh path wired from `AppContainer`, Pro/Simple hubs, log-money, and tax tile.
- **Onboarding** — 4-step flow: self-employed toggle, pay frequency, country from Settings, payment schedule + default save-rate guide.
- **Payment schedule** — user picks quarterly / yearly / monthly; dynamic “Due soon” labels.
- **Manual set-aside** — “I set money aside” sheet + deposits tracked in `TaxEnvelopeState`.
- **Year summary** — in-app preview + PDF export via native share (no blank sheet on failure).
- **Hub integration** — hero section, tile on Pro/Simple hubs, set-aside prompt after logging income.
- **Tests** — `BuxMuseTests/TaxEngine/TaxEnvelopeEngineTests.swift`.

### Phase 29 UX renames (Tax jar → Tax savings)

- Tax jar → **Tax savings**
- Tax jar balance → **My set-aside**
- Quarterly coach → **Due soon**
- Add to jar → **I set money aside**

Localization phases 28–30 merged into `Localizable.xcstrings` (+ scripts in `scripts/localization/`).

---

## Simple Studio — quotes, not agreements

- **Pro agreements removed** from Simple entry paths; Simple uses **job quotes** (`SimpleStudioJobDealSection`, `SimpleStudioJobQuoteSheet`).
- Hub Tools: **Quote a job** reminder banner.
- **Native share** for invoices and job quotes (`BuxShareItemsPayload`, `BuxActivityShareSheet`, `.buxShareSheetPresentation()`).
- **Invoice Save & send** — share sheet presents correctly (no dismiss-before-present bug).

---

## Country & region localization

- **CountryDisplayL10n** + **CountrySearchAliasStore** — localized country names at display time.
- **country_search_aliases.json** — 261/261 ISO regions, Spanish search aliases (`complete: true`).
- **build_country_search_aliases.py** — CLDR + extras pipeline.
- Settings country picker, tax country picker, and invoice party forms use localized names + search.

Tax country source: **Settings region** (`TaxEnvelopeSourceContext.appRegionCountryCode`), not GPS.

User-facing copy: **“BuxMuse Intelligence on device”** (not JSON/catalog jargon).

---

## Spanish localization — 100% display coverage

- **ExpenseDisplayL10n** — English keys stored in SwiftData; UI localizes at render (e.g. **Salary → Sueldo** on dashboard recent transactions).
- Income quick picks (`Salary`, `Refund`, `Gift`, etc.) localized everywhere labels appear.
- Catalog keys used in Swift: **100% es-419** after gap fill (tax profile strings, purge copy, expense UI).
- Hardcoded navigation titles moved to **`buxCatalogNavigationTitle`** where app locale must drive copy.
- Expense tab context menus, detail insights, vault overlay, and receipt parsing overlay localized.

---

## Data wipe — complete + double warning

**Settings → Backup & restore → Delete All Local App Data** now:

1. **First dialog** — lists everything including Tax savings, goals, Studio/Simple Studio, receipts, scans, backups.
2. **Final alert** — “Last chance… Nothing will remain” + **Erase everything permanently**.

**Purge scope** (nothing user-generated left):

| Layer | Cleared |
|--------|---------|
| Settings | Passcodes, preferences re-seeded |
| SwiftData | Expenses, goals, merchants, custom categories |
| Pro Studio | Clients, projects, invoices, receipts, agreements, business cards, **taxEnvelope** |
| Simple Studio | Entries, customers, invoices, JSON store |
| Files | Pro receipt images, scan images, silent backups |
| Caches | Merchant logos, tax translation cache |
| UserDefaults | Hustles, money map, notification state, tips/news, subscription dismissals |
| Live | Studio timer session, `taxEnvelopeBrain` refresh |

**Copy updates**

- Merchant logo blurb: no Google/DuckDuckGo — “refresh them automatically”.
- Success message mentions Tax savings and Studio data.

---

## Tax savings onboarding layout fix

Last onboarding step (payment schedule + set-aside %):

- **Label on its own line** — “Guía de apartado predeterminada” (no truncation).
- **Large % value** beside hidden-label stepper.
- **Back** compact; **Empezar ahorro fiscal** expands full width.
- Step content in **ScrollView** so footer buttons stay visible.

---

## Tax engine & catalog (supporting work)

- **global_tax_updater.py** — resume, T1 pin, local write, workflow improvements.
- iOS catalog merge preserves bundled T1 on remote refresh.
- Fiscal quarter period + unified **WorldTaxEngine** routing for hub/quarterly/simulator/sparkline.
- `buxmuse_tax_compute.json` updated.

---

## App audit (session)

- **Build:** green (iPhone 16 simulator).
- **Features:** Tax savings, Simple/Pro Studio, expenses, goals, subscription hub, tax reference, invoices, business cards, mileage, timer, money map, hustle matrix — connected; no placeholder flows found.
- **Spanish:** ≥98% effective UI coverage; catalog keys at 100% after this session.

---

## New & modified files (high level)

### New

- `BuxMuse/Features/Studio/TaxEnvelope/**`
- `BuxMuse/Core/Localization/CountryDisplayL10n.swift`
- `BuxMuse/Core/Localization/CountrySearchAliasStore.swift`
- `BuxMuse/Core/Localization/ExpenseDisplayL10n.swift`
- `BuxMuse/Features/Studio/Simple/Views/SimpleStudioJobDealSection.swift`
- `BuxMuse/Resources/country_search_aliases.json`
- `BuxMuseTests/TaxEngine/TaxEnvelopeEngineTests.swift`
- `scripts/build_country_search_aliases.py`
- `scripts/localization/build_phase28_tax_envelope.py`
- `scripts/localization/build_phase29_tax_savings_ux.py`
- `scripts/localization/build_phase30_tax_savings_l10n.py`
- `docs/localization/phase28-tax-envelope.json`
- `docs/localization/phase29-tax-savings-ux.json`
- `docs/localization/phase30-tax-savings-l10n.json`

### Key modified

- `DataSettingsView.swift` — double wipe, full purge, merchant copy
- `StudioStore.swift` — `taxEnvelope` reset on purge
- `TransactionStackViews.swift` — localized recent transaction names
- `TaxEnvelopeOnboardingView.swift` — layout fix
- `Localizable.xcstrings` — thousands of es-419 additions
- Simple Studio views, share helpers, hubs
- `BuxStorageAuditEngine`, `HustleManager`, `BuxNotificationInboxEngine`, `SimpleStudioScanImageStore`

---

## How to verify

1. **Tax savings** — Studio hub → Tax savings → complete onboarding → log income → set aside → year summary share.
2. **Spanish** — Settings → Spanish → log income as Salary → dashboard shows **Sueldo** / **Ingreso**.
3. **Wipe** — Settings → Delete All Local App Data → two warnings → confirm Tax savings and scans are gone after relaunch.
4. **Simple quote** — Simple Studio → job → Quote a job → share sheet.
5. **Onboarding step 4** — full label, visible %, full “Empezar ahorro fiscal” button.

---

*Generated at end of session — 8 June 2026.*
