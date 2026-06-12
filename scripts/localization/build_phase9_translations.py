#!/usr/bin/env python3
"""Build phase9 goal/expense engine and related UI format translations."""

from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "docs/localization/phase9-translations.json"

# key -> (es-419, es-ES)
T: dict[str, tuple[str, str]] = {
    # UI format keys
    "%lld%%": ("%lld%%", "%lld%%"),
    "Reliability: %lld%%": ("Confiabilidad: %lld%%", "Fiabilidad: %lld%%"),
    "Runway %@": ("Pista %@", "Pista %@"),
    "Photo opacity": ("Opacidad de foto", "Opacidad de foto"),
    "Overlay opacity %lld%%": ("Opacidad de superposición %lld%%", "Opacidad de superposición %lld%%"),
    "Merge %@ into…": ("Fusionar %@ en…", "Fusionar %@ en…"),
    "Status: %@": ("Estado: %@", "Estado: %@"),
    # Recurrence & misc labels
    "other": ("otro", "otro"),
    "weekly": ("semanal", "semanal"),
    "bi-weekly": ("quincenal", "quincenal"),
    "monthly": ("mensual", "mensual"),
    "yearly": ("anual", "anual"),
    "irregular": ("irregular", "irregular"),
    # Risk / timeline levels & scenario names
    "High": ("Alto", "Alto"),
    "Medium": ("Medio", "Medio"),
    "Low": ("Bajo", "Bajo"),
    "Stalled": ("Estancado", "Estancado"),
    "Accelerating": ("Acelerando", "Acelerando"),
    "Slowing Down": ("Desacelerando", "Desacelerando"),
    "Consistent Momentum": ("Impulso constante", "Impulso constante"),
    "Awaiting Kickstart": ("Esperando impulso inicial", "Esperando impulso inicial"),
    "Current Pace": ("Ritmo actual", "Ritmo actual"),
    "Moderate Trim": ("Recorte moderado", "Recorte moderado"),
    "Aggressive Focus": ("Enfoque agresivo", "Enfoque agresivo"),
    # LocalFinancialIntelligenceEngine — savings suggestion
    "Your %@ spending is %lld%% above baseline. Reducing by 15%% could save you %@ %@/month.": (
        "Tu gasto en %@ está %lld%% por encima de la base. Reducir un 15%% podría ahorrarte %@ %@/mes.",
        "Tu gasto en %@ está un %lld%% por encima de la base. Reducir un 15%% podría ahorrarte %@ %@/mes.",
    ),
    # GoalsRiskEngine
    "Expected completion date is behind your set deadline by %lld month(s).": (
        "La fecha estimada de finalización va %lld mes(es) detrás de tu fecha límite.",
        "La fecha estimada de finalización va %lld mes(es) por detrás de tu fecha límite.",
    ),
    "Expected completion date is slightly behind your set deadline.": (
        "La fecha estimada de finalización va un poco detrás de tu fecha límite.",
        "La fecha estimada de finalización va un poco por detrás de tu fecha límite.",
    ),
    "Increase monthly savings to %@ or extend the goal's deadline.": (
        "Aumenta el ahorro mensual a %@ o extiende la fecha límite de la meta.",
        "Aumenta el ahorro mensual a %@ o amplía la fecha límite de la meta.",
    ),
    "It has been %lld days since your last goal contribution.": (
        "Han pasado %lld días desde tu último aporte a la meta.",
        "Han pasado %lld días desde tu último aporte a la meta.",
    ),
    "Set up an automatic recurring weekly or monthly transfer to stay on track.": (
        "Configura una transferencia recurrente semanal o mensual para mantenerte al día.",
        "Configura una transferencia recurrente semanal o mensual para mantenerte al día.",
    ),
    "No contributions have been made to this goal since its creation %lld days ago.": (
        "No has hecho aportes a esta meta desde que la creaste, hace %lld días.",
        "No has hecho aportes a esta meta desde que la creaste, hace %lld días.",
    ),
    "Kickstart your goal by adding an initial contribution of any amount today.": (
        "Impulsa tu meta con un aporte inicial de cualquier monto hoy.",
        "Impulsa tu meta con un aporte inicial de cualquier importe hoy.",
    ),
    "Heavy overspending in categories like %@ is draining cash reserves.": (
        "El gasto excesivo en categorías como %@ está drenando tu efectivo.",
        "El gasto excesivo en categorías como %@ está agotando tu efectivo.",
    ),
    "Pause non-essential shopping and implement category spending caps immediately.": (
        "Pausa compras no esenciales y pon topes de gasto por categoría de inmediato.",
        "Pausa compras no esenciales y pon topes de gasto por categoría de inmediato.",
    ),
    "Monthly subscription burn rate is %@, reducing your available goal funding.": (
        "El gasto mensual en suscripciones es %@, lo que reduce el dinero disponible para tus metas.",
        "El gasto mensual en suscripciones es %@, lo que reduce el dinero disponible para tus metas.",
    ),
    "Review subscription hub and consider downgrading or pausing lesser-used services.": (
        "Revisa el centro de suscripciones y considera bajar de plan o pausar servicios que casi no usas.",
        "Revisa el centro de suscripciones y plantéate bajar de plan o pausar servicios que casi no usas.",
    ),
    "Large, non-recurring expenses registered recently have temporarily impacted liquid savings.": (
        "Gastos grandes y puntuales recientes han afectado temporalmente tu ahorro líquido.",
        "Gastos grandes y puntuales recientes han afectado temporalmente tu ahorro líquido.",
    ),
    "Create a dedicated buffer fund for unexpected car, travel, or device repairs.": (
        "Crea un fondo de colchón para imprevistos de auto, viajes o reparación de dispositivos.",
        "Crea un fondo de colchón para imprevistos de coche, viajes o reparación de dispositivos.",
    ),
    "Spike detected: %@ spending is %lld%% above baseline.": (
        "Pico detectado: el gasto en %@ está %lld%% por encima de la base.",
        "Pico detectado: el gasto en %@ está un %lld%% por encima de la base.",
    ),
    "Trim %@ expenditures by deferring purchases to next month.": (
        "Recorta gastos en %@ posponiendo compras al próximo mes.",
        "Recorta gastos en %@ posponiendo compras al mes que viene.",
    ),
    "Income flow has decreased by %lld%% compared to last month.": (
        "Tus ingresos bajaron %lld%% frente al mes pasado.",
        "Tus ingresos han bajado un %lld%% respecto al mes pasado.",
    ),
    "Lower contribution amounts this period to protect your fundamental checking account cash flow.": (
        "Baja los aportes este periodo para proteger el flujo de caja de tu cuenta corriente.",
        "Baja los aportes este periodo para proteger el flujo de caja de tu cuenta corriente.",
    ),
    # GoalsMomentumEngine
    "Deposit %@ today to initialize momentum.": (
        "Deposita %@ hoy para iniciar el impulso.",
        "Ingresa %@ hoy para iniciar el impulso.",
    ),
    "Set a calendar reminder for weekly goal updates.": (
        "Pon un recordatorio semanal en el calendario para revisar tus metas.",
        "Pon un recordatorio semanal en el calendario para revisar tus metas.",
    ),
    "Form a weekly check-in habit to review cash flow.": (
        "Crea el hábito de revisar tu flujo de caja cada semana.",
        "Crea el hábito de revisar tu flujo de caja cada semana.",
    ),
    "Match non-essential treats (like coffee) with a goal contribution.": (
        "Empareja caprichos no esenciales (como el café) con un aporte a la meta.",
        "Empareja caprichos no esenciales (como el café) con un aporte a la meta.",
    ),
    "Make a small %@ micro-contribution to break the dry spell.": (
        "Haz un micro-aporte de %@ para romper la sequía.",
        "Haz un micro-aporte de %@ para romper la sequía.",
    ),
    "Review your budget to see where cash has been leak-drained.": (
        "Revisa tu presupuesto para ver dónde se te escapa el efectivo.",
        "Revisa tu presupuesto para ver dónde se te escapa el efectivo.",
    ),
    "Automate a micro-savings deposit of %@ per day.": (
        "Automatiza un micro-ahorro de %@ al día.",
        "Automatiza un micro-ahorro de %@ al día.",
    ),
    "Link savings goals to positive daily habits.": (
        "Vincula tus metas de ahorro a hábitos diarios positivos.",
        "Vincula tus metas de ahorro a hábitos diarios positivos.",
    ),
    "Double down! Try to add another %@ while in this active streak.": (
        "¡Aprovecha el impulso! Intenta sumar otros %@ mientras dure esta racha activa.",
        "¡Aprovecha el impulso! Intenta sumar otros %@ mientras dure esta racha activa.",
    ),
    "Share your savings milestone with a trusted partner.": (
        "Comparte tu hito de ahorro con alguien de confianza.",
        "Comparte tu hito de ahorro con alguien de confianza.",
    ),
    "Keep this active momentum high by saving at the beginning of the week.": (
        "Mantén este impulso activo ahorrando al inicio de la semana.",
        "Mantén este impulso activo ahorrando al inicio de la semana.",
    ),
    "Build a 3-week streak of consecutive contributions.": (
        "Arma una racha de 3 semanas con aportes consecutivos.",
        "Monta una racha de 3 semanas con aportes consecutivos.",
    ),
    "Re-engage today by allocating just %@ to this goal.": (
        "Vuelve a activarte hoy asignando solo %@ a esta meta.",
        "Vuelve a activarte hoy asignando solo %@ a esta meta.",
    ),
    "Audit recent purchases to identify saving leakages.": (
        "Audita compras recientes para detectar fugas de ahorro.",
        "Audita compras recientes para detectar fugas de ahorro.",
    ),
    "Reschedule savings day to align precisely with your payday.": (
        "Reprograma tu día de ahorro para que coincida con tu día de pago.",
        "Reprograma tu día de ahorro para que coincida con tu día de pago.",
    ),
    "Avoid the 'all-or-nothing' mindset: small regular steps outperform large rare steps.": (
        "Evita el todo o nada: pasos pequeños y regulares ganan a saltos grandes y raros.",
        "Evita el todo o nada: pasos pequeños y regulares ganan a saltos grandes y raros.",
    ),
    "Excellent progress! Consider locking in a portion of this month's extra savings.": (
        "¡Excelente avance! Considera reservar parte del ahorro extra de este mes.",
        "¡Excelente avance! Plantéate reservar parte del ahorro extra de este mes.",
    ),
    "Review if your target date can be pulled forward.": (
        "Revisa si puedes adelantar tu fecha objetivo.",
        "Revisa si puedes adelantar tu fecha objetivo.",
    ),
    "Increase your auto-saving amount by 5% to harness your momentum.": (
        "Sube tu auto-ahorro un 5%% para aprovechar el impulso.",
        "Sube tu auto-ahorro un 5%% para aprovechar el impulso.",
    ),
    "Reward yourself with a small, free celebration for accelerated pacing.": (
        "Celébralo con algo pequeño y gratis por este ritmo acelerado.",
        "Celébralo con algo pequeño y gratis por este ritmo acelerado.",
    ),
    "Adjust your milestone targets slightly to feel less pressure.": (
        "Ajusta un poco tus hitos para sentir menos presión.",
        "Ajusta un poco tus hitos para sentir menos presión.",
    ),
    "Audit subscriptions to redirect a quick %@ today.": (
        "Revisa suscripciones para redirigir %@ hoy mismo.",
        "Revisa suscripciones para redirigir %@ hoy mismo.",
    ),
    "Try 'zero-spend days' once a week to free up cash.": (
        "Prueba días de gasto cero una vez por semana para liberar efectivo.",
        "Prueba días de gasto cero una vez por semana para liberar efectivo.",
    ),
    "Keep contributions recurring to remove friction.": (
        "Mantén aportes recurrentes para quitar fricción.",
        "Mantén aportes recurrentes para quitar fricción.",
    ),
    "Maintain this excellent, stable velocity with your regular deposit.": (
        "Mantén esta velocidad estable con tu depósito habitual.",
        "Mantén esta velocidad estable con tu ingreso habitual.",
    ),
    "Confirm your current cash reserves are healthy.": (
        "Confirma que tus reservas de efectivo están sanas.",
        "Confirma que tus reservas de efectivo están sanas.",
    ),
    "Establish a permanent auto-contribution so you don't even have to think about it.": (
        "Configura un auto-aporte permanente para no tener que pensarlo.",
        "Configura un auto-aporte permanente para no tener que pensarlo.",
    ),
    "Maintain the 'pay yourself first' golden rule.": (
        "Mantén la regla de oro: págate primero.",
        "Mantén la regla de oro: págate primero.",
    ),
    # GoalsTimelineAI
    "Maintain your standard deposit speed.": (
        "Mantén tu ritmo habitual de depósitos.",
        "Mantén tu ritmo habitual de ingresos.",
    ),
    "Reduce groceries and restaurants by 10%.": (
        "Reduce supermercado y restaurantes un 10%%.",
        "Reduce supermercado y restaurantes un 10%%.",
    ),
    "Cancel unused memberships & pause non-essential shopping.": (
        "Cancela membresías que no usas y pausa compras no esenciales.",
        "Cancela membresías que no usas y pausa compras no esenciales.",
    ),
    "Reach your goal faster by setting up a small recurring weekly contribution.": (
        "Llega antes a tu meta con un aporte semanal recurrente pequeño.",
        "Llega antes a tu meta con un aporte semanal recurrente pequeño.",
    ),
    "If you %@ %@": (
        "Si %@ %@",
        "Si %@ %@",
    ),
    # GoalsOpportunityEngine
    "Cancel your unused %@ subscription.": (
        "Cancela tu suscripción a %@ que no usas.",
        "Cancela tu suscripción a %@ que no usas.",
    ),
    "Redirect %@/mo to reach your goal %@ months earlier.": (
        "Redirige %@/mes para llegar a tu meta %@ meses antes.",
        "Redirige %@/mes para llegar a tu meta %@ meses antes.",
    ),
    "Trim %@ expenses by 15%%.": (
        "Recorta gastos en %@ un 15%%.",
        "Recorta gastos en %@ un 15%%.",
    ),
    "Redirect %@/mo to finish %@ months earlier.": (
        "Redirige %@/mes para terminar %@ meses antes.",
        "Redirige %@/mes para terminar %@ meses antes.",
    ),
    "Redirect recent windfall from %@ to your goal.": (
        "Redirige el ingreso extra reciente de %@ a tu meta.",
        "Redirige el ingreso extra reciente de %@ a tu meta.",
    ),
    "Reach your goal %@ months earlier with a one-time %@ deposit.": (
        "Llega a tu meta %@ meses antes con un depósito único de %@.",
        "Llega a tu meta %@ meses antes con un ingreso único de %@.",
    ),
    "Save an extra %@/mo by packing your own lunch.": (
        "Ahorra %@/mes extra llevando tu almuerzo.",
        "Ahorra %@/mes extra llevando tu almuerzo.",
    ),
    "Accelerate your completion timeline by %@ months.": (
        "Acelera tu cronograma de finalización en %@ meses.",
        "Acelera tu cronograma de finalización en %@ meses.",
    ),
    # ExpenseIntelligenceEngine
    "Repeats %@ · %lld%% confidence": (
        "Se repite %@ · %lld%% de confianza",
        "Se repite %@ · %lld%% de confianza",
    ),
    " · Next around %@": (
        " · Próximo alrededor de %@",
        " · Próximo alrededor de %@",
    ),
    "Refund detected — funds returned to your wallet.": (
        "Reembolso detectado — fondos devueltos a tu billetera.",
        "Reembolso detectado — fondos devueltos a tu cartera.",
    ),
    "Possible duplicate charge — review this transaction.": (
        "Posible cargo duplicado — revisa esta transacción.",
        "Posible cargo duplicado — revisa esta transacción.",
    ),
    "Spending in %@ affects goal pacing.": (
        "El gasto en %@ afecta el ritmo de tus metas.",
        "El gasto en %@ afecta el ritmo de tus metas.",
    ),
    "Matches an active subscription pattern in your hub.": (
        "Coincide con un patrón de suscripción activa en tu centro.",
        "Coincide con un patrón de suscripción activa en tu centro.",
    ),
    "Matches your %@ pattern": (
        "Coincide con tu patrón de %@",
        "Coincide con tu patrón de %@",
    ),
    "This looks like a subscription · %@ cycle": (
        "Parece una suscripción · ciclo %@",
        "Parece una suscripción · ciclo %@",
    ),
    "Part of a monthly cycle at this merchant": (
        "Parte de un ciclo mensual en este comercio",
        "Parte de un ciclo mensual en este comercio",
    ),
    "%@ appears often in your recent activity (%lld times).": (
        "%@ aparece seguido en tu actividad reciente (%lld veces).",
        "%@ aparece a menudo en tu actividad reciente (%lld veces).",
    ),
    "You've logged %lld expenses at %@ recently.": (
        "Registraste %lld gastos en %@ recientemente.",
        "Has registrado %lld gastos en %@ recientemente.",
    ),
}


def main() -> None:
    payload = {k: {"es-419": a, "es-ES": e} for k, (a, e) in T.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} keys to {OUT}")


if __name__ == "__main__":
    main()
