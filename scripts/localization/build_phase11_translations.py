#!/usr/bin/env python3
"""Phase 11 — Simple Studio, expenses, projects, planner, search."""

from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "docs/localization/phase11-translations.json"

T: dict[str, tuple[str, str]] = {
    # Project overview
    "Fixed %@ — time is tracked for margin & scope, not to recalculate the price.": (
        "Fijo %@ — el tiempo se registra para margen y alcance, no para recalcular el precio.",
        "Fijo %@ — el tiempo se registra para margen y alcance, no para recalcular el precio.",
    ),
    "%@/hr × %@ billable hrs logged": (
        "%@/h × %@ h facturables registradas",
        "%@/h × %@ h facturables registradas",
    ),
    "%lld of %lld used": ("%lld de %lld usadas", "%lld de %lld usadas"),
    "%@ h": ("%@ h", "%@ h"),
    "Time entries below are your task log for this project.": (
        "Las entradas de tiempo abajo son tu registro de tareas para este proyecto.",
        "Las entradas de tiempo abajo son tu registro de tareas para este proyecto.",
    ),
    # Simple Studio money
    "Keep %@": ("Quedan %@", "Quedan %@"),
    "Agreed %@": ("Acordado %@", "Acordado %@"),
    "Spent %@": ("Gastado %@", "Gastado %@"),
    "Paid %@": ("Pagado %@", "Pagado %@"),
    "Waiting %@": ("En espera %@", "En espera %@"),
    "When paid: keep %@": ("Al cobrar: quedan %@", "Al cobrar: quedan %@"),
    "Tap the chart or a row below to filter": (
        "Toca el gráfico o una fila abajo para filtrar",
        "Toca el gráfico o una fila abajo para filtrar",
    ),
    "%@ · %lldd": ("%@ · %lld d", "%@ · %lld d"),
    "Advance left: %@": ("Anticipo restante: %@", "Anticipo restante: %@"),
    # Log time
    "Already logged: %@": ("Ya registrado: %@", "Ya registrado: %@"),
    "Planned time: %@": ("Tiempo planificado: %@", "Tiempo planificado: %@"),
    "Almost there — about %lld min left on your plan.": (
        "Casi — quedan unos %lld min en tu plan.",
        "Casi — quedan unos %lld min en tu plan.",
    ),
    # Planner
    "Health · %@": ("Salud · %@", "Salud · %@",),
    "~%@h to finish at current pace": (
        "~%@ h para terminar al ritmo actual",
        "~%@ h para terminar al ritmo actual",
    ),
    "After %@": ("Después de %@", "Después de %@"),
    "After: %@": ("Después de: %@", "Después de: %@"),
    # Insights / search
    "%lld paid": ("%lld pagados", "%lld pagados"),
    "%lld open": ("%lld abiertos", "%lld abiertos"),
    "%lld result": ("%lld resultado", "%lld resultado"),
    "%lld results": ("%lld resultados", "%lld resultados"),
    # Client / SE
    "LTV: %@": ("LTV: %@", "LTV: %@"),
    "%lld/100": ("%lld/100", "%lld/100"),
    "%lld days": ("%lld días", "%lld días"),
    "%lld time entries logged": ("%lld entradas de tiempo registradas", "%lld entradas de tiempo registradas"),
    "Runway %@": ("Runway %@", "Runway %@"),
    # Invoices
    "%lld invoice(s)": ("%lld factura(s)", "%lld factura(s)"),
    "Issued: %@": ("Emitida: %@", "Emitida: %@"),
    "Due: %@": ("Vence: %@", "Vence: %@"),
    "Template: %@": ("Plantilla: %@", "Plantilla: %@"),
    "Late Risk Detected. Awaiting payment speed estimated at %lld days.": (
        "Riesgo de retraso. Se estima cobro en %lld días.",
        "Riesgo de retraso. Se estima cobro en %lld días.",
    ),
    # Expense / settings
    "Use %@?": ("¿Usar %@?", "¿Usar %@?"),
    "Cash (%@)": ("Efectivo (%@)", "Efectivo (%@)"),
    "ESTIMATED VALUE (%@)": ("VALOR ESTIMADO (%@)", "VALOR ESTIMADO (%@)"),
    "%@ (%@)": ("%1$@ (%2$@)", "%1$@ (%2$@)"),
    "%@ · typical %@": ("%@ · habitual %@", "%@ · habitual %@"),
    "Viewing: %@": ("Viendo: %@", "Viendo: %@"),
    "%lld/10": ("%lld/10", "%lld/10"),
    "Current %@ Cash in Wallet": ("Efectivo %@ actual en la billetera", "Efectivo %@ actual en la cartera"),
    "%lld Categories · Target: %@": (
        "%lld categorías · Meta: %@",
        "%lld categorías · Meta: %@",
    ),
    "See all %lld designs": ("Ver las %lld diseños", "Ver los %lld diseños"),
    "Scale: %.1fx": ("Escala: %.1fx", "Escala: %.1fx"),
    "Card: %@ — any photo size works.": (
        "Tarjeta: %@ — cualquier tamaño de foto sirve.",
        "Tarjeta: %@ — cualquier tamaño de foto sirve.",
    ),
    "%@ · %@": ("%1$@ · %2$@", "%1$@ · %2$@"),
    "%@ %@": ("%1$@ %2$@", "%1$@ %2$@"),
    "Signed · %@": ("Firmado · %@", "Firmado · %@"),
    "Fill from %@": ("Completar desde %@", "Completar desde %@"),
    "Qty %.1f · %@": ("Cant. %.1f · %@", "Cant. %.1f · %@"),
    "Est. allowance: %@": ("Tarifa est.: %@", "Tarifa est.: %@"),
    "Photos: %@": ("Fotos: %@", "Fotos: %@"),
    "+%@": ("+%@", "+%@"),
    "+%.1f%%": ("+%.1f%%", "+%.1f%%"),
    "Pick another workspace above, or add an expense tagged to %@.": (
        "Elige otro workspace arriba o agrega un gasto etiquetado a %@.",
        "Elige otro workspace arriba o añade un gasto etiquetado a %@.",
    ),
    "Local · Private · On your phone": (
        "Local · Privado · En tu teléfono",
        "Local · Privado · En tu teléfono",
    ),
    "Today kept": ("Quedó hoy", "Quedó hoy"),
}


def main() -> None:
    payload = {k: {"es-419": a, "es-ES": e} for k, (a, e) in T.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} keys to {OUT}")


if __name__ == "__main__":
    main()
