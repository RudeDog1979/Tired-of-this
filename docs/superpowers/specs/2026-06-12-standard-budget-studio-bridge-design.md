# Standard Budget — Studio Bridge

**Date:** 2026-06-12  
**Status:** Shipped

## Problem

Freelancers and informal earners often log money-in through **Studio** (Simple entries or Pro paid invoices) while the main app **Standard budget** only counts income from **Add Income** in Expenses/Home. That forces double entry or leaves the dashboard limit out of sync with real earnings.

## Solution

Optional settings (Settings → Budget → Standard mode, when Studio is enabled):

| Mode | Setting |
|------|---------|
| **Simple Studio** | Include Simple Studio income |
| **Pro Studio** | Include Pro Studio income |

When on, qualifying Studio money-in for the **current pay period** adds to Standard budget **earned income** — same pool that drives the dashboard ring, remaining balance, and expense warnings.

## Simple Studio — what counts

Uses the same rules as Simple Studio “made” / tax bridge (`TaxEnvelopeContextBridge.incomeAmount`):

| Entry kind | Counts when |
|------------|-------------|
| Income | Always |
| Job | Full amount + tip |
| Repayment received | Full amount + tip |
| They owe me | When marked paid |

Date filter: entry `createdAt` within pay period.

## Pro Studio — what counts

| Invoice | Counts when |
|---------|-------------|
| Paid invoice | `status == .paid`, `paymentDate` within pay period, `total > 0` |

Synthetic tax-bridge invoices (`notes == "TaxEnvelope synthetic"`) are excluded.

## Dedup (same payment in both ledgers)

When the bridge is on, Studio supplement **skips** items that match **Add Income** already in the earned pool:

- Same **amount** (exact)
- Same **calendar day** (`startOfDay` on entry date / invoice `paymentDate` vs income `date`)
- Respects **Income source** filter (Salary vs Other) — only matches income that counts in the pool
- One-to-one pairing when multiple same-day same-amount payments exist

Add Income remains the source of truth; Studio only fills gaps. Dashboard shows footnote when adjustment > 0: *“Studio income adjusted by … — already logged in Add Income”*.

## Pay period

Uses the user’s **Payday Schedule** from Budget settings (weekly, biweekly, month anchors, etc.) — **not** calendar month.

## Interaction with other settings

| Setting | Behavior |
|---------|----------|
| **Optional spending cap** | `effectiveLimit = min(earned + studio supplement, cap)` when both apply |
| **Budget counts** (Paycheck & salary / Freelance & other) | Filters **Add Income** records only; Studio dedup uses the same rule |
| **Expense warnings** | Warnings use combined earned pool when toggle is on |
| **Envelope mode** | Toggles hidden; supplement not applied |

## Simple Studio period alignment

Simple Studio hub, My Money, and Home widget **Made/Spent** use the same pay period as Standard budget (`BuxBudgetPeriodCalculator`). Section title: **This month** for month-aligned cycles; **This period** + date range for weekly/biweekly/custom.

## Defaults & safety

- **Off by default** — existing users unchanged
- **No auto-sync to Expenses ledger** — virtual supplement for budget math only

## Implementation

| File | Role |
|------|------|
| `StandardBudgetStudioBridge.swift` | Simple + Pro supplements, dedup vs Add Income |
| `BudgetPeriodEngine.swift` | `supplementalEarned` parameter on `computeStandardBudget` / warnings |
| `BuxMuseBrain.swift` | Resolves supplements; adds to `incomePoolThisPeriod` and standard limit |
| `SettingsStore.swift` | `includeSimpleStudioIncomeInBudget`, `includeProStudioIncomeInBudget` |
| `BudgetSettingsView.swift` | Mode-specific toggles + footnotes |
| `DashboardView.swift` | Studio badges + dedup footnote |
| `StandardBudgetStudioBridgePromptCard.swift` | Discoverability on Home + Studio hubs |
| `AddExpenseViewModel.swift` | Warnings include deduped supplement |
