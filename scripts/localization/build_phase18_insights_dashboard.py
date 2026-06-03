#!/usr/bin/env python3
"""Phase 18 — Insights engines, Money Map, dashboard brain (es-419 / es-ES)."""

from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "docs/localization/phase18-insights-dashboard.json"

T: dict[str, tuple[str, str]] = {
    # Insight values & actions
    "Splurge Risk": ("Riesgo de exceso", "Riesgo de exceso"),
    "Low Spend Day": ("Día de bajo gasto", "Día de bajo gasto"),
    "Spike Detected": ("Pico detectado", "Pico detectado"),
    "Weather Bias": ("Sesgo climático", "Sesgo climático"),
    "Weekend Bias": ("Sesgo de fin de semana", "Sesgo de fin de semana"),
    "Nighttime Bias": ("Sesgo nocturno", "Sesgo nocturno"),
    "Overspend Forecast": ("Pronóstico de exceso", "Pronóstico de exceso"),
    "Stable Budget": ("Presupuesto estable", "Presupuesto estable"),
    "Overspend Spike": ("Pico de exceso", "Pico de exceso"),
    "Savings Gained": ("Ahorro logrado", "Ahorro logrado"),
    "Price Hike": ("Subida de precio", "Subida de precio"),
    "Refund Saved": ("Reembolso guardado", "Reembolso guardado"),
    "Ahead Pace": ("Ritmo adelantado", "Ritmo adelantado"),
    "Behind Pace": ("Ritmo atrasado", "Ritmo atrasado"),
    "Action Required": ("Acción requerida", "Acción requerida"),
    "Cost Increase": ("Aumento de costo", "Aumento de costo"),
    "Unused App": ("App sin uso", "App sin uso"),
    "Overlapping Service": ("Servicio duplicado", "Servicio duplicado"),
    "Goal Opportunity": ("Oportunidad de meta", "Oportunidad de meta"),
    "%lld%% on credit": ("%lld%% en crédito", "%lld%% en crédito"),
    "%lld%% untagged": ("%lld%% sin etiquetar", "%lld%% sin etiquetar"),
    "%lld%% cash": ("%lld%% en efectivo", "%lld%% en efectivo"),
    "%lld trade": ("%lld trueque", "%lld trueque"),
    "%lld trades": ("%lld trueques", "%lld trueques"),
    "%lld provider": ("%lld proveedor", "%lld proveedor"),
    "%lld providers": ("%lld proveedores", "%lld proveedores"),
    "Review credit-tagged expenses": ("Revisa gastos con crédito", "Revisa gastos con crédito"),
    "Set a weekly pay-down reminder": ("Configura recordatorio semanal de pago", "Configura recordatorio semanal de pago"),
    "Check BNPL due dates": ("Revisa fechas de BNPL", "Revisa fechas de BNPL"),
    "Consolidate small BNPL plans": ("Consolida planes BNPL pequeños", "Consolida planes BNPL pequeños"),
    "Assign a workspace when logging": ("Asigna un espacio al registrar", "Asigna un espacio al registrar"),
    "Open Workspaces in Studio settings": ("Abre Espacios en Ajustes de Studio", "Abre Espacios en Ajustes de Studio"),
    "Log cash expenses from Add Expense": ("Registra gastos en efectivo desde Agregar gasto", "Registra gastos en efectivo desde Agregar gasto"),
    "Update drawer balances in Studio": ("Actualiza saldos de caja en Studio", "Actualiza saldos de caja en Studio"),
    "Tag expenses": ("Etiqueta gastos", "Etiqueta gastos"),
    # Money Map territories
    "Categories": ("Categorías", "Categorías"),
    "Cash flow": ("Flujo de caja", "Flujo de caja"),
    "Merchants": ("Comercios", "Comercios"),
    "Cash drawer": ("Caja en efectivo", "Caja en efectivo"),
    "Barter": ("Trueque", "Trueque"),
    "Energy": ("Energía", "Energía"),
    "Scope radar": ("Radar de alcance", "Radar de alcance"),
    "Top insight": ("Insight principal", "Insight principal"),
    "Signals": ("Señales", "Señales"),
    "Studio": ("Studio", "Studio"),
    "Invoices": ("Facturas", "Facturas"),
    "Mileage": ("Kilometraje", "Kilometraje"),
    # Dashboard / brain
    "This Month": ("Este mes", "Este mes"),
    "Transactions": ("Transacciones", "Transacciones"),
    "Simple Monthly Budget": ("Presupuesto mensual simple", "Presupuesto mensual simple"),
    "Custom %@ Budget": ("Presupuesto %@ personalizado", "Presupuesto %@ personalizado"),
    "weekly": ("semanal", "semanal"),
    "monthly": ("mensual", "mensual"),
    "custom": ("personalizado", "personalizado"),
}


def main() -> None:
    payload = {k: {"es-419": v[0], "es-ES": v[1]} for k, v in T.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} keys to {OUT}")


if __name__ == "__main__":
    main()
