#!/usr/bin/env python3
"""Phase 12 — invoice designer, agreements, tax, settings, expenses (new keys only)."""

from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "docs/localization/phase12-translations.json"

T: dict[str, tuple[str, str]] = {
    "Header: %@ · Background: %@ · Template: %@": (
        "Encabezado: %@ · Fondo: %@ · Plantilla: %@",
        "Encabezado: %@ · Fondo: %@ · Plantilla: %@",
    ),
    'Matching "%@"': ('Coincide con "%@"', 'Coincide con "%@"'),
    "Live Preview · %@": ("Vista previa · %@", "Vista previa · %@"),
    "%@ — %@%%": ("%@ — %@%%", "%@ — %@%%"),
    "Review %@ preset": ("Revisar preset %@", "Revisar preset %@"),
    "%@ · %@ (%@)": ("%@ · %@ (%@)", "%@ · %@ (%@)"),
    "%@ %@ · %@": ("%1$@ %2$@ · %3$@", "%1$@ %2$@ · %3$@"),
    "%lld designs": ("%lld diseños", "%lld diseños"),
    "Last: %@": ("Último: %@", "Último: %@"),
    "Waiting: %@": ("En espera: %@", "En espera: %@"),
    "Total: %@": ("Total: %@", "Total: %@"),
    "Preview: %@": ("Vista previa: %@", "Vista previa: %@"),
    "%lld%%": ("%lld%%", "%lld%%"),
    "%lldd": ("%lld d", "%lld d"),
    "Local notification %lld day before renewal.": (
        "Notificación local %lld día antes de la renovación.",
        "Notificación local %lld día antes de la renovación.",
    ),
    "Local notification %lld days before renewal.": (
        "Notificación local %lld días antes de la renovación.",
        "Notificación local %lld días antes de la renovación.",
    ),
    "Fill from job": ("Completar desde trabajo", "Completar desde trabajo"),
    "Fill from project": ("Completar desde proyecto", "Completar desde proyecto"),
    "this workspace": ("este workspace", "este workspace"),
    "Same trip home — adds a second log with From ↔ To swapped (%@ mi each way).": (
        "Mismo viaje de vuelta — agrega un segundo registro con Origen ↔ Destino invertidos (%@ mi por tramo).",
        "Mismo viaje de vuelta — añade un segundo registro con Origen ↔ Destino invertidos (%@ mi por trayecto).",
    ),
}

def main() -> None:
    payload = {k: {"es-419": a, "es-ES": b} for k, (a, b) in T.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} keys → {OUT}")


if __name__ == "__main__":
    main()
