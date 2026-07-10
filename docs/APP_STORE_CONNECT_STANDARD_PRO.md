# App Store Connect — Standard / Pro (1.1.2)

Last updated: **2026-07-10**

Ship **1.1.2 (build 23)** with a clean two-tier catalog. Do **not** attach stuck `.v2` products.

---

## Before you touch Connect

1. Cancel the stuck **1.1.1** submission if it is still open (**Cancel Submission**).
2. Leave old `.v2` products in place (IDs are burned). Do **not** delete them. Do **not** attach them.
3. App download price: **Free ($0.00)** under Distribution → Pricing.
4. Paid Apps Agreement: **Active**.

---

## Create one new subscription group

**Monetization → Subscriptions → +**

| Field | Value |
|--------|--------|
| Group reference name | `BuxMuse` |
| Group display name (EN) | `BuxMuse` |
| Group display name (es-MX / es-ES) | `BuxMuse` |

Arrange levels: **Pro = Level 1** (highest), **Standard = Level 2**.

### Products (exact IDs — must match the binary)

| Level | Reference name | Product ID | Duration | Price (UK) | Intro |
|-------|----------------|------------|----------|------------|-------|
| 1 | BuxMuse Pro Monthly | `com.buxmuse.app.pro.monthly.v3` | 1 month | £4.99 | **None** |
| 1 | BuxMuse Pro Yearly | `com.buxmuse.app.pro.yearly.v3` | 1 year | £39.99 | **None** |
| 2 | BuxMuse Standard Monthly | `com.buxmuse.app.standard.monthly.v3` | 1 month | £1.99 | **7-day free** |
| 2 | BuxMuse Standard Yearly | `com.buxmuse.app.standard.yearly.v3` | 1 year | £14.99 | **7-day free** |

### Suggested localization copy

**Standard Monthly / Yearly**

- Display name: `BuxMuse Standard Monthly` / `BuxMuse Standard Yearly`
- Description (≤55): `Personal finance + Simple Studio.`

**Pro Monthly / Yearly**

- Display name: `BuxMuse Pro Monthly` / `BuxMuse Pro Yearly`
- Description (≤55): `All Standard features + Pro Studio.`

Add **English (U.K.)**, **Spanish (Mexico)**, **Spanish (Spain)** on group + each product. Upload a paywall screenshot on each product’s Review Information.

---

## Submit 1.1.2

1. Archive **1.1.2 (23)** → Upload to App Store Connect.
2. Create version **1.1.2** (or open draft) → select build **23**.
3. **In-App Purchases and Subscriptions → +** → attach **only** the four `.v3` products (all must be **Ready to Submit**).
4. Paste Review Notes:

```
This build uses a single subscription group with two tiers:
- BuxMuse Standard (monthly/yearly): personal finance + Simple Studio. 7-day free trial on Standard only.
- BuxMuse Pro (monthly/yearly): includes all Standard features + Pro Studio tools. No trial; paid upgrade.

No enterprise / contact-sales links. No separate Studio add-on IAPs.
Product IDs: com.buxmuse.app.standard.monthly.v3, .standard.yearly.v3, .pro.monthly.v3, .pro.yearly.v3.
Sandbox: complete onboarding → Standard paywall → start trial → Settings → upgrade to Pro.
```

5. **Submit for Review**.

---

## Dynamic pricing (binary)

The app never hardcodes currency. All paywall prices use StoreKit 2 `Product.displayPrice` (and subscription period from the product). Reviewers in US/EU/JP see $, €, ¥ automatically from the storefront.

Local Xcode testing: scheme already points at `BuxMuse/Configuration/BuxMuse.storekit`. Change storefront via **Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration / Application Region**.


| Tier | Unlocks |
|------|---------|
| Standard | Full app + Simple Studio |
| Pro | Everything in Standard + Pro Studio tools |

Legacy `.v2` / older IDs still restore entitlements in code but are not offered for sale.
