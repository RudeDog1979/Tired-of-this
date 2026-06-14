#!/usr/bin/env python3
"""Phase 31 — Consumer debt feature strings (en → es)."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/localization/phase31-debt-translations.json"
MERGE = ROOT / "scripts/localization/merge_phase1_translations.py"

T: dict[str, tuple[str, str]] = {
    "Log your first debt": ("Registra tu primera deuda", "Registra tu primera deuda"),
    "Track what you owe": ("Controla lo que debes", "Controla lo que debes"),
    "Banks, family loans, and informal lenders — all in one place.": (
        "Bancos, préstamos familiares y prestamistas informales — todo en un solo lugar.",
        "Bancos, préstamos familiares y prestamistas informales — todo en un solo lugar.",
    ),
    "Turn on consumer debt tracking to see balances, reminders, and payoff insights.": (
        "Activa el seguimiento de deuda personal para ver saldos, recordatorios e ideas de pago.",
        "Activa el seguimiento de deuda personal para ver saldos, recordatorios e ideas de pago.",
    ),
    "Log debt": ("Registrar deuda", "Registrar deuda"),
    "Turn on & log debt": ("Activar y registrar deuda", "Activar y registrar deuda"),
    "Debt Center": ("Centro de deudas", "Centro de deudas"),
    "Track consumer debt": ("Seguir deuda personal", "Seguir deuda personal"),
    "Track bank loans, credit cards, family loans, and informal lenders.": (
        "Registra préstamos bancarios, tarjetas, préstamos familiares y prestamistas informales.",
        "Registra préstamos bancarios, tarjetas, préstamos familiares y prestamistas informales.",
    ),
    "Track credit cards, loans, and other balances in one place.": (
        "Registra tarjetas, préstamos y otros saldos en un solo lugar.",
        "Registra tarjetas, préstamos y otros saldos en un solo lugar.",
    ),
    "Active debts": ("Deudas activas", "Deudas activas"),
    "Upcoming reminders": ("Próximos recordatorios", "Próximos recordatorios"),
    "Balance breakdown": ("Desglose del saldo", "Desglose del saldo"),
    "Your debts": ("Tus deudas", "Tus deudas"),
    "On-device insights": ("Información en el dispositivo", "Información en el dispositivo"),
    "On-device intelligence": ("Inteligencia en el dispositivo", "Inteligencia en el dispositivo"),
    "Show archived debts": ("Mostrar deudas archivadas", "Mostrar deudas archivadas"),
    "Add debt": ("Agregar deuda", "Agregar deuda"),
    "Payment log": ("Historial de pagos", "Historial de pagos"),
    "Payment history": ("Historial de pagos", "Historial de pagos"),
    "Due date reminders": ("Recordatorios de vencimiento", "Recordatorios de vencimiento"),
    "Local notification 3 days before your due date.": (
        "Notificación local 3 días antes de tu fecha de pago.",
        "Notificación local 3 días antes de tu fecha de pago.",
    ),
    "Reminders": ("Recordatorios", "Recordatorios"),
    "Current balance": ("Saldo actual", "Saldo actual"),
    "Original balance": ("Saldo original", "Saldo original"),
    "APR %": ("TAE %", "TAE %"),
    "Minimum payment": ("Pago mínimo", "Pago mínimo"),
    "Monthly due date": ("Fecha de pago mensual", "Fecha de pago mensual"),
    "Payment due today — reminder is on.": (
        "Pago vence hoy — el recordatorio está activo.",
        "Pago vence hoy — el recordatorio está activo.",
    ),
    "Terms": ("Condiciones", "Condiciones"),
    "Account": ("Cuenta", "Cuenta"),
    "Credit card": ("Tarjeta de crédito", "Tarjeta de crédito"),
    "Personal loan": ("Préstamo personal", "Préstamo personal"),
    "Student loan": ("Préstamo estudiantil", "Préstamo estudiantil"),
    "Mortgage": ("Hipoteca", "Hipoteca"),
    "Other debt": ("Otra deuda", "Otra deuda"),
    "Bank": ("Banco", "Banco"),
    "Credit union": ("Cooperativa de crédito", "Cooperativa de crédito"),
    "Friend or family": ("Amigo o familiar", "Amigo o familiar"),
    "Private individual": ("Particular", "Particular"),
    "Informal lender": ("Prestamista informal", "Prestamista informal"),
    "Other source": ("Otra fuente", "Otra fuente"),
    "Focus payment": ("Priorizar pago", "Priorizar pago"),
    "%@ carries the largest balance — extra payments there reduce total interest fastest.": (
        "%@ tiene el saldo más alto — pagos extra ahí reducen intereses más rápido.",
        "%@ tiene el saldo más alto — pagos extra ahí reducen intereses más rápido.",
    ),
    "Due soon": ("Vence pronto", "Vence pronto"),
    "%@ payment is due today.": ("El pago de %@ vence hoy.", "El pago de %@ vence hoy."),
    "%@ payment is due in %lld days.": (
        "El pago de %@ vence en %lld días.",
        "El pago de %@ vence en %lld días.",
    ),
    "No payment yet": ("Sin pago aún", "Sin pago aún"),
    "You haven't logged a payment for %@ this month.": (
        "No has registrado un pago para %@ este mes.",
        "No has registrado un pago para %@ este mes.",
    ),
    "Debt snapshot": ("Resumen de deudas", "Resumen de deudas"),
    "You're tracking %lld active balances on this device.": (
        "Estás siguiendo %lld saldos activos en este dispositivo.",
        "Estás siguiendo %lld saldos activos en este dispositivo.",
    ),
    "Great progress": ("Gran avance", "Gran avance"),
    "You've paid down %lld%% of the original balance.": (
        "Has pagado el %lld%% del saldo original.",
        "Has pagado el %lld%% del saldo original.",
    ),
    "High interest": ("Interés alto", "Interés alto"),
    "At %@%% APR, paying more than the minimum saves real money over time.": (
        "Con %@%% TAE, pagar más que el mínimo ahorra dinero real con el tiempo.",
        "Con %@%% TAE, pagar más que el mínimo ahorra dinero real con el tiempo.",
    ),
    "Payoff path": ("Camino de pago", "Camino de pago"),
    "At your minimum payment, this could be paid off around %@.": (
        "Con tu pago mínimo, esto podría liquidarse alrededor de %@.",
        "Con tu pago mínimo, esto podría liquidarse alrededor de %@.",
    ),
    "Informal loan": ("Préstamo informal", "Préstamo informal"),
    "Log every payment so you always know what's left — even without a bank statement.": (
        "Registra cada pago para saber siempre cuánto queda — incluso sin extracto bancario.",
        "Registra cada pago para saber siempre cuánto queda — incluso sin extracto bancario.",
    ),
    "Almost there": ("Casi listo", "Casi listo"),
    "You're close to clearing this balance. One more push could finish it.": (
        "Estás cerca de liquidar este saldo. Un último empujón podría terminarlo.",
        "Estás cerca de liquidar este saldo. Un último empujón podría terminarlo.",
    ),
    "Debt payment due soon": ("Pago de deuda vence pronto", "Pago de deuda vence pronto"),
    "Logo appears only for known banks in our catalog. Everyone else gets a category icon.": (
        "El logo solo aparece para bancos conocidos en nuestro catálogo. Los demás usan un icono de categoría.",
        "El logo solo aparece para bancos conocidos en nuestro catálogo. Los demás usan un icono de categoría.",
    ),
    "e.g. Mom, Uncle Carlos": ("p. ej. Mamá, Tío Carlos", "p. ej. Mamá, Tío Carlos"),
    "e.g. Local lender": ("p. ej. Prestamista local", "p. ej. Prestamista local"),
    "e.g. John Smith": ("p. ej. Juan Pérez", "p. ej. Juan Pérez"),
    "e.g. Chase, mBank": ("p. ej. Chase, mBank", "p. ej. Chase, mBank"),
    "Track debt": ("Seguir deudas", "Seguir deudas"),
    "Optional. Turn on consumer debt tracking to log loans, cards, and informal lenders.": (
        "Opcional. Activa el seguimiento de deuda personal para registrar préstamos, tarjetas y prestamistas informales.",
        "Opcional. Activa el seguimiento de deuda personal para registrar préstamos, tarjetas y prestamistas informales.",
    ),
    "Optionally track loans, cards, and informal debt": (
        "Opcionalmente registra préstamos, tarjetas y deuda informal",
        "Opcionalmente registra préstamos, tarjetas y deuda informal",
    ),
    "4. Consumer debt": ("4. Deuda personal", "4. Deuda personal"),
}


def main() -> None:
    payload = {k: {"es-419": v[0], "es-ES": v[1]} for k, v in T.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} keys to {OUT}")
    subprocess.run([sys.executable, str(MERGE), str(OUT)], check=True, cwd=ROOT)


if __name__ == "__main__":
    main()
