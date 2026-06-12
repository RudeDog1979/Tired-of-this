#!/usr/bin/env python3
"""Phase 28 — Tax Envelope EN keys → es-419 / es-ES."""

from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "docs/localization/phase28-tax-envelope.json"

T: dict[str, tuple[str, str]] = {
    "Tax Envelope": ("Sobre fiscal", "Sobre fiscal"),
    "This week": ("Esta semana", "Esta semana"),
    "Tax jar": ("Hucha fiscal", "Hucha fiscal"),
    "Reminders": ("Recordatorios", "Recordatorios"),
    "My year summary": ("Resumen del año", "Resumen del año"),
    "Full Tax Studio": ("Tax Studio completo", "Tax Studio completo"),
    "Set aside for tax": ("Aparta para impuestos", "Aparta para impuestos"),
    "Guide: %lld%% from catalog": ("Guía: %lld%% del catálogo", "Guía: %lld%% del catálogo"),
    "I saved this": ("Lo guardé", "Lo guardé"),
    "Saved to tax jar": ("Guardado en la hucha", "Guardado en la hucha"),
    "Not now": ("Ahora no", "Ahora no"),
    "Set aside": ("Aparta", "Aparta"),
    "Are you self-employed?": ("¿Trabajas por cuenta propia?", "¿Trabajas por cuenta propia?"),
    "I earn money on my own": ("Gano dinero por mi cuenta", "Gano dinero por mi cuenta"),
    "How often do you get paid?": ("¿Con qué frecuencia cobras?", "¿Con qué frecuencia cobras?"),
    "Weekly": ("Semanal", "Semanal"),
    "Per job": ("Por trabajo", "Por trabajo"),
    "Your tax country": ("Tu país fiscal", "Tu país fiscal"),
    "Recommended save rate": ("Tasa de ahorro recomendada", "Tasa de ahorro recomendada"),
    "Save %lld%%": ("Ahorra %lld%%", "Ahorra %lld%%"),
    "Start Tax Envelope": ("Empezar Sobre fiscal", "Empezar Sobre fiscal"),
    "Next": ("Siguiente", "Siguiente"),
    "Back": ("Atrás", "Atrás"),
    "Open Tax Envelope": ("Abrir Sobre fiscal", "Abrir Sobre fiscal"),
    "Set up Tax Envelope": ("Configurar Sobre fiscal", "Configurar Sobre fiscal"),
    "You made this week": ("Ganaste esta semana", "Ganaste esta semana"),
    "Set aside target": ("Meta de apartado", "Meta de apartado"),
    "Guide rate: %lld%%": ("Tasa guía: %lld%%", "Tasa guía: %lld%%"),
    "Saved in jar": ("Guardado en la hucha", "Guardado en la hucha"),
    "Year target": ("Meta anual", "Meta anual"),
    "Recent saves": ("Ahorros recientes", "Ahorros recientes"),
    "Quarter": ("Trimestre", "Trimestre"),
    "Schedule": ("Calendario", "Calendario"),
    "Next due": ("Próximo vencimiento", "Próximo vencimiento"),
    "Estimated amount": ("Importe estimado", "Importe estimado"),
    "Mark paid": ("Marcar pagado", "Marcar pagado"),
    "Marked paid": ("Marcado pagado", "Marcado pagado"),
    "Set aside, tax jar, and quarterly reminders": (
        "Aparta dinero, hucha fiscal y recordatorios trimestrales",
        "Aparta dinero, hucha fiscal y recordatorios trimestrales",
    ),
    "Set-aside uses your country's tax catalog (%lld%% guide).": (
        "El apartado usa el catálogo fiscal de tu país (guía %lld%%).",
        "El apartado usa el catálogo fiscal de tu país (guía %lld%%).",
    ),
    "You chose to set aside %lld%% from each payment.": (
        "Elegiste apartar %lld%% de cada pago.",
        "Elegiste apartar %lld%% de cada pago.",
    ),
    "Set-aside follows your tax profile rates (%lld%% guide).": (
        "El apartado sigue las tasas de tu perfil fiscal (guía %lld%%).",
        "El apartado sigue las tasas de tu perfil fiscal (guía %lld%%).",
    ),
    "Based on your country's tax rules — about %lld%% is a good starting point.": (
        "Según las reglas fiscales de tu país — ~%lld%% es un buen punto de partida.",
        "Según las normas fiscales de tu país — ~%lld%% es un buen punto de partida.",
    ),
    "You can adjust this anytime in Tax Envelope settings.": (
        "Puedes ajustarlo cuando quieras en ajustes del Sobre fiscal.",
        "Puedes ajustarlo cuando quieras en ajustes del Sobre fiscal.",
    ),
    "Using rates from your tax profile — about %lld%%.": (
        "Usando tasas de tu perfil fiscal — ~%lld%%.",
        "Usando tasas de tu perfil fiscal — ~%lld%%.",
    ),
    "Your tax jar tracks money you set aside for estimated taxes.": (
        "Tu hucha registra el dinero que apartas para impuestos estimados.",
        "Tu hucha registra el dinero que apartas para impuestos estimados.",
    ),
    "Amounts come from your books and the monthly tax catalog — not fixed guesses.": (
        "Los importes vienen de tus libros y el catálogo mensual — no suposiciones fijas.",
        "Los importes vienen de tus libros y el catálogo mensual — no suposiciones fijas.",
    ),
}

payload = {
    key: {"es-419": es419, "es-ES": esES}
    for key, (es419, esES) in T.items()
}

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"Wrote {OUT} ({len(payload)} keys)")
