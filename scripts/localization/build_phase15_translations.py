#!/usr/bin/env python3
"""Phase 15 — menus, timeline, chips, alerts, Studio hub, search filters."""

from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "docs/localization/phase15-translations.json"

# es-419, es-ES (informal tú)
T: dict[str, tuple[str, str]] = {
    # Expense timeline
    "Today": ("Hoy", "Hoy"),
    "Yesterday": ("Ayer", "Ayer"),
    "This week": ("Esta semana", "Esta semana"),
    "Last week": ("Semana pasada", "Semana pasada"),
    "Last month": ("Mes pasado", "Mes pasado"),
    "Earlier": ("Anteriores", "Anteriores"),
    # Invoice designer tabs
    "Branding": ("Marca", "Marca"),
    "Tax & Rates": ("Impuestos y tarifas", "Impuestos y tarifas"),
    # Hustle / workspaces
    "All Workspaces": ("Todos los espacios", "Todos los espacios"),
    "· includes unassigned": ("· incluye sin asignar", "· incluye sin asignar"),
    # Studio hub tools (confirm / fix)
    "Studio Insights": ("Insights de Studio", "Insights de Studio"),
    "Tax Studio": ("Estudio fiscal", "Estudio fiscal"),
    "Cashflow": ("Flujo de caja", "Flujo de caja"),
    "Deductions": ("Deducciones", "Deducciones"),
    "Mileage Log": ("Registro de kilometraje", "Registro de kilometraje"),
    "Business Card Studio": ("Estudio de tarjetas", "Estudio de tarjetas"),
    "Top Clients": ("Mejores clientes", "Mejores clientes"),
    "Deduction Opportunities": ("Oportunidades de deducción", "Oportunidades de deducción"),
    # Hero / empty
    "Set Up Your Business": ("Configura tu negocio", "Configura tu negocio"),
    "Studio workspace": ("Espacio de Studio", "Espacio de Studio"),
    # Business types
    "Sole Trader": ("Trabajador independiente", "Trabajador autónomo"),
    "LLC": ("LLC", "LLC"),
    "Self Employed": ("Autónomo", "Autónomo"),
    "Contractor": ("Contratista", "Contratista"),
    "Freelancer": ("Freelancer", "Freelancer"),
    # Pro search filters
    "Drafts": ("Borradores", "Borradores"),
    "Waiting": ("En espera", "En espera"),
    "Deductible": ("Deducible", "Deducible"),
    "Time logged": ("Tiempo registrado", "Tiempo registrado"),
    # Studio alerts
    "Tax profile incomplete": ("Perfil fiscal incompleto", "Perfil fiscal incompleto"),
    "Choose a country preset or enter your tax rules in Tax Profile.": (
        "Elige un preset de país o ingresa tus reglas fiscales en Perfil fiscal.",
        "Elige un preset de país o introduce tus reglas fiscales en Perfil fiscal.",
    ),
    "Cashflow survival mode": ("Modo supervivencia de flujo", "Modo supervivencia de flujo"),
    "High stress impact. Review profitability and terms.": (
        "Impacto de estrés alto. Revisa rentabilidad y condiciones.",
        "Impacto de estrés alto. Revisa rentabilidad y condiciones.",
    ),
    "Client red flag: %@": ("Alerta de cliente: %@", "Alerta de cliente: %@"),
    "%lld overdue invoice(s). Health score %lld%%.": (
        "%lld factura(s) vencida(s). Salud %lld%%.",
        "%lld factura(s) vencida(s). Salud %lld%%.",
    ),
    "%lld overdue invoice(s)": ("%lld factura(s) vencida(s)", "%lld factura(s) vencida(s)"),
    "Follow up on outstanding payments to improve cashflow.": (
        "Da seguimiento a pagos pendientes para mejorar el flujo.",
        "Da seguimiento a pagos pendientes para mejorar el flujo.",
    ),
    "Project overrun risk": ("Riesgo de sobrecosto en proyecto", "Riesgo de sobrecosto en proyecto"),
    "%lld project(s) may exceed time or budget.": (
        "%lld proyecto(s) pueden exceder tiempo o presupuesto.",
        "%lld proyecto(s) pueden exceder tiempo o presupuesto.",
    ),
    "Tax deadline approaching": ("Se acerca el vencimiento fiscal", "Se acerca el vencimiento fiscal"),
    "%lld days until your next scheduled tax payment.": (
        "%lld días hasta tu próximo pago fiscal programado.",
        "%lld días hasta tu próximo pago fiscal programado.",
    ),
    "Configure tax rules": ("Configura reglas fiscales", "Configura reglas fiscales"),
    # Toolbar / profile (fix prior bad entry)
    "Business Profile": ("Perfil del negocio", "Perfil del negocio"),
    "Tax Profile": ("Perfil fiscal", "Perfil fiscal"),
    # Expense header insights
    "Spending is up this month": ("El gasto subió este mes", "El gasto subió este mes"),
    "Great job keeping costs down": ("Buen trabajo bajando costos", "Buen trabajo bajando costos"),
    "%lld transactions": ("%lld transacciones", "%lld transacciones"),
    # Tax studio links
    "Income Tax Calculator": ("Calculadora de impuesto a la renta", "Calculadora de IRPF"),
    "Quarterly Tax": ("Impuesto trimestral", "Impuesto trimestral"),
    "12-MONTH PROJECTION": ("PROYECCIÓN 12 MESES", "PROYECCIÓN 12 MESES"),
}

def main() -> None:
    payload = {k: {"es-419": v[0], "es-ES": v[1]} for k, v in T.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} keys to {OUT}")

if __name__ == "__main__":
    main()
