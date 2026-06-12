# BuxMuse — translation preferences

## Target languages

- Primary: `es-419` (Latin America)
- Secondary: `es-ES` (Spain)
- Also maintain generic `es` where Xcode uses it

Default mode for catalog work: **refined** (translate → review → polish).

## Audience & tone

- Freelancers and small business owners
- **Tú** (informal), clear and direct
- Avoid Spain-only slang in `es-419`; avoid Latin-only slang in `es-ES`

## Do not translate

- BuxMuse
- Bux Canvas
- Studio (product tier name)
- PocketKeeps (sample brand in cards)
- Face ID, HealthKit, Apple Health (keep Apple product names)
- User names, merchant names, notes, invoice line items user typed
- Enum / API / file / key names

## Glossary (en → es-419 / es-ES)

| English | es-419 | es-ES | Notes |
|---------|--------|-------|-------|
| Home | Inicio | Inicio | Tab |
| Expenses | Gastos | Gastos | Tab |
| Settings | Ajustes | Ajustes | Tab |
| Studio | Studio | Studio | Product name |
| Done | Listo | Hecho | Sheet dismiss |
| Cancel | Cancelar | Cancelar | |
| Save | Guardar | Guardar | |
| Exit | Salir | Salir | Bux Canvas |
| Reset zoom | Restablecer zoom | Restablecer zoom | |
| Safe zone | Zona segura | Zona segura | Print / design |
| Background | Fondo | Fondo | |
| Layers | Capas | Capas | |
| Invoice | Factura | Factura | |
| Receipt | Recibo | Recibo | |
| Mileage | Millaje | Kilometraje | ES prefers kilometraje |
| Subscription | Suscripción | Suscripción | |
| Freelancer | Freelancer / autónomo | Autónomo | Prefer natural local term |

## Variant diffs (must differ when it matters)

| Concept | es-419 | es-ES |
|---------|--------|-------|
| Cell phone | celular | móvil |
| Computer | computadora | ordenador |
| Ticket (receipt) | recibo | ticket / recibo |
| You (UI) | tú | tú |

## Output format for catalog batches

When translating for `Localizable.xcstrings`, return JSON fragments keyed by **exact English source string** matching Swift literals, with `es`, `es-419`, and `es-ES` entries per key.
