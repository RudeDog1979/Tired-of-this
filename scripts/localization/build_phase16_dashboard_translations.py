#!/usr/bin/env python3
"""Phase 16 — Dashboard UI strings (hero, cards, billing, discovery)."""

from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "docs/localization/phase16-dashboard-translations.json"

T: dict[str, tuple[str, str]] = {
    "Top: %@": ("Principal: %@", "Principal: %@"),
    "All categories": ("Todas las categorías", "Todas las categorías"),
    "All merchants": ("Todos los comercios", "Todos los comercios"),
    "%lld This Month": ("%lld este mes", "%lld este mes"),
    "On track": ("En buen camino", "En buen camino"),
    "Est. tax": ("Imp. est.", "Imp. est."),
    "Quarter due": ("Trim. a pagar", "Trim. a pagar"),
    "Rate": ("Tasa", "Tasa"),
    "Expenses": ("Gastos", "Gastos"),
    "Net": ("Neto", "Neto"),
    "Self-employed?": ("¿Trabajas por tu cuenta?", "¿Trabajas por tu cuenta?"),
    "Turn on Studio for invoices, mileage, and tax estimates — optional, in Settings.": (
        "Activa Studio para facturas, kilometraje e impuestos estimados — opcional, en Ajustes.",
        "Activa Studio para facturas, kilometraje e impuestos estimados — opcional, en Ajustes.",
    ),
    "See Studio in Settings": ("Ver Studio en Ajustes", "Ver Studio en Ajustes"),
    "Dismiss": ("Cerrar", "Cerrar"),
    "Semi-Annual": ("Semestral", "Semestral"),
    "Irregular Pattern": ("Patrón irregular", "Patrón irregular"),
    "28-day": ("Cada 28 días", "Cada 28 días"),
    "30-day": ("Cada 30 días", "Cada 30 días"),
    "31-day": ("Cada 31 días", "Cada 31 días"),
}

def main() -> None:
    payload = {k: {"es-419": v[0], "es-ES": v[1]} for k, v in T.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} keys to {OUT}")

if __name__ == "__main__":
    main()
