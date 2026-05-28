# Phase 3 QA Checklist (Merchants & Connectivity)

Manual pass before release polish. Mark each item **Pass** / **Fail** / **N/A**.

## Merchant suggestions (add expense)

- [ ] Type `M&S` → multiple rows (aliases, history, “Add as new merchant”)
- [ ] Tap **Marks & Spencer** (or alias) → field updates, list closes
- [ ] Type full **Marks and Spencer** → still matches saved/history rows
- [ ] **Use …?** chip only when exactly one non-alias saved match
- [ ] Save with ambiguous name (no pick) → pick sheet appears
- [ ] After pick → expense saves with correct `merchantId` / label

## Edit expense

- [ ] Edit existing expense → merchant name and link preserved
- [ ] Change merchant via suggestions → updates on save

## Merchants hub (Expenses → merchants)

- [ ] Expand merchant → **Label** field saves (disambiguator)
- [ ] Duplicate-name hint when another merchant shares normalized name
- [ ] Preview line shows `Name · Label` when label set
- [ ] Subscription toggle still saves

## Filters (Expenses → advanced filters)

- [ ] **Search merchants** finds by name / label
- [ ] **Any merchant** clears filter
- [ ] Selected merchant shows checkmark + **Clear**
- [ ] Filtered list still respects other filters (category, type, heat)

## Connectivity & logos

- [ ] Airplane mode → offline toast (readable)
- [ ] Back online → green toast (readable)
- [ ] Merchant logos: cache first; no endless spin offline
- [ ] Online: favicon fetch still works for new merchants

## Keyboard (native dismiss)

- [ ] New Client: scroll form → keyboard dismisses; no duplicate accessory icons
- [ ] Add expense / Business profile: swipe keyboard down works
- [ ] Decimal/phone pads: no stuck keyboard after scrolling away

## Studio navigation (visual)

- [ ] Push Studio tool (Clients, Mileage, Tax, etc.) → no harsh white/black flash behind nav bar
- [ ] Studio themes / mesh still look correct on hub and pushed screens

## Regression guardrails

- [ ] Themes / appearance unchanged
- [ ] Tax Studio calculations unchanged
- [ ] BuxTips / news unchanged
- [ ] Mileage log + return trip still saves correctly

---

**Notes** (device, build, failures):
