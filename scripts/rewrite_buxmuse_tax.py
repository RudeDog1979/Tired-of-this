#!/usr/bin/env python3
"""Rewrite income_tax and notes for self-employed focus. Preserves all other fields."""

import json
from pathlib import Path

DISCLAIMER = "This is informational reference text, not legal advice."

def notes(*parts: str) -> str:
    body = " ".join(p.strip() for p in parts if p.strip())
    return f"{body}\n\n{DISCLAIMER}"

REWRITES = {
    "US": {
        "income_tax": "Self-employed income is reported on Schedule C (sole proprietors) or through a pass-through entity. Net profit is subject to federal income tax (10%–37%) plus self-employment tax of 15.3% on net earnings (Social Security and Medicare), with half of SE tax generally deductible. Quarterly estimated payments are usually required.",
        "notes": notes(
            "State and local income taxes vary; some states have no personal income tax.",
            "Sales tax or economic nexus rules may require registration if you sell taxable goods or services.",
            "Many freelancers use an LLC for liability separation; default tax treatment for a single-member LLC is still Schedule C unless you elect corporate taxation."
        ),
    },
    "DO": {
        "income_tax": "Self-employed individuals and independent professionals generally file as persona física with business income and pay progressive ISR on net income from 0% up to 25%, similar to employed individuals but without payroll withholding—you declare and pay through DGII filings.",
        "notes": notes(
            "VAT (ITBIS) registration is required once you exceed turnover thresholds or operate in taxable activities.",
            "Territorial system: Dominican-source income is taxable; keep invoices and DGII receipts.",
            "Informal cash work is common but legally still reportable; enforcement varies by sector."
        ),
    },
    "MX": {
        "income_tax": "Freelancers and sole proprietors (personas físicas con actividad empresarial) pay ISR on net business profit under progressive rates from about 1.92% to 35%. Simplified regimes such as RESICO (for eligible lower-income activities) and RIF (legacy small-taxpayer regime in transition) offer flat or reduced rates if you qualify.",
        "notes": notes(
            "VAT (IVA) registration is required when you exceed SAT thresholds or issue facturas.",
            "Border zone (8% IVA) and certain free-zone incentives may apply to location.",
            "Facturación electrónica (CFDI) is mandatory for most business receipts."
        ),
    },
    "CA": {
        "income_tax": "Self-employed Canadians report business income on Form T2125; net profit is taxed like other personal income at federal rates (15%–33%) plus provincial/territorial tax. You pay both employer and employee portions of CPP contributions (and optionally EI in Quebec for some self-employed persons).",
        "notes": notes(
            "GST/HST registration is mandatory once worldwide taxable supplies exceed CAD 30,000 in four consecutive quarters.",
            "Quarterly instalments may be required if tax owing exceeds thresholds.",
            "Combined rates vary significantly by province."
        ),
    },
    "GB": {
        "income_tax": "Self-employed income is taxed the same way as employment income through Self Assessment: progressive rates of 0%, 20%, 40%, and 45% on taxable profit after the Personal Allowance. You also pay Class 2 and Class 4 National Insurance on profits (Class 2 largely merged into Class 4 rules in recent years).",
        "notes": notes(
            "VAT registration is required if taxable turnover exceeds £90,000 (2024/25 threshold—verify current figure).",
            "File an annual Self Assessment return and make payments on account.",
            "Scotland has devolved income tax bands; NI rules apply UK-wide."
        ),
    },
    "DE": {
        "income_tax": "Freelancers (Freiberufler) and sole traders (Gewerbetreibende) pay Einkommensteuer on net profit at progressive rates from 0% to 45%. Gewerbetreibende may also owe trade tax (Gewerbesteuer) depending on municipality and allowance; many Freiberufler are exempt from Gewerbesteuer.",
        "notes": notes(
            "VAT (Umsatzsteuer) registration is generally required once small-business turnover exceeds €22,000 (Kleinunternehmerregelung limit—verify current).",
            "Health and long-term care insurance are mandatory; pension insurance may apply to some trades.",
            "Keep EÜR (income-surplus accounting) or balance-sheet records."
        ),
    },
    "FR": {
        "income_tax": "Self-employed income is taxed under the personal income tax (IR) system on net profit, with progressive rates from 0% to 45%. Micro-entrepreneurs (auto-entrepreneurs) under the micro-fiscal regime pay tax on a flat percentage of turnover with simplified social contributions instead of full real-profit accounting if within turnover ceilings.",
        "notes": notes(
            "VAT (TVA) registration depends on regime and turnover; micro-entrepreneurs have specific TVA rules.",
            "Social charges (URSSAF) are a major cost for independents and are paid regularly.",
            "Overseas departments may have adapted rates."
        ),
    },
    "ES": {
        "income_tax": "Autónomos (self-employed) pay IRPF on net business profit at progressive state rates plus regional scales, combined up to roughly 47% at high incomes. You register in the RETA social-security system and pay cuota de autónomos monthly regardless of profit in most cases.",
        "notes": notes(
            "VAT (IVA) registration is required for most commercial activity; IGIC applies in the Canary Islands.",
            "Flat-rate schemes (tarifa plana) reduce social-security cuota for new autónomos for a limited period.",
            "Quarterly model 130/131 prepayments are typical."
        ),
    },
    "IT": {
        "income_tax": "Self-employed workers pay IRPEF on net profit at progressive rates from 23% to 43%, plus regional and municipal surcharges. The flat-rate regime (regime forfettario) allows eligible freelancers to pay tax on a coefficient of gross receipts at a single rate (5% startup / 15% standard) if turnover and activity limits are met.",
        "notes": notes(
            "VAT (IVA) registration is generally required unless exempt under forfettario (with turnover limits).",
            "INPS social contributions are paid on a minimum or declared income base.",
            "Partita IVA registration is required to invoice as a professional."
        ),
    },
    "IN": {
        "income_tax": "Freelancers and sole proprietors pay income tax on net professional or business income under progressive slabs (0%–30% under the old regime, or optional new regime with lower rates and fewer deductions). Presumptive taxation (44ADA/44AD) may apply to certain professions and businesses on a percentage of gross receipts.",
        "notes": notes(
            "GST registration is mandatory if aggregate turnover exceeds the threshold (₹20 lakh for services in most states, ₹40 lakh for goods—verify current limits).",
            "Advance tax instalments apply if liability exceeds ₹10,000.",
            "Much informal freelance work exists; legally income is still taxable."
        ),
    },
    "BR": {
        "income_tax": "Self-employed individuals report income via Carnê-Leão (monthly) for certain receipts and annual DIRPF. Progressive IRPF rates run from 0% to 27.5% on taxable income. MEI (Microempreendedor Individual) pays a fixed monthly DAS covering simplified taxes for eligible micro-businesses; Simples Nacional is available for slightly larger sole props with combined tax on gross revenue.",
        "notes": notes(
            "MEI turnover cap and permitted activities are strictly limited.",
            "ISS (service tax) and other municipal taxes may apply outside MEI/Simples.",
            "NF-e or NFS-e invoicing rules vary by municipality."
        ),
    },
    "AR": {
        "income_tax": "Self-employed monotributistas pay a fixed monthly lump sum (Monotributo) covering income tax, pension, and medical components based on category and gross billing. Outside Monotributo, autónomos pay Ganancias on net profit at progressive rates from 5% to 35%.",
        "notes": notes(
            "Monotributo has strict billing ceilings by category; exceeding them forces reclassification.",
            "IVA registration rules differ between Monotributo and responsable inscripto regimes.",
            "Provincial gross-income tax (IIBB) may apply separately."
        ),
    },
    "CL": {
        "income_tax": "Independent workers and sole proprietors pay impuesto global complementario on net business income at progressive rates from 0% to 40%. Simplified regimes exist for small taxpayers with presumptive or simplified accounting if eligible.",
        "notes": notes(
            "VAT (IVA) registration required when activity is commercial or turnover exceeds SII thresholds.",
            "Monthly provisional payments (PPM) are common.",
            "Boleta de honorarios or factura electrónica required for most services."
        ),
    },
    "CO": {
        "income_tax": "Independent contractors and sole merchants pay renta on net business income at progressive rates from 0% to 39%. Régimen Simple de Tributación (RST) offers unified tax on gross income tiers for eligible small businesses.",
        "notes": notes(
            "VAT (IVA) registration as responsable if thresholds or activity require it.",
            "Retención en la fuente often applies when large clients pay freelancers.",
            "RUT registration with DIAN is mandatory for invoicing."
        ),
    },
    "PE": {
        "income_tax": "Self-employed workers with negocio unipersonal or independent services pay IR on net income at progressive rates from 8% to 30%. Régimen MYPE Tributario and nuevo RUS offer simplified rates on gross income for very small businesses if qualified.",
        "notes": notes(
            "IGV (VAT) registration required when turnover exceeds SUNAT thresholds.",
            "Fourth-category income (honorarios) has withholding by clients; fifth-category rules differ for employees.",
            "Electronic invoicing (SEE) is mandatory for most taxpayers."
        ),
    },
    "JP": {
        "income_tax": "Self-employed individuals (kojin jigyo) file a final tax return on net business profit. National income tax is progressive from 5% to 45%; local inhabitant tax adds roughly 10%. Blue-form (ao shinkoku) filing allows enhanced deductions with proper bookkeeping.",
        "notes": notes(
            "Consumption tax registration required if taxable sales exceeded ¥10 million in the base period (with exceptions).",
            "National health insurance and national pension contributions are self-paid.",
            "Consumption tax filing depends on simplified or standard method."
        ),
    },
    "CN": {
        "income_tax": "Self-employed individuals (个体工商户) and freelancers generally pay individual income tax on business profit at progressive rates from 3% to 45% under the business-income category, or a simplified assessed method where local tax offices apply. Employee-style salary IIT rules do not apply to true sole-trade business income.",
        "notes": notes(
            "VAT registration required for VAT-taxable activities above thresholds; small-scale taxpayer status may allow 1% or 3% simplified VAT.",
            "Social insurance participation varies by city and hukou/residency rules.",
            "Many gig workers operate informally; formal registration requires a business license."
        ),
    },
    "AU": {
        "income_tax": "Sole traders report business income on their individual tax return; net profit is taxed at resident progressive rates from 0% to 45% plus Medicare levy (2%). Same personal rates as employees—no separate corporate layer for sole traders.",
        "notes": notes(
            "GST registration mandatory if annual GST turnover is AUD 75,000 or more.",
            "Pay-as-you-go (PAYG) instalments may apply once earning business income.",
            "Superannuation is not mandatory for yourself but may be for any employees."
        ),
    },
    "KR": {
        "income_tax": "Self-employed business owners and freelancers pay global income tax on net business income at progressive rates from 6% to 45%, similar to combined employment income but reported through business filings. Simplified bookkeeping taxpayers (simple ledger) have streamlined rules under turnover limits.",
        "notes": notes(
            "VAT registration required if supply value exceeds KRW 48 million.",
            "Local income tax adds roughly 10% of national income tax.",
            "National health insurance premiums adjust based on declared business income."
        ),
    },
    "SG": {
        "income_tax": "Sole proprietors and partners pay tax on business profit as part of personal income at progressive resident rates from 0% to 24%—same schedule as employment income, but you deduct allowable business expenses first.",
        "notes": notes(
            "GST registration mandatory if taxable turnover exceeds SGD 1 million (voluntary registration possible below).",
            "No capital gains tax for most individuals; territorial system taxes Singapore-source income.",
            "CPF contributions apply differently—self-employed persons may contribute to MediSave."
        ),
    },
    "AF": {
        "income_tax": "Self-employed and business income is theoretically subject to progressive individual income tax up to 20%, but enforcement is weak and much economic activity is informal following years of instability.",
        "notes": notes(
            "Business Receipt Tax (10%) applies to gross receipts for many businesses.",
            "Formal registration with tax authorities is uncommon outside major cities.",
            "System is largely informal; rely on local guidance if operating formally."
        ),
    },
    "AL": {
        "income_tax": "Self-employed individuals and sole traders pay personal income tax on net business profit at progressive rates of 0%, 13%, and 23%. Small businesses with turnover below ALL 14 million may qualify for 0% CIT, but personal tax on distributions/profit still applies per structure.",
        "notes": notes(
            "VAT registration required once turnover exceeds ALL 10 million.",
            "Social and health contributions apply to self-employed registrations.",
            "Many small traders operate informally in rural areas."
        ),
    },
    "DZ": {
        "income_tax": "Auto-entrepreneurs and sole proprietors (personne physique) pay IRG on net professional income at progressive rates from 0% to 35%. Flat-rate and simplified regimes exist for small activities under annual finance law limits.",
        "notes": notes(
            "VAT (TVA) registration required above turnover thresholds.",
            "IFU (single tax declaration) obligations apply once registered.",
            "Tax rules are centralized; informal street trade is common but taxable if registered."
        ),
    },
    "AD": {
        "income_tax": "Self-employed residents pay personal income tax on net business profit at progressive rates capped at 10%—one of Europe's lowest. No separate corporate layer for sole traders.",
        "notes": notes(
            "IGI (VAT) at 4.5% applies to most commercial supplies; registration required for business activity.",
            "Social security (CASS) contributions apply to self-employed workers.",
            "No wealth, inheritance, or gift tax for individuals."
        ),
    },
    "AO": {
        "income_tax": "Self-employed professionals and sole proprietors pay IRT on net business income at progressive rates from 0% to 25%. Simplified tax regime available for small businesses meeting turnover criteria.",
        "notes": notes(
            "VAT (IVA) at 14% applies; registration required for taxable activity.",
            "Much informal commerce exists outside Luanda; formal sector uses electronic invoicing.",
            "Withholding on service payments may apply."
        ),
    },
    "AI": {
        "income_tax": "There is no personal income tax for self-employed residents or non-residents in Anguilla. Business income is not subject to income tax at individual level.",
        "notes": notes(
            "No VAT; stamp duties and fees may apply to transactions.",
            "Tax-neutral jurisdiction—registration still required for licensed business activity.",
            "No corporate tax for IBCs; local sole traders operate under business license rules."
        ),
    },
    "AQ": {
        "income_tax": "Not applicable. Antarctica has no permanent population, no national tax authority, and no self-employment tax system.",
        "notes": notes(
            "Expedition staff and researchers are taxed by their home country employer or contract jurisdiction, not Antarctica.",
            "No VAT or business registration on the continent."
        ),
    },
    "AG": {
        "income_tax": "Residents pay 0% personal income tax on self-employed and employment income. Non-residents may face withholding on Antigua-source fees.",
        "notes": notes(
            "ABST (VAT) at 15% applies to taxable supplies; registration required for trading businesses.",
            "Personal income tax was abolished for residents in 2016.",
            "Business license and corporate tax may apply if operating through a company."
        ),
    },
    "AM": {
        "income_tax": "Self-employed individuals and sole proprietors pay flat 20% personal income tax on net business profit—the same rate as general personal income. Micro-entity and turnover-tax simplifications exist for very small businesses.",
        "notes": notes(
            "VAT registration required if turnover exceeds AMD 115 million.",
            "IT sector and free-economic-zone incentives may reduce effective burden for qualifying freelancers.",
            "Social payments apply once registered as an entrepreneur."
        ),
    },
    "AW": {
        "income_tax": "Self-employed residents pay progressive income tax on net profit from 7% up to 52%—the same personal schedule as employees, but you declare business income through self-assessment rather than payroll withholding.",
        "notes": notes(
            "Turnover taxes (BBO/BAVP/BAZV at 6%) apply instead of VAT on many services.",
            "Social premium (AOV/AWW) contributions are required for registered businesses.",
            "Dutch Caribbean autonomous country with its own tax administration."
        ),
    },
}


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    src = root / "BuxMuse" / "Resources" / "buxmuse_tax.json"
    data = json.loads(src.read_text(encoding="utf-8"))

    for code, entry in data["countries"].items():
        if code not in REWRITES:
            raise KeyError(f"Missing rewrite for {code}")
        entry["income_tax"] = REWRITES[code]["income_tax"]
        entry["notes"] = REWRITES[code]["notes"]

    data["updatedAt"] = "2026-05-27T12:00:00Z"

    src.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Updated {len(REWRITES)} countries in {src}")


if __name__ == "__main__":
    main()
