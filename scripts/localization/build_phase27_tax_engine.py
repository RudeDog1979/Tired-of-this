#!/usr/bin/env python3
"""Phase 27 — Tax Engine I/J/L UI strings (EN keys → es-419 / es-ES)."""

from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "docs/localization/phase27-tax-engine-ijl.json"

# English key -> (es-419, es-ES)
T: dict[str, tuple[str, str]] = {
    # Phase J — income tax calculator
    "Catalog engine": ("Motor del catálogo fiscal", "Motor del catálogo fiscal"),
    "Net after tax: %@": ("Neto después de impuestos: %@", "Neto después de impuestos: %@"),
    "Rates": ("Tasas", "Tasas"),
    "Fiscal year to date: %@ – %@": (
        "Año fiscal hasta la fecha: %@ – %@",
        "Año fiscal hasta la fecha: %@ – %@",
    ),
    "Fiscal year to date": ("Año fiscal hasta la fecha", "Año fiscal hasta la fecha"),
    "Rules as of %@": ("Normas vigentes desde %@", "Normas vigentes desde %@"),
    "Tax year %@": ("Año fiscal %@", "Año fiscal %@"),
    "Current quarter": ("Trimestre actual", "Trimestre actual"),
    "All recorded transactions": (
        "Todas las transacciones registradas",
        "Todas las transacciones registradas",
    ),
    "Hypothetical annual": ("Anual hipotético", "Anual hipotético"),
    # Phase L — US invoice regional sales tax
    "%@ sales tax (est.)": (
        "Impuesto sobre ventas de %@ (est.)",
        "Impuesto sobre ventas de %@ (est.)",
    ),
    "%@ tax (est.)": ("Impuesto de %@ (est.)", "Impuesto de %@ (est.)"),
    # Phase I — receipt / expense categories
    "Software": ("Software", "Software"),
    "Fuel": ("Combustible", "Combustible"),
    "Home Office": ("Oficina en casa", "Oficina en casa"),
    "Subcontractors": ("Subcontratistas", "Subcontratistas"),
    "Meals": ("Comidas", "Comidas"),
    "Phone & Internet": ("Teléfono e internet", "Teléfono e internet"),
    "Equipment": ("Equipamiento", "Equipamiento"),
    "Marketing": ("Marketing", "Marketing"),
    "Insurance": ("Seguros", "Seguros"),
    "Bank Fees": ("Comisiones bancarias", "Comisiones bancarias"),
    "Misc": ("Varios", "Varios"),
    # Phase I — deductibility hints
    "Catalog rule allows %lld%% deductibility for %@ in %@.": (
        "El catálogo permite deducir %lld%% de %@ en %@.",
        "El catálogo permite deducir %lld%% de %@ en %@.",
    ),
    "Fully deductible per your tax profile rules.": (
        "Totalmente deducible según las reglas de tu perfil fiscal.",
        "Totalmente deducible según las reglas de tu perfil fiscal.",
    ),
    "Tax profile applies %lld%% for %@.": (
        "El perfil fiscal aplica %lld%% para %@.",
        "El perfil fiscal aplica %lld%% para %@.",
    ),
    "Fully deductible per tax profile.": (
        "Totalmente deducible según el perfil fiscal.",
        "Totalmente deducible según el perfil fiscal.",
    ),
    # Calculator line labels from compute catalog (GB / US)
    "Class 2 National Insurance": (
        "Seguro Nacional clase 2",
        "Seguro Nacional clase 2",
    ),
    "Class 4 National Insurance": (
        "Seguro Nacional clase 4",
        "Seguro Nacional clase 4",
    ),
    "Class 4 National Insurance (additional)": (
        "Seguro Nacional clase 4 (adicional)",
        "Seguro Nacional clase 4 (adicional)",
    ),
    "Class 1 National Insurance": (
        "Seguro Nacional clase 1",
        "Seguro Nacional clase 1",
    ),
    "Class 1 National Insurance (additional)": (
        "Seguro Nacional clase 1 (adicional)",
        "Seguro Nacional clase 1 (adicional)",
    ),
    "Self-employment tax (SECA)": (
        "Impuesto de trabajo por cuenta propia (SECA)",
        "Impuesto de trabajo por cuenta propia (SECA)",
    ),
}


def main() -> None:
    payload = {k: {"es-419": v[0], "es-ES": v[1]} for k, v in T.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} keys to {OUT}")


if __name__ == "__main__":
    main()
