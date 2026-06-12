#!/usr/bin/env python3
"""Phase 14 — enum rawValues, feature strips, and missing catalog labels."""

from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "docs/localization/phase14-translations.json"

# es-419, es-ES (informal tú for LATAM)
T: dict[str, tuple[str, str]] = {
    # Project / invoice / receipt
    "On hold": ("En pausa", "En pausa"),
    "Cancelled": ("Cancelada", "Cancelada"),
    "Completed": ("Completado", "Completado"),
    "Strong": ("Fuerte", "Fuerte"),
    "Weak": ("Débil", "Débil"),
    "Risky": ("Arriesgado", "Arriesgado"),
    "Self-employed": ("Autónomo", "Autónomo"),
    "Employed": ("Empleado", "Empleado"),
    "One-off / gig": ("Trabajo puntual", "Trabajo puntual"),
    # Simple studio payment
    "Still waiting": ("Aún en espera", "Aún en espera"),
    "Partially paid": ("Pago parcial", "Pago parcial"),
    "Paid in full": ("Pagado completo", "Pagado completo"),
    # Search / studio sections
    "Projects": ("Proyectos", "Proyectos"),
    "Receipts": ("Recibos", "Recibos"),
    "Mileage": ("Kilometraje", "Kilometraje"),
    "Time": ("Tiempo", "Tiempo"),
    "Ledger": ("Libro mayor", "Libro mayor"),
    # Feature strips
    "Off": ("Desactivado", "Desactivado"),
    "Tag expenses": ("Etiquetar gastos", "Etiquetar gastos"),
    "Enable payment tagging in Settings": (
        "Activa el etiquetado de pagos en Ajustes",
        "Activa el etiquetado de pagos en Ajustes",
    ),
    "Settings → Payment Sources": (
        "Ajustes → Fuentes de pago",
        "Ajustes → Fuentes de pago",
    ),
    "Cash Drawer": ("Caja de efectivo", "Caja de efectivo"),
    "Enable in Studio → Cash & Barter": (
        "Actívalo en Studio → Efectivo y trueque",
        "Actívalo en Studio → Efectivo y trueque",
    ),
    "Enable Studio first": ("Activa Studio primero", "Activa Studio primero"),
    "Studio → Cash & Barter": ("Studio → Efectivo y trueque", "Studio → Efectivo y trueque"),
    "Studio → Turn on": ("Studio → Activar", "Studio → Activar"),
    "Barter & Trade": ("Trueque e intercambio", "Trueque e intercambio"),
    "No trades": ("Sin trueques", "Sin trueques"),
    "Log non-cash exchanges": ("Registra intercambios sin efectivo", "Registra intercambios sin efectivo"),
    "All workspaces": ("Todos los workspaces", "Todos los workspaces"),
    "Workspaces": ("Workspaces", "Workspaces"),
    "Separate gigs or departments": ("Separa trabajos o áreas", "Separa trabajos o áreas"),
    "Studio → Workspaces": ("Studio → Workspaces", "Studio → Workspaces"),
    "Creative Energy": ("Energía creativa", "Energía creativa"),
    "Track workload & rest": ("Registra carga y descanso", "Registra carga y descanso"),
    "Studio → Workload & Energy": ("Studio → Carga y energía", "Studio → Carga y energía"),
    "Scope Radar": ("Radar de alcance", "Radar de alcance"),
    "Clear": ("Todo claro", "Todo claro"),
    "Hours & revision guardrails": ("Horas y límites de revisiones", "Horas y límites de revisiones"),
    "Studio → Scope Radar": ("Studio → Radar de alcance", "Studio → Radar de alcance"),
    "Upgrade to Pro": ("Pasar a Pro", "Pasar a Pro"),
    "%.1f h work · %.1f h sleep": ("%.1f h trabajo · %.1f h sueño", "%.1f h trabajo · %.1f h sueño"),
    # Tax / misc UI
    "Custom profile": ("Perfil personalizado", "Perfil personalizado"),
    "Saved · %@ · %@ · %@": ("Guardado · %@ · %@ · %@", "Guardado · %@ · %@ · %@"),
    "Unknown Client": ("Cliente desconocido", "Cliente desconocido"),
    # Categories (TransactionCategory.displayName keys)
    "Restaurants": ("Restaurantes", "Restaurantes"),
    "Transport": ("Transporte", "Transporte"),
    "Subscriptions": ("Suscripciones", "Suscripciones"),
    "Housing": ("Vivienda", "Vivienda"),
    "Entertainment": ("Entretenimiento", "Entretenimiento"),
    "Shopping": ("Compras", "Compras"),
    "Health": ("Salud", "Salud"),
    "Utilities": ("Servicios", "Servicios"),
    "Travel": ("Viajes", "Viajes"),
    "Education": ("Educación", "Educación"),
    "Personal": ("Personal", "Personal"),
    "Income": ("Ingresos", "Ingresos"),
    "Other": ("Otros", "Otros"),
    "Weekly": ("Semanal", "Semanal"),
    "Monthly": ("Mensual", "Mensual"),
    "Quarterly": ("Trimestral", "Trimestral"),
    "Semi-Annual": ("Semestral", "Semestral"),
    "Yearly": ("Anual", "Anual"),
    "this workspace": ("este workspace", "este workspace"),
    "This looks like a subscription · %@ cycle": (
        "Parece una suscripción · ciclo %@",
        "Parece una suscripción · ciclo %@",
    ),
    "Part of a monthly cycle at this merchant": (
        "Parte de un ciclo mensual en este comercio",
        "Parte de un ciclo mensual en este comercio",
    ),
}


def main() -> None:
    payload = {k: {"es-419": a, "es-ES": b} for k, (a, b) in T.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} keys → {OUT}")


if __name__ == "__main__":
    main()
