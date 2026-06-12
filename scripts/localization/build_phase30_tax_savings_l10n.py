#!/usr/bin/env python3
"""Phase 30 — Tax savings full EN → es-419 / es-ES (Intelligence copy + schedule + year summary)."""

from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "docs/localization/phase30-tax-savings-l10n.json"

T: dict[str, tuple[str, str]] = {
    # Intelligence / onboarding (updated copy)
    "BuxMuse Intelligence uses tax rules for the country in your app settings — on your device.": (
        "BuxMuse Intelligence usa las reglas fiscales del país en los ajustes de la app — en tu dispositivo.",
        "BuxMuse Intelligence usa las normas fiscales del país en los ajustes de la app — en tu dispositivo.",
    ),
    "Based on what you log and BuxMuse Intelligence for your country — kept on your device.": (
        "Según lo que registras y BuxMuse Intelligence para tu país — guardado en tu dispositivo.",
        "Según lo que registras y BuxMuse Intelligence para tu país — guardado en tu dispositivo.",
    ),
    "Due dates and amounts from your books and BuxMuse Intelligence for %@.": (
        "Fechas e importes según tus registros y BuxMuse Intelligence para %@.",
        "Fechas e importes según tus registros y BuxMuse Intelligence para %@.",
    ),
    "When do you pay tax?": (
        "¿Cuándo pagas impuestos?",
        "¿Cuándo pagas impuestos?",
    ),
    "Typical in %@: %@. Pick what matches you.": (
        "Lo habitual en %@: %@. Elige lo que te corresponda.",
        "Lo habitual en %@: %@. Elige lo que te corresponda.",
    ),
    "BuxMuse Intelligence suggests %@ for your country. Pick what matches you — estimates update right away.": (
        "BuxMuse Intelligence sugiere %@ para tu país. Elige lo que te corresponda — las estimaciones se actualizan al instante.",
        "BuxMuse Intelligence sugiere %@ para tu país. Elige lo que te corresponda — las estimaciones se actualizan al instante.",
    ),
    "Pick what matches you — due dates and reminders update right away.": (
        "Elige lo que te corresponda — las fechas y recordatorios se actualizan al instante.",
        "Elige lo que te corresponda — las fechas y recordatorios se actualizan al instante.",
    ),
    "Set-aside uses BuxMuse Intelligence for your country (%lld%% guide).": (
        "El apartado usa BuxMuse Intelligence para tu país (guía %lld%%).",
        "El apartado usa BuxMuse Intelligence para tu país (guía %lld%%).",
    ),
    "BuxMuse Intelligence suggests about %lld%% for your country — a good starting point.": (
        "BuxMuse Intelligence sugiere ~%lld%% para tu país — un buen punto de partida.",
        "BuxMuse Intelligence sugiere ~%lld%% para tu país — un buen punto de partida.",
    ),
    "Guide: %lld%% from BuxMuse Intelligence": (
        "Guía: %lld%% según BuxMuse Intelligence",
        "Guía: %lld%% según BuxMuse Intelligence",
    ),
    "Estimated from your books and BuxMuse Intelligence on your device. Change schedule below if yours is different.": (
        "Estimado según tus registros y BuxMuse Intelligence en tu dispositivo. Cambia el calendario abajo si el tuyo es distinto.",
        "Estimado según tus registros y BuxMuse Intelligence en tu dispositivo. Cambia el calendario abajo si el tuyo es distinto.",
    ),
    "Intelligence updated %@": (
        "Intelligence actualizada %@",
        "Intelligence actualizada %@",
    ),
    # Payment schedule labels
    "Monthly": ("Mensual", "Mensual"),
    "Quarterly": ("Trimestral", "Trimestral"),
    "Yearly": ("Anual", "Anual"),
    "Estimated tax this month": ("Impuesto estimado este mes", "Impuesto estimado este mes"),
    "Estimated tax this year": ("Impuesto estimado este año", "Impuesto estimado este año"),
    "Estimated tax this quarter": ("Impuesto estimado este trimestre", "Impuesto estimado este trimestre"),
    "Month": ("Mes", "Mes"),
    "Tax year": ("Año fiscal", "Año fiscal"),
    "Quarter": ("Trimestre", "Trimestre"),
    "Current month due": ("Vence este mes", "Vence este mes"),
    "Current quarter due": ("Vence este trimestre", "Vence este trimestre"),
    "Current year due": ("Vence este año", "Vence este año"),
    "You pay tax": ("Pagas impuestos", "Pagas impuestos"),
    "This year": ("Este año", "Este año"),
    "Tax year %@": ("Año fiscal %@", "Año fiscal %@"),
    # Year summary
    "Share year summary": ("Compartir resumen anual", "Compartir resumen anual"),
    "You pay tax: %@": ("Pagas impuestos: %@", "Pagas impuestos: %@"),
    "Gross income (YTD)": ("Ingresos brutos (acumulado)", "Ingresos brutos (acumulado)"),
    "Deductible expenses": ("Gastos deducibles", "Gastos deducibles"),
    "Estimated tax": ("Impuesto estimado", "Impuesto estimado"),
    "Appendix — not a tax return": ("Anexo — no es una declaración", "Anexo — no es una declaración"),
    "Figures are estimates from your BuxMuse books and BuxMuse Intelligence on your device. File with your tax authority or accountant.": (
        "Las cifras son estimaciones según tus registros de BuxMuse y BuxMuse Intelligence en tu dispositivo. Presenta ante tu autoridad fiscal o contador.",
        "Las cifras son estimaciones según tus registros de BuxMuse y BuxMuse Intelligence en tu dispositivo. Presenta ante tu autoridad fiscal o contador.",
    ),
    # Re-merge phase 29 keys that may have been superseded
    "Tax savings": ("Ahorro fiscal", "Ahorro fiscal"),
    "Set up tax savings": ("Configurar ahorro fiscal", "Configurar ahorro fiscal"),
    "My set-aside": ("Mi apartado", "Mi apartado"),
    "Due soon": ("Próximo pago", "Próximo pago"),
    "This week": ("Esta semana", "Esta semana"),
    "You've set aside": ("Has apartado", "Has apartado"),
    "Estimated tax this year": ("Impuesto estimado este año", "Impuesto estimado este año"),
    "I set money aside": ("Aparté dinero", "Aparté dinero"),
    "Add to my set-aside total": ("Sumar a mi total apartado", "Sumar a mi total apartado"),
    "Added to set-aside total": ("Sumado al total apartado", "Sumado al total apartado"),
    "Skip": ("Omitir", "Omitir"),
    "Paid it": ("Ya lo pagué", "Ya lo pagué"),
    "Due date": ("Fecha límite", "Fecha límite"),
    "Suggested set-aside": ("Apartado sugerido", "Apartado sugerido"),
    "Recent set-asides": ("Apartados recientes", "Apartados recientes"),
    "My year summary": ("Resumen del año", "Resumen del año"),
    "Full Tax Studio": ("Tax Studio completo", "Tax Studio completo"),
    "Set aside for tax": ("Aparta para impuestos", "Aparta para impuestos"),
    "Set aside": ("Aparta", "Aparta"),
    "Amount": ("Importe", "Importe"),
    "Note": ("Nota", "Nota"),
    "Optional": ("Opcional", "Opcional"),
    "Back": ("Atrás", "Atrás"),
    "Next": ("Siguiente", "Siguiente"),
    "Start tax savings": ("Empezar ahorro fiscal", "Empezar ahorro fiscal"),
    "You get paid on your own": ("Cobras por tu cuenta", "Cobras por tu cuenta"),
    "I earn money on my own": ("Gano dinero por mi cuenta", "Gano dinero por mi cuenta"),
    "We suggest how much to set aside": ("Sugerimos cuánto apartar", "Sugerimos cuánto apartar"),
    "Weekly": ("Semanal", "Semanal"),
    "Per job": ("Por trabajo", "Por trabajo"),
    "You log what you set aside": ("Registras lo que apartas", "Registras lo que apartas"),
    "After logging pay, tap Add — or use I set money aside anytime. BuxMuse tracks the total; it does not hold your money.": (
        "Tras registrar pago, pulsa Sumar — o usa Aparté dinero cuando quieras. BuxMuse lleva el total; no guarda tu dinero.",
        "Tras registrar pago, pulsa Sumar — o usa Aparté dinero cuando quieras. BuxMuse lleva el total; no guarda tu dinero.",
    ),
    "We remind you before tax is due": ("Te avisamos antes del vencimiento", "Te avisamos antes del vencimiento"),
    "Default set-aside guide: %lld%%": ("Guía de apartado predeterminada: %lld%%", "Guía de apartado predeterminada: %lld%%"),
    "You made this week": ("Ganaste esta semana", "Ganaste esta semana"),
    "Guide rate: %lld%%": ("Tasa guía: %lld%%", "Tasa guía: %lld%%"),
    "Set aside %@ from this week's pay": ("Aparta %@ del pago de esta semana", "Aparta %@ del pago de esta semana"),
    "%@ of ~%@ estimated tax this year": ("%@ de ~%@ de impuesto estimado este año", "%@ de ~%@ de impuesto estimado este año"),
    "Log pay this week to see how much to set aside": (
        "Registra pago esta semana para ver cuánto apartar",
        "Registra pago esta semana para ver cuánto apartar",
    ),
    "Log pay to see estimated tax for the year": (
        "Registra pagos para ver el impuesto estimado del año",
        "Registra pagos para ver el impuesto estimado del año",
    ),
    "%@ set aside — log pay to refresh your estimate": (
        "%@ apartado — registra pagos para actualizar la estimación",
        "%@ apartado — registra pagos para actualizar la estimación",
    ),
    "Tracks set-asides you log. BuxMuse is not a bank.": (
        "Registra lo que apartas. BuxMuse no es un banco.",
        "Registra lo que apartas. BuxMuse no es un banco.",
    ),
    "Tracks what you log as set aside for tax. BuxMuse does not hold your money.": (
        "Registra lo que apartas para impuestos. BuxMuse no guarda tu dinero.",
        "Registra lo que apartas para impuestos. BuxMuse no guarda tu dinero.",
    ),
    "No set-asides logged yet. Log pay and tap Add, or use I set money aside.": (
        "Sin apartados registrados. Registra pago y pulsa Sumar, o usa Aparté dinero.",
        "Sin apartados registrados. Registra pago y pulsa Sumar, o usa Aparté dinero.",
    ),
    "Adds to your set-aside total. BuxMuse does not move money for you.": (
        "Suma a tu total apartado. BuxMuse no mueve tu dinero.",
        "Suma a tu total apartado. BuxMuse no mueve tu dinero.",
    ),
    "You chose to set aside %lld%% from each payment.": (
        "Elegiste apartar %lld%% de cada pago.",
        "Elegiste apartar %lld%% de cada pago.",
    ),
    "Set-aside follows your tax profile rates (%lld%% guide).": (
        "El apartado sigue las tasas de tu perfil fiscal (guía %lld%%).",
        "El apartado sigue las tasas de tu perfil fiscal (guía %lld%%).",
    ),
    "You can adjust this anytime in tax savings settings.": (
        "Puedes ajustarlo cuando quieras en ajustes de ahorro fiscal.",
        "Puedes ajustarlo cuando quieras en ajustes de ahorro fiscal.",
    ),
    "Using rates from your tax profile — about %lld%%.": (
        "Usando tasas de tu perfil fiscal — ~%lld%%.",
        "Usando tasas de tu perfil fiscal — ~%lld%%.",
    ),
    "Set aside · track · due soon · year summary": (
        "Aparta · registra · próximo pago · resumen anual",
        "Aparta · registra · próximo pago · resumen anual",
    ),
}

payload = {k: {"es-419": v[0], "es-ES": v[1]} for k, v in T.items()}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"Wrote {len(payload)} keys to {OUT}")
