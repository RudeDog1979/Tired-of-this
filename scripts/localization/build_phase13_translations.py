#!/usr/bin/env python3
"""Phase 13 — remaining interpolated UI (cards, tax, expenses, business card)."""

from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "docs/localization/phase13-translations.json"

T: dict[str, tuple[str, str]] = {
    "INCOME & DEDUCTIONS (%@)": (
        "INGRESOS Y DEDUCCIONES (%@)",
        "INGRESOS Y DEDUCCIONES (%@)",
    ),
    "%@:": ("%@:", "%@:"),
    "Estimated runway based on your %@ monthly burn rate.": (
        "Runway estimado según tu ritmo de gasto mensual de %@.",
        "Runway estimado según tu ritmo de gasto mensual de %@.",
    ),
    "Save %@": ("Ahorra %@", "Ahorra %@"),
    "%lld countries": ("%lld países", "%lld países"),
    "Updated %@": ("Actualizado %@", "Actualizado %@"),
    "+%lld more · tap for details": (
        "+%lld más · toca para detalles",
        "+%lld más · toca para detalles",
    ),
    "+%lld more": ("+%lld más", "+%lld más"),
    "Shown as %@ · %@": ("Se muestra como %@ · %@", "Se muestra como %@ · %@"),
    "Your recurring subscriptions account for roughly %.0f%% of your overall spending. Taking advantage of multi-month prepayments could unlock up to 15%% in annual savings across active plans.": (
        "Tus suscripciones recurrentes representan aprox. %.0f%% de tu gasto total. Pagar varios meses por adelantado puede ahorrarte hasta un 15%% anual en planes activos.",
        "Tus suscripciones recurrentes representan aprox. %.0f%% de tu gasto total. Pagar varios meses por adelantado puede ahorrarte hasta un 15%% anual en planes activos.",
    ),
    "Total spent (%@)": ("Total gastado (%@)", "Total gastado (%@)"),
    "%lld items": ("%lld ítems", "%lld elementos"),
    "%lld transactions": ("%lld transacciones", "%lld transacciones"),
    "Target: %@": ("Meta: %@", "Meta: %@"),
    "Tax Health · %@ risk": ("Salud fiscal · riesgo %@", "Salud fiscal · riesgo %@"),
    "%@ Portfolio": ("Portafolio %@", "Cartera %@"),
    "Use %@ currency": ("Usar moneda %@", "Usar moneda %@"),
    "Keep %@": ("Mantener %@", "Mantener %@"),
    "%lldh": ("%lld h", "%lld h"),
    "%lld m": ("%lld m", "%lld m"),
    "%lldm": ("%lld m", "%lld m"),
    "Recommended: %@": ("Recomendado: %@", "Recomendado: %@"),
    "Delete %lld": ("Eliminar %lld", "Eliminar %lld"),
    "%@ %@": ("%1$@ %2$@", "%1$@ %2$@"),
    "7 Days": ("7 días", "7 días"),
    "30 Days": ("30 días", "30 días"),
    "90 Days": ("90 días", "90 días"),
    "Log %@ and stop": ("Registrar %@ y detener", "Registrar %@ y detener"),
    "%lld/100": ("%lld/100", "%lld/100"),
    "Not asked yet": ("Sin pedir aún", "Sin pedir aún"),
    "Limited access": ("Acceso limitado", "Acceso limitado"),
    "Full access": ("Acceso completo", "Acceso completo"),
    "Denied": ("Denegado", "Denegado"),
    "Restricted": ("Restringido", "Restringido"),
    "local": ("local", "local"),
    "Risk score: %.0f%%": ("Riesgo: %.0f%%", "Riesgo: %.0f%%"),
    "↑ %.1f%% Increase": ("↑ %.1f%% aumento", "↑ %.1f%% aumento"),
    "↓ %.1f%% Decrease": ("↓ %.1f%% baja", "↓ %.1f%% bajada"),
    "%.1f hrs": ("%.1f h", "%.1f h"),
    "%.0f%%": ("%.0f%%", "%.0f%%"),
    "%+.1f": ("%+.1f", "%+.1f"),
    "%.1fh": ("%.1f h", "%.1f h"),
    "%.1f h / %.1f h": ("%.1f h / %.1f h", "%.1f h / %.1f h"),
    "%lld°": ("%lld°", "%lld°"),
    "+%lld°": ("+%lld°", "+%lld°"),
    "%lld%%": ("%lld%%", "%lld%%"),
}


def main() -> None:
    payload = {k: {"es-419": a, "es-ES": b} for k, (a, b) in T.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} keys → {OUT}")


if __name__ == "__main__":
    main()
