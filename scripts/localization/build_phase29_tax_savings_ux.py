#!/usr/bin/env python3
"""Phase 29 — Tax savings UX clarity (EN → es-419 / es-ES)."""

from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "docs/localization/phase29-tax-savings-ux.json"

T: dict[str, tuple[str, str]] = {
    "Tax savings": ("Ahorro fiscal", "Ahorro fiscal"),
    "Set up tax savings": ("Configurar ahorro fiscal", "Configurar ahorro fiscal"),
    "My set-aside": ("Mi apartado", "Mi apartado"),
    "Due soon": ("Próximo pago", "Próximo pago"),
    "You've set aside": ("Has apartado", "Has apartado"),
    "Estimated tax this year": ("Impuesto estimado este año", "Impuesto estimado este año"),
    "Estimated tax this quarter": ("Impuesto estimado este trimestre", "Impuesto estimado este trimestre"),
    "I set money aside": ("Aparté dinero", "Aparté dinero"),
    "Add to my set-aside total": ("Sumar a mi total apartado", "Sumar a mi total apartado"),
    "Added to set-aside total": ("Sumado al total apartado", "Sumado al total apartado"),
    "Skip": ("Omitir", "Omitir"),
    "Paid it": ("Ya lo pagué", "Ya lo pagué"),
    "Due date": ("Fecha límite", "Fecha límite"),
    "Payment schedule": ("Calendario de pagos", "Calendario de pagos"),
    "Suggested set-aside": ("Apartado sugerido", "Apartado sugerido"),
    "Recent set-asides": ("Apartados recientes", "Apartados recientes"),
    "Set aside %@ from this week's pay": (
        "Aparta %@ del pago de esta semana",
        "Aparta %@ del pago de esta semana",
    ),
    "%@ of ~%@ estimated tax this year": (
        "%@ de ~%@ de impuesto estimado este año",
        "%@ de ~%@ de impuesto estimado este año",
    ),
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
    "Estimated from your books and your country's tax rules.": (
        "Estimado según tus registros y las reglas fiscales de tu país.",
        "Estimado según tus registros y las normas fiscales de tu país.",
    ),
    "Adds to your set-aside total. BuxMuse does not move money for you.": (
        "Suma a tu total apartado. BuxMuse no mueve tu dinero.",
        "Suma a tu total apartado. BuxMuse no mueve tu dinero.",
    ),
    "You get paid on your own": (
        "Cobras por tu cuenta",
        "Cobras por tu cuenta",
    ),
    "We use your country's tax rules to suggest how much to set aside.": (
        "Usamos las reglas fiscales de tu país para sugerir cuánto apartar.",
        "Usamos las normas fiscales de tu país para sugerir cuánto apartar.",
    ),
    "We suggest how much to set aside": (
        "Sugerimos cuánto apartar",
        "Sugerimos cuánto apartar",
    ),
    "Based on what you log and your country's tax rules — updated monthly.": (
        "Según lo que registras y las reglas fiscales de tu país — actualizado cada mes.",
        "Según lo que registras y las normas fiscales de tu país — actualizado cada mes.",
    ),
    "You log what you set aside": (
        "Registras lo que apartas",
        "Registras lo que apartas",
    ),
    "After logging pay, tap Add — or use I set money aside anytime. BuxMuse tracks the total; it does not hold your money.": (
        "Tras registrar pago, pulsa Sumar — o usa Aparté dinero cuando quieras. BuxMuse lleva el total; no guarda tu dinero.",
        "Tras registrar pago, pulsa Sumar — o usa Aparté dinero cuando quieras. BuxMuse lleva el total; no guarda tu dinero.",
    ),
    "We remind you before tax is due": (
        "Te avisamos antes del vencimiento",
        "Te avisamos antes del vencimiento",
    ),
    "Due dates and amounts from your books and %@ tax rules.": (
        "Fechas e importes según tus registros y las reglas fiscales de %@.",
        "Fechas e importes según tus registros y las normas fiscales de %@.",
    ),
    "Default set-aside guide: %lld%%": (
        "Guía de apartado predeterminada: %lld%%",
        "Guía de apartado predeterminada: %lld%%",
    ),
    "Start tax savings": ("Empezar ahorro fiscal", "Empezar ahorro fiscal"),
    "Guide: %lld%% from your tax rules": (
        "Guía: %lld%% según tus reglas fiscales",
        "Guía: %lld%% según tus normas fiscales",
    ),
    "Set aside · track · due soon · year summary": (
        "Aparta · registra · próximo pago · resumen anual",
        "Aparta · registra · próximo pago · resumen anual",
    ),
    "You can adjust this anytime in tax savings settings.": (
        "Puedes ajustarlo cuando quieras en ajustes de ahorro fiscal.",
        "Puedes ajustarlo cuando quieras en ajustes de ahorro fiscal.",
    ),
}

payload = {k: {"es-419": v[0], "es-ES": v[1]} for k, v in T.items()}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"Wrote {len(payload)} keys to {OUT}")
