#!/usr/bin/env python3
"""Build docs/localization/phase5b-translations.json for insight engine prose."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/localization/phase5b-translations.json"

# es-419 (tú) / es-ES — format specifiers preserved
ENTRIES: dict[str, tuple[str, str]] = {
    "Your %@ spending reached %@ this month, which is %@%% higher than your baseline average of %@.": (
        "Tu gasto en %@ llegó a %@ este mes, un %@%% por encima de tu promedio base de %@.",
        "Tu gasto en %@ llegó a %@ este mes, un %@%% por encima de tu promedio base de %@.",
    ),
    "Your %@ spending fell to %@ this month compared to %@ historically, leaving you with an extra surplus of %@.": (
        "Tu gasto en %@ bajó a %@ este mes frente a %@ histórico, con un excedente de %@.",
        "Tu gasto en %@ bajó a %@ este mes frente a %@ histórico, con un excedente de %@.",
    ),
    "Category: %@. Current: %@. Baseline: %@.": (
        "Categoría: %@. Actual: %@. Base: %@.",
        "Categoría: %@. Actual: %@. Base: %@.",
    ),
    "Category: %@. Saved: %@.": (
        "Categoría: %@. Ahorrado: %@.",
        "Categoría: %@. Ahorrado: %@.",
    ),
    "Review recent transaction line items inside %@.": (
        "Revisa los movimientos recientes en %@.",
        "Revisa los movimientos recientes en %@.",
    ),
    "Redirect this surplus of %@ immediately into savings goals.": (
        "Redirige ya este excedente de %@ a tus metas de ahorro.",
        "Redirige ya este excedente de %@ a tus objetivos de ahorro.",
    ),
    "Your latest charge of %@ at %@ is higher than the previous transaction of %@. This represents a price rise of %@.": (
        "Tu último cargo de %@ en %@ supera el anterior de %@. Subida de %@.",
        "Tu último cargo de %@ en %@ supera el anterior de %@. Subida de %@.",
    ),
    "The BuxMuse Brain successfully reconciled a cleared credit/refund of %@ from %@ back into your main wallet.": (
        "BuxMuse concilió un reembolso/abono de %@ de %@ en tu billetera principal.",
        "BuxMuse concilió un reembolso/abono de %@ de %@ en tu cartera principal.",
    ),
    "Merchant: %@. Current: %@. Previous: %@.": (
        "Comercio: %@. Actual: %@. Anterior: %@.",
        "Comercio: %@. Actual: %@. Anterior: %@.",
    ),
    "Merchant: %@. Refund: %@.": (
        "Comercio: %@. Reembolso: %@.",
        "Comercio: %@. Reembolso: %@.",
    ),
    "With a strong health score of %lld%% and consistent contributions, you are trending ahead of your original pacing schedules for '%@'.": (
        "Con salud %lld%% y aportes constantes, vas adelantado al ritmo original de '%@'.",
        "Con salud %lld%% y aportes constantes, vas adelantado al ritmo original de '%@'.",
    ),
    "A low health score of %lld%% indicates high timeline delay risk. Contributions are falling behind standard forecast timelines.": (
        "Salud baja (%lld%%): alto riesgo de retraso. Los aportes van detrás del pronóstico.",
        "Salud baja (%lld%%): alto riesgo de retraso. Los aportes van detrás del pronóstico.",
    ),
    "Goal: %@. Health: %lld%%.": (
        "Meta: %@. Salud: %lld%%.",
        "Objetivo: %@. Salud: %lld%%.",
    ),
    "Re-route %@ from active media subscription overspends to boost momentum.": (
        "Redirige %@ de suscripciones de media activas para impulsar el ritmo.",
        "Redirige %@ de suscripciones de media activas para impulsar el ritmo.",
    ),
    "The BuxMuse Pattern Engine detected two identical billing sweeps for %@ within the same billing cycle. This likely represents a merchant billing error.": (
        "El motor de patrones detectó dos cargos idénticos de %@ en el mismo ciclo. Probable error del comercio.",
        "El motor de patrones detectó dos cargos idénticos de %@ en el mismo ciclo. Probable error del comercio.",
    ),
    "The Brain detected a recent price increase for your %@ subscription. You are paying more than the baseline average from previous cycles.": (
        "Detectamos subida de precio en %@. Pagas más que el promedio de ciclos anteriores.",
        "Detectamos subida de precio en %@. Pagas más que el promedio de ciclos anteriores.",
    ),
    "Your %@ subscription represents a 'Zombie' charge. Usage analytics indicate zero active engagement or features consumed during the last 30 days.": (
        "Tu suscripción %@ es un cargo «zombie»: sin uso en los últimos 30 días.",
        "Tu suscripción %@ es un cargo «zombie»: sin uso en los últimos 30 días.",
    ),
    "You are maintaining active subscriptions for both %@. Trimming down to a single active streaming platform could optimize your media budget.": (
        "Tienes suscripciones activas a %@. Quedarte con una plataforma optimiza tu presupuesto de media.",
        "Tienes suscripciones activas a %@. Quedarte con una plataforma optimiza tu presupuesto de media.",
    ),
    "Canceling your %@ subscription (%@/mo) and redirecting that cash flow to %@ allows you to achieve the goal %@ months sooner.": (
        "Cancelar %@ (%@/mes) y redirigir ese flujo a %@ adelanta la meta %@ meses.",
        "Cancelar %@ (%@/mes) y redirigir ese flujo a %@ adelanta el objetivo %@ meses.",
    ),
    "Merchant: %@. Risk: Double Charge.": (
        "Comercio: %@. Riesgo: cargo duplicado.",
        "Comercio: %@. Riesgo: cargo duplicado.",
    ),
    "Merchant: %@. Price Hike detected.": (
        "Comercio: %@. Subida de precio detectada.",
        "Comercio: %@. Subida de precio detectada.",
    ),
    "Zombie flag on %@.": (
        "Marca zombie en %@.",
        "Marca zombie en %@.",
    ),
    "Overlapping streaming video bundle count: %lld.": (
        "Suscripciones de video superpuestas: %lld.",
        "Suscripciones de video superpuestas: %lld.",
    ),
    "Sub: %@. Cost: %@. Goal: %@. Pacing: -%@ months.": (
        "Sub: %@. Costo: %@. Meta: %@. Ritmo: -%@ meses.",
        "Sub: %@. Costo: %@. Objetivo: %@. Ritmo: -%@ meses.",
    ),
    "Contact %@ support to request a double-charge refund.": (
        "Contacta soporte de %@ para pedir reembolso por cargo duplicado.",
        "Contacta soporte de %@ para pedir reembolso por cargo duplicado.",
    ),
    "Review your usage to check if %@ is still value-aligned.": (
        "Revisa tu uso para ver si %@ sigue valiendo la pena.",
        "Revisa tu uso para ver si %@ sigue valiendo la pena.",
    ),
    "Cancel %@ immediately to recover the cost.": (
        "Cancela %@ ya para recuperar el costo.",
        "Cancela %@ ya para recuperar el costo.",
    ),
    "Cancel %@ inside BuxMuse.": (
        "Cancela %@ dentro de BuxMuse.",
        "Cancela %@ dentro de BuxMuse.",
    ),
    "Set up an automated monthly %@ transfer to '%@'.": (
        "Configura una transferencia mensual automática de %@ a '%@'.",
        "Configura una transferencia mensual automática de %@ a '%@'.",
    ),
    "Your spending rose by %@%% immediately following your last payday. This matches a standard payday splurge bias.": (
        "Tu gasto subió %@%% justo después del último día de pago. Patrón típico de «gasto de quincena».",
        "Tu gasto subió %@%% justo después del último día de pago. Patrón típico de «gasto de nómina».",
    ),
    "Sundays are your quietest financial days, averaging just %@ compared to %@ on other days of the week. This is an optimal rest day for your wallet.": (
        "Los domingos son tus días más tranquilos: %@ de promedio frente a %@ el resto de la semana. Ideal para descansar el bolsillo.",
        "Los domingos son tus días más tranquilos: %@ de promedio frente a %@ el resto de la semana. Ideal para descansar el bolsillo.",
    ),
    "You spent %@ this week, which is %@%% higher than your weekly baseline average of %@.": (
        "Gastaste %@ esta semana, un %@%% sobre tu promedio semanal de %@.",
        "Gastaste %@ esta semana, un %@%% sobre tu promedio semanal de %@.",
    ),
    "When local logs indicate rainy weather notes, your discretionary dining and transport spending drops by over 40% as you stay indoors, showing a strong outdoor spending bias.": (
        "Con notas de lluvia en tus registros, bajan restaurantes y transporte (+40%) porque te quedas adentro: sesgo a gastar afuera.",
        "Con notas de lluvia en tus registros, bajan restaurantes y transporte (+40%) porque te quedas dentro: sesgo a gastar fuera.",
    ),
    "Last Payday: %@. Spend: %@. Baseline: %@.": (
        "Último pago: %@. Gasto: %@. Base: %@.",
        "Último pago: %@. Gasto: %@. Base: %@.",
    ),
    "Sunday Average: %@. Daily Average: %@.": (
        "Promedio domingo: %@. Promedio diario: %@.",
        "Promedio domingo: %@. Promedio diario: %@.",
    ),
    "Current Week Spend: %@. Monthly Average Week: %@.": (
        "Gasto semana actual: %@. Promedio semanal mensual: %@.",
        "Gasto semana actual: %@. Promedio semanal mensual: %@.",
    ),
    "Rainy-note transactions count: %lld.": (
        "Transacciones con nota de lluvia: %lld.",
        "Transacciones con nota de lluvia: %lld.",
    ),
    "Based on your current daily run-rate of %@, BuxMuse predicts you will spend %@ this month. This is %@%% higher than your standard average (%@), threatening a potential %@ overspend.": (
        "Con ritmo diario %@, BuxMuse proyecta %@ este mes: %@%% sobre tu promedio (%@), con posible exceso de %@.",
        "Con ritmo diario %@, BuxMuse proyecta %@ este mes: %@%% sobre tu promedio (%@), con posible exceso de %@.",
    ),
    "BuxMuse predicts a stable close to the month, with forecasted spending at %@, well within your safe historical boundaries of %@.": (
        "BuxMuse prevé un cierre estable del mes, con gasto proyectado %@, dentro de tu rango histórico seguro de %@.",
        "BuxMuse prevé un cierre estable del mes, con gasto proyectado %@, dentro de tu rango histórico seguro de %@.",
    ),
    "Run-rate: %@/day. Predicted: %@. Historical: %@.": (
        "Ritmo: %@/día. Proyectado: %@. Histórico: %@.",
        "Ritmo: %@/día. Proyectado: %@. Histórico: %@.",
    ),
    "Predicted: %@. Historical Avg: %@.": (
        "Proyectado: %@. Promedio histórico: %@.",
        "Proyectado: %@. Promedio histórico: %@.",
    ),
    "Transfer 10% of your remaining free budget to savings goals early.": (
        "Transfiere el 10% de tu presupuesto libre restante a metas de ahorro antes de tiempo.",
        "Transfiere el 10% de tu presupuesto libre restante a objetivos de ahorro antes de tiempo.",
    ),
    "Your weekend spending averages %@ per day, which is %@%% higher than your weekday average of %@.": (
        "Tu gasto de fin de semana promedia %@/día, un %@%% sobre el día entre semana de %@.",
        "Tu gasto de fin de semana promedia %@/día, un %@%% sobre el día entre semana de %@.",
    ),
    "You spent %@ across %lld late-night rides this month. Fare spikes and premium options contribute to this nocturnal splurge.": (
        "Gastaste %@ en %lld viajes nocturnos este mes. Tarifas dinámicas y opciones premium impulsan el gasto.",
        "Gastaste %@ en %lld viajes nocturnos este mes. Tarifas dinámicas y opciones premium impulsan el gasto.",
    ),
    "Weekend Average: %@. Weekday Average: %@.": (
        "Promedio fin de semana: %@. Entre semana: %@.",
        "Promedio fin de semana: %@. Entre semana: %@.",
    ),
    "Nighttime Transport Spend: %@. Count: %lld.": (
        "Transporte nocturno: %@. Cantidad: %lld.",
        "Transporte nocturno: %@. Cantidad: %lld.",
    ),
    "Establish a concrete 'Weekend Budget cap' of %@.": (
        "Fija un tope concreto de fin de semana de %@.",
        "Fija un tope concreto de fin de semana de %@.",
    ),
    "You have logged %lld barter or trade exchanges with an estimated combined value of %@. These are tracked separately from cash expenses for your records.": (
        "Registraste %lld intercambios de trueque con valor estimado %@. Se llevan aparte del efectivo.",
        "Registraste %lld intercambios de trueque con valor estimado %@. Se llevan aparte del efectivo.",
    ),
    "Project \"%@\" has used %@ of %@ budgeted hours. Watch for scope creep before taking extra revisions.": (
        "El proyecto \"%@\" usó %@ de %@ horas presupuestadas. Cuida el scope creep antes de más revisiones.",
        "El proyecto \"%@\" usó %@ de %@ horas presupuestadas. Cuida el scope creep antes de más revisiones.",
    ),
    "StudioProject budgetedHours vs timeEntries.": (
        "StudioProject: budgetedHours vs timeEntries.",
        "StudioProject: budgetedHours vs timeEntries.",
    ),
    "Barter transactions where isBarterExchange is true.": (
        "Transacciones de trueque con isBarterExchange en true.",
        "Transacciones de trueque con isBarterExchange en true.",
    ),
    "%lld territories · charts · Pro lanes · insights": (
        "%lld territorios · gráficos · carriles Pro · insights",
        "%lld territorios · gráficos · carriles Pro · insights",
    ),
    "%lld territories · tap to open full map": (
        "%lld territorios · toca para abrir el mapa completo",
        "%lld territorios · toca para abrir el mapa completo",
    ),
    "Spent this month across %lld live territories": (
        "Gastado este mes en %lld territorios activos",
        "Gastado este mes en %lld territorios activos",
    ),
    "Studio · %@": (
        "Studio · %@",
        "Studio · %@",
    ),
    "Workload %@h vs project time %@h · Scope alerts %lld": (
        "Carga %@ h vs proyecto %@ h · Alertas de alcance %lld",
        "Carga %@ h vs proyecto %@ h · Alertas de alcance %lld",
    ),
    "Add estimated values when logging trades": (
        "Agrega valores estimados al registrar trueques",
        "Añade valores estimados al registrar trueques",
    ),
    "Non-cash exchanges logged in BuxMuse.": (
        "Intercambios sin efectivo registrados en BuxMuse.",
        "Intercambios sin efectivo registrados en BuxMuse.",
    ),
    "Long-press & drag to weave the web · tap for territory detail": (
        "Mantén y arrastra para tejer la red · toca para detalle del territorio",
        "Mantén pulsado y arrastra para tejer la red · toca para detalle del territorio",
    ),
    "FULL TERRITORY VIEW": (
        "VISTA COMPLETA DE TERRITORIOS",
        "VISTA COMPLETA DE TERRITORIOS",
    ),
    "Pro territories show merchants, scope radar, invoices, mileage, and more as you enable Studio tools.": (
        "Los territorios Pro muestran comercios, radar de alcance, facturas, kilometraje y más al activar herramientas de Studio.",
        "Los territorios Pro muestran comercios, radar de alcance, facturas, kilometraje y más al activar herramientas de Studio.",
    ),
}

payload = {
    k: {"es-419": a, "es-ES": e}
    for k, (a, e) in ENTRIES.items()
}

OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
print(f"Wrote {len(payload)} keys to {OUT}")
