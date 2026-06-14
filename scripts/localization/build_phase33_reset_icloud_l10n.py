#!/usr/bin/env python3
"""Phase 33 — Factory reset + optional iCloud deletion strings (en → es)."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/localization/phase33-reset-icloud-translations.json"
MERGE = ROOT / "scripts/localization/merge_phase1_translations.py"

T: dict[str, tuple[str, str]] = {
    "This action is irreversible on this device. It will wipe expenses, goals, Tax savings, merchants, logo cache, Studio and Simple Studio records, receipts, scans, backups, and reset all settings. On the next step you choose whether to keep or delete your iCloud backup.": (
        "Esta acción es irreversible en este dispositivo. Borrará gastos, metas, ahorros fiscales, comercios, caché de logos, registros de Studio y Simple Studio, recibos, escaneos, copias y restablecerá todos los ajustes. En el siguiente paso eliges si conservar o eliminar tu copia de iCloud.",
        "Esta acción es irreversible en este dispositivo. Borrará gastos, metas, ahorros fiscales, comercios, caché de logos, registros de Studio y Simple Studio, recibos, escaneos, copias y restablecerá todos los ajustes. En el siguiente paso eliges si conservar o eliminar tu copia de iCloud.",
    ),
    "Continue to iCloud choice": (
        "Continuar a la opción de iCloud",
        "Continuar a la opción de iCloud",
    ),
    "On the next step you choose whether to keep or delete your iCloud backup.": (
        "En el siguiente paso eliges si conservar o eliminar tu copia de iCloud.",
        "En el siguiente paso eliges si conservar o eliminar tu copia de iCloud.",
    ),
    "What should happen to your iCloud data?": (
        "¿Qué debe ocurrir con tus datos de iCloud?",
        "¿Qué debe ocurrir con tus datos de iCloud?",
    ),
    "You can erase this device only and keep a backup in iCloud for your other devices, or permanently delete your BuxMuse iCloud backup on every device signed into this Apple ID.": (
        "Puedes borrar solo este dispositivo y conservar una copia en iCloud para tus otros dispositivos, o eliminar permanentemente la copia de BuxMuse en iCloud en todos los dispositivos con este Apple ID.",
        "Puedes borrar solo este dispositivo y conservar una copia en iCloud para tus otros dispositivos, o eliminar permanentemente la copia de BuxMuse en iCloud en todos los dispositivos con este Apple ID.",
    ),
    "Keep data in iCloud": (
        "Conservar datos en iCloud",
        "Conservar datos en iCloud",
    ),
    "Also delete iCloud data": (
        "Eliminar también datos de iCloud",
        "Eliminar también datos de iCloud",
    ),
    "Back up before deleting iCloud": (
        "Haz una copia antes de eliminar iCloud",
        "Haz una copia antes de eliminar iCloud",
    ),
    "Deleting iCloud data is permanent on all your devices. Save a local JSON backup first if you might need this data later.": (
        "Eliminar datos de iCloud es permanente en todos tus dispositivos. Guarda primero una copia JSON local si podrías necesitar estos datos más tarde.",
        "Eliminar datos de iCloud es permanente en todos tus dispositivos. Guarda primero una copia JSON local si podrías necesitar estos datos más tarde.",
    ),
    "Export JSON backup": (
        "Exportar copia JSON",
        "Exportar copia JSON",
    ),
    "Continue without backup": (
        "Continuar sin copia",
        "Continuar sin copia",
    ),
    "Delete iCloud data?": (
        "¿Eliminar datos de iCloud?",
        "¿Eliminar datos de iCloud?",
    ),
    "Yes, continue": (
        "Sí, continuar",
        "Sí, continuar",
    ),
    "Are you sure? This will permanently remove your BuxMuse backup from iCloud on every device. You cannot recover it from Apple later.": (
        "¿Estás seguro? Esto eliminará permanentemente tu copia de BuxMuse de iCloud en todos los dispositivos. No podrás recuperarla de Apple más tarde.",
        "¿Estás seguro? Esto eliminará permanentemente tu copia de BuxMuse de iCloud en todos los dispositivos. No podrás recuperarla de Apple más tarde.",
    ),
    "Final warning: delete iCloud backup?": (
        "Advertencia final: ¿eliminar copia de iCloud?",
        "Advertencia final: ¿eliminar copia de iCloud?",
    ),
    "Delete iCloud and reset device": (
        "Eliminar iCloud y restablecer dispositivo",
        "Eliminar iCloud y restablecer dispositivo",
    ),
    "Last chance. BuxMuse will erase your iCloud backup and all local data on this device. Other devices will no longer restore from iCloud. Are you absolutely sure?": (
        "Última oportunidad. BuxMuse borrará tu copia de iCloud y todos los datos locales de este dispositivo. Otros dispositivos ya no podrán restaurar desde iCloud. ¿Estás completamente seguro?",
        "Última oportunidad. BuxMuse borrará tu copia de iCloud y todos los datos locales de este dispositivo. Otros dispositivos ya no podrán restaurar desde iCloud. ¿Estás completamente seguro?",
    ),
    "Last chance: BuxMuse will permanently delete every piece of local data on this device. Your iCloud backup will be kept. Are you absolutely sure?": (
        "Última oportunidad: BuxMuse eliminará permanentemente todos los datos locales de este dispositivo. Tu copia de iCloud se conservará. ¿Estás completamente seguro?",
        "Última oportunidad: BuxMuse eliminará permanentemente todos los datos locales de este dispositivo. Tu copia de iCloud se conservará. ¿Estás completamente seguro?",
    ),
    "Save this JSON file somewhere safe — Files, iCloud Drive, or email — before deleting your iCloud backup.": (
        "Guarda este archivo JSON en un lugar seguro — Archivos, iCloud Drive o correo — antes de eliminar tu copia de iCloud.",
        "Guarda este archivo JSON en un lugar seguro — Archivos, iCloud Drive o correo — antes de eliminar tu copia de iCloud.",
    ),
    "Save JSON backup archive": (
        "Guardar copia JSON",
        "Guardar copia JSON",
    ),
    "Continue to iCloud deletion": (
        "Continuar a eliminación de iCloud",
        "Continuar a eliminación de iCloud",
    ),
    "Save local backup": (
        "Guardar copia local",
        "Guardar copia local",
    ),
    "Your BuxMuse database, settings, and iCloud backup have been erased. This device is restored to fresh seeds.": (
        "Tu base de datos, ajustes y copia de iCloud de BuxMuse se han borrado. Este dispositivo se ha restablecido a valores iniciales.",
        "Tu base de datos, ajustes y copia de iCloud de BuxMuse se han borrado. Este dispositivo se ha restablecido a valores iniciales.",
    ),
    "Your BuxMuse database and settings have been restored to fresh seeds. Expenses, Tax savings, merchants, Studio data, caches, and backups are removed. Your iCloud backup was kept.": (
        "Tu base de datos y ajustes de BuxMuse se han restablecido a valores iniciales. Se eliminaron gastos, ahorros fiscales, comercios, datos de Studio, cachés y copias. Tu copia de iCloud se conservó.",
        "Tu base de datos y ajustes de BuxMuse se han restablecido a valores iniciales. Se eliminaron gastos, ahorros fiscales, comercios, datos de Studio, cachés y copias. Tu copia de iCloud se conservó.",
    ),
    "iCloud deletion failed": (
        "Error al eliminar iCloud",
        "Error al eliminar iCloud",
    ),
}


def main() -> None:
    payload = {k: {"es-419": v[0], "es-ES": v[1]} for k, v in T.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} keys to {OUT}")
    subprocess.run([sys.executable, str(MERGE), str(OUT)], check=True, cwd=ROOT)


if __name__ == "__main__":
    main()
