#!/usr/bin/env python3
"""Phase 17 — Expenses, Subscription Hub, Insights (es-419 / es-ES)."""

from __future__ import annotations

import json
from pathlib import Path

OUT = (
    Path(__file__).resolve().parents[2]
    / "docs/localization/phase17-expenses-subscriptions-insights.json"
)

T: dict[str, tuple[str, str]] = {
    # Expenses — summary & intelligence
    "Trending towards %@ this month": (
        "Tendencia hacia %@ este mes",
        "Tendencia hacia %@ este mes",
    ),
    "Duplicate": ("Duplicado", "Duplicado"),
    "Refund": ("Reembolso", "Reembolso"),
    "Recurrence": ("Recurrencia", "Recurrencia"),
    "Subscription": ("Suscripción", "Suscripción"),
    "Heat zone": ("Zona caliente", "Zona caliente"),
    "Future impact": ("Impacto futuro", "Impacto futuro"),
    "Habit signature": ("Firma de hábito", "Firma de hábito"),
    "Micro commitment": ("Microcompromiso", "Microcompromiso"),
    "Emotional tag": ("Etiqueta emocional", "Etiqueta emocional"),
    "Context": ("Contexto", "Contexto"),
    "Category": ("Categoría", "Categoría"),
    "Merchant": ("Comercio", "Comercio"),
    "Goals": ("Metas", "Metas"),
    "Subscriptions": ("Suscripciones", "Suscripciones"),
    "Matches your %@ pattern": ("Coincide con tu patrón de %@", "Coincide con tu patrón de %@"),
    "Part of a monthly cycle at this merchant": (
        "Parte de un ciclo mensual en este comercio",
        "Parte de un ciclo mensual en este comercio",
    ),
    # Emotional tags
    "None": ("Ninguna", "Ninguna"),
    "Joy": ("Alegría", "Alegría"),
    "Excited": ("Emoción", "Emoción"),
    "Calm": ("Calma", "Calma"),
    "Neutral": ("Neutral", "Neutral"),
    "Stress": ("Estrés", "Estrés"),
    "Regret": ("Arrepentimiento", "Arrepentimiento"),
    "Guilty": ("Culpa", "Culpa"),
    "This purchase brought you joy — worth celebrating.": (
        "Esta compra te dio alegría — vale la pena celebrarla.",
        "Esta compra te dio alegría — vale la pena celebrarla.",
    ),
    "You felt excited about this one. Enjoy it mindfully.": (
        "Te emocionó esta compra. Disfrútala con conciencia.",
        "Te emocionó esta compra. Disfrútala con conciencia.",
    ),
    "A calm, intentional spend. Nice balance.": (
        "Un gasto tranquilo e intencional. Buen equilibrio.",
        "Un gasto tranquilo e intencional. Buen equilibrio.",
    ),
    "A practical, neutral expense.": (
        "Un gasto práctico y neutral.",
        "Un gasto práctico y neutral.",
    ),
    "Tagged under stress. Worth a pause before the next similar buy.": (
        "Marcado como estrés. Vale la pena pausar antes de una compra similar.",
        "Marcado como estrés. Vale la pena pausar antes de una compra similar.",
    ),
    "Tagged as regret. Consider avoiding similar purchases.": (
        "Marcado como arrepentimiento. Considera evitar compras similares.",
        "Marcado como arrepentimiento. Considera evitar compras similares.",
    ),
    "Some guilt here — reflect on whether this matched your values.": (
        "Hay algo de culpa — piensa si esto va con tus valores.",
        "Hay algo de culpa — piensa si esto va con tus valores.",
    ),
    "Emotional tag: %@.": ("Etiqueta emocional: %@.", "Etiqueta emocional: %@."),
    # Subscription hub — detail copy
    "Apple TV+ (Cheaper alternatives starting at %@ 9.99/mo)": (
        "Apple TV+ (alternativas desde %@ 9.99/mes)",
        "Apple TV+ (alternativas desde %@ 9,99/mes)",
    ),
    "Ad-supported plan (%@ 6.99/mo)": (
        "Plan con anuncios (%@ 6.99/mes)",
        "Plan con anuncios (%@ 6,99/mes)",
    ),
    "Active Netflix Premium account. Price increased by 15%% in recent cycle. Consider moving to standard ad-supported tier to save %@ 8.50/mo.": (
        "Cuenta Netflix Premium activa. El precio subió 15%% en el ciclo reciente. Considera el plan con anuncios para ahorrar %@ 8.50/mes.",
        "Cuenta Netflix Premium activa. El precio subió un 15%% en el ciclo reciente. Considera el plan con anuncios para ahorrar %@ 8,50/mes.",
    ),
    "YouTube Music (Included in Premium)": (
        "YouTube Music (incluido en Premium)",
        "YouTube Music (incluido en Premium)",
    ),
    "Spotify Individual (%@ 11.99/mo)": (
        "Spotify Individual (%@ 11.99/mes)",
        "Spotify Individual (%@ 11,99/mes)",
    ),
    "Shared Spotify Family account. Consider Spotify Individual if only one person uses it.": (
        "Cuenta Spotify Familiar compartida. Considera Spotify Individual si solo una persona la usa.",
        "Cuenta Spotify Familiar compartida. Considera Spotify Individual si solo una persona la usa.",
    ),
    "Downgrade plan": ("Bajar de plan", "Bajar de plan"),
    "Share a bundle with family": (
        "Compartir un paquete en familia",
        "Compartir un paquete en familia",
    ),
    "Monthly Savings": ("Ahorro mensual", "Ahorro mensual"),
    "Yearly Savings": ("Ahorro anual", "Ahorro anual"),
    # Insights — feature strips
    "Credit & BNPL": ("Crédito y BNPL", "Crédito y BNPL"),
    "Cash Drawer": ("Caja en efectivo", "Caja en efectivo"),
    "Barter & Trade": ("Trueque e intercambio", "Trueque e intercambio"),
    "Workspaces": ("Espacios de trabajo", "Espacios de trabajo"),
    "Creative Energy": ("Energía creativa", "Energía creativa"),
    "Scope Radar": ("Radar de alcance", "Radar de alcance"),
    "Settings → Payment Sources": (
        "Ajustes → Fuentes de pago",
        "Ajustes → Fuentes de pago",
    ),
    "Studio → Cash & Barter": (
        "Studio → Efectivo y trueque",
        "Studio → Efectivo y trueque",
    ),
    "Studio → Turn on": ("Studio → Activar", "Studio → Activar"),
    "Studio → Workspaces": (
        "Studio → Espacios de trabajo",
        "Studio → Espacios de trabajo",
    ),
    "Studio → Workload & Energy": (
        "Studio → Carga y energía",
        "Studio → Carga y energía",
    ),
    "Studio → Scope Radar": (
        "Studio → Radar de alcance",
        "Studio → Radar de alcance",
    ),
    "Upgrade to Pro": ("Mejorar a Pro", "Pasar a Pro"),
    "Enable in Studio → Cash & Barter": (
        "Actívalo en Studio → Efectivo y trueque",
        "Actívalo en Studio → Efectivo y trueque",
    ),
    "Enable Studio first": (
        "Activa Studio primero",
        "Activa Studio primero",
    ),
    "Track workload & rest": (
        "Registra carga de trabajo y descanso",
        "Registra carga de trabajo y descanso",
    ),
    "%.1f h work · %.1f h sleep": (
        "%.1f h trabajo · %.1f h sueño",
        "%.1f h trabajo · %.1f h sueño",
    ),
    "Your subscriptions increased by %@ this month.": (
        "Tus suscripciones subieron %@ este mes.",
        "Tus suscripciones subieron %@ este mes.",
    ),
    "Your subscriptions are fully optimized with no price hikes.": (
        "Tus suscripciones están optimizadas, sin aumentos de precio.",
        "Tus suscripciones están optimizadas, sin subidas de precio.",
    ),
}


def main() -> None:
    payload = {k: {"es-419": v[0], "es-ES": v[1]} for k, v in T.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} keys to {OUT}")


if __name__ == "__main__":
    main()
