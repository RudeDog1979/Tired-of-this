# Simple Studio — Product & V1 Spec

**Date:** 2026-05-30  
**Status:** Approved — implementation in progress

## Positioning

*Not a bank. Your private work ledger — local, secure, efficient.*

- **BuxMuse core** (Home, Expenses, Goals, Insights): free, always included
- **Simple Studio**: free when Studio is enabled — informal workers worldwide
- **Pro Studio**: paid upgrade — full tax, PDF invoices, CRM, analytics

## V1 North Star

Scan or tap → know what you kept → know who owes you → send a simple invoice via WhatsApp/IG/FB.

## Simple Studio Features (V1)

1. Compressed hub: today kept, 4 tiles, waiting-on list, mini chart, recent feed
2. + sheet: Scan first, Log money, Invoice, People
3. Daily money log: income, expense, job, advance, owed to me, I owe
4. Job pocket fields: materials, petrol, transport, advance on job entries
5. Customer memory (auto-built people list)
6. Simple tax 4-tile: made / spent / keep / might owe
7. My Money full-screen: donut + waiting bars + job pocket bars
8. Persona picker at first unlock (tasks, jobs, driving, shop, lending, other)
9. Pro upgrade gate in Settings

## Pro Boundary

Simple: scan, log, simple invoice image, debt, charts, people memory  
Pro: PDF designer, Tax Studio, projects, mileage, full CRM, compliance

## Data Contract

See `SimpleStudioModels.swift` — JSON store at `Application Support/Studio/simple_studio.json`

## Phases

- **A:** Mode flag, persona, hub shell, router ✅
- **B:** Log money, store CRUD, hub metrics ✅
- **B2:** Job/people edits, contact info, paid fixes ✅
- **C:** Scan → editable chips (Simple Studio scanner) ✅
- **D:** Simple invoice share card ✅
- **E:** Debt flows, reminders ✅
- **F:** Polish, perf, tests
