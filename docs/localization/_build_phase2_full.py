#!/usr/bin/env python3
"""Build phase2-translations-full.json from phase2 keys, phase1 reuse, and translations."""
import json
import re
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
KEYS_FILE = ROOT / "phase2-keys.txt"
PHASE1_FILE = ROOT / "phase1-translations.json"
PARTIAL_FILE = ROOT / "phase2-translations.json"
OUT_FILE = ROOT / "phase2-translations-full.json"

KEEP_EN = {
    "BuxMuse", "Bux Canvas", "Studio", "Card Studio", "Simple Studio", "Pro Studio",
    "Face ID", "HealthKit", "Business Card Studio", "Scope Radar",
    "Bux Adjust", "Bux Background", "Bux FX", "Bux Focal Crop", "Bux Layers",
    "Bux Photo", "Bux Photo Lab", "Bux Shape", "Bux Shapes",
    "BUXMUSE STUDIO", "WhatsApp", "vCard", "PDF", "PNG", "QR", "CRM", "FAQ",
    "VAT", "GST", "ITBIS", "Pro", "Live Activity", "Lock Screen",
}

# Hand-refined overrides (machine base + glossary polish)
MANUAL = {
    "Ask your studio anything": ("Pregúntale lo que quieras a tu Studio", "Pregúntale lo que quieras a tu Studio"),
    "BUXMUSE STUDIO": ("BUXMUSE STUDIO", "BUXMUSE STUDIO"),
    "Card Studio": ("Card Studio", "Card Studio"),
    "Simple Studio": ("Simple Studio", "Simple Studio"),
    "Simple Invoice": ("Simple Invoice", "Simple Invoice"),
    "Simple invoice": ("Simple Invoice", "Simple Invoice"),
    "Tax Studio": ("Tax Studio", "Tax Studio"),
    "Full Tax Studio in Pro": ("Tax Studio completo en Pro", "Tax Studio completo en Pro"),
    "Sent via BuxMuse · Not a bank": ("Enviado vía BuxMuse · No es un banco", "Enviado vía BuxMuse · No es un banco"),
    "Design print-ready cards in minutes — geometric templates, Bux Canvas, photo lab, and export to PDF or vCard.": (
        "Diseña tarjetas listas para imprimir en minutos — plantillas geométricas, Bux Canvas, laboratorio de fotos y exporta a PDF o vCard.",
        "Diseña tarjetas listas para imprimir en minutos — plantillas geométricas, Bux Canvas, laboratorio de fotos y exporta a PDF o vCard.",
    ),
    "Clients, invoices, projects, receipts, mileage, tax deductions, and your Simple ledger — all offline.": (
        "Clientes, facturas, proyectos, recibos, millaje, deducciones fiscales y tu libro Simple — todo sin conexión.",
        "Clientes, facturas, proyectos, recibos, kilometraje, deducciones fiscales y tu libro Simple — todo sin conexión.",
    ),
    "Use {PREFIX}, {YEAR}, {SEQ}": (
        "Usa {PREFIX}, {YEAR}, {SEQ}",
        "Usa {PREFIX}, {YEAR}, {SEQ}",
    ),
    "Matching \\": ("Coincidencia \\", "Coincidencia \\"),
    "Exit": ("Salir", "Salir"),
    "Done": ("Listo", "Hecho"),
    "Mileage Log": ("Registro de millaje", "Registro de kilometraje"),
    "Open mileage log": ("Abrir registro de millaje", "Abrir registro de kilometraje"),
    "Add business mileage to include allowances in your deduction estimate.": (
        "Agrega millaje de negocio para incluir viáticos en tu estimación de deducciones.",
        "Añade kilometraje de negocio para incluir viáticos en tu estimación de deducciones.",
    ),
    "Add mileage entry": ("Agregar entrada de millaje", "Añadir entrada de kilometraje"),
    "Log same trip back": ("Registrar el mismo viaje de vuelta", "Registrar el mismo viaje de vuelta"),
    "Same trip back": ("Mismo viaje de vuelta", "Mismo viaje de vuelta"),
    "There and back": ("Ida y vuelta", "Ida y vuelta"),
    "My money": ("Mi dinero", "Mi dinero"),
    "Tap to open My money": ("Toca para abrir Mi dinero", "Toca para abrir Mi dinero"),
    "Scope Radar": ("Scope Radar", "Scope Radar"),
    "SCOPE RADAR": ("SCOPE RADAR", "SCOPE RADAR"),
    "Pro Studio": ("Pro Studio", "Pro Studio"),
    "Business Card Studio": ("Business Card Studio", "Business Card Studio"),
    "Upgrade to Pro Studio": ("Actualizar a Pro Studio", "Actualizar a Pro Studio"),
    "Scan Receipt": ("Escanear recibo", "Escanear ticket"),
    "Scan receipt": ("Escanear recibo", "Escanear ticket"),
    "Receipt Scanner": ("Escáner de recibos", "Escáner de tickets"),
    "Receipts": ("Recibos", "Recibos"),
    "Settings": ("Ajustes", "Ajustes"),
    "Region & currency": ("Región y moneda", "Región y moneda"),
    "Amount": ("Monto", "Importe"),
    "Amount due": ("Monto adeudado", "Importe adeudado"),
    "Snap": ("Ajustar", "Ajustar"),
}


def should_skip(key: str) -> bool:
    if r"\(" in key:
        return True
    if re.fullmatch(r"[A-Za-z]{1,2}", key):
        return True
    if re.fullmatch(r"[^A-Za-z0-9]+", key):
        return True
    return False


def protect_terms(text: str) -> tuple[str, list[tuple[str, str]]]:
    replacements = []
    out = text
    for i, term in enumerate(sorted(KEEP_EN, key=len, reverse=True)):
        if term in out:
            ph = f"⟦{i}⟧"
            replacements.append((ph, term))
            out = out.replace(term, ph)
    return out, replacements


def restore_terms(text: str, replacements: list[tuple[str, str]]) -> str:
    for ph, term in replacements:
        text = text.replace(ph, term)
    return text


def to_es419(base: str) -> str:
    t = base
    # Latin America preferences
    t = re.sub(r"\busted\b", "tú", t, flags=re.I)
    t = re.sub(r"\bordenador\b", "computadora", t, flags=re.I)
    t = re.sub(r"\bmóvil\b", "celular", t, flags=re.I)
    t = re.sub(r"\bimporte\b", "monto", t, flags=re.I)
    t = re.sub(r"\bkilometraje\b", "millaje", t, flags=re.I)
    t = re.sub(r"\bKilometraje\b", "Millaje", t)
    t = re.sub(r"\bañadir\b", "agregar", t, flags=re.I)
    t = re.sub(r"\bAñadir\b", "Agregar", t)
    t = re.sub(r"\bañade\b", "agrega", t, flags=re.I)
    t = re.sub(r"\bAñade\b", "Agrega", t)
    t = re.sub(r"\bhecho\b", "listo", t, flags=re.I)  # Done button context
    t = re.sub(r"\bHecho\b", "Listo", t)
    return t


def to_es_es(base: str) -> str:
    t = base
    t = re.sub(r"\bcomputadora\b", "ordenador", t, flags=re.I)
    t = re.sub(r"\bComputadora\b", "Ordenador", t)
    t = re.sub(r"\bcelular\b", "móvil", t, flags=re.I)
    t = re.sub(r"\bCelular\b", "Móvil", t)
    t = re.sub(r"\bteléfono\b", "móvil", t, flags=re.I)  # only in some UI - careful
    t = re.sub(r"\bmonto\b", "importe", t, flags=re.I)
    t = re.sub(r"\bMonto\b", "Importe", t)
    t = re.sub(r"\bmillaje\b", "kilometraje", t, flags=re.I)
    t = re.sub(r"\bMillaje\b", "Kilometraje", t)
    t = re.sub(r"\bagregar\b", "añadir", t, flags=re.I)
    t = re.sub(r"\bAgregar\b", "Añadir", t)
    t = re.sub(r"\bagrega\b", "añade", t, flags=re.I)
    t = re.sub(r"\bAgrega\b", "Añade", t)
    t = re.sub(r"\blisto\b", "hecho", t, flags=re.I)  # Done
    t = re.sub(r"\bListo\b", "Hecho", t)
    # Receipt scan wording
    if "escanear recibo" in t.lower() and "ticket" not in t.lower():
        t = re.sub(r"escanear recibo", "escanear ticket", t, flags=re.I)
        t = re.sub(r"Escanear recibo", "Escanear ticket", t)
    if "escáner de recibos" in t.lower():
        t = t.replace("escáner de recibos", "escáner de tickets").replace(
            "Escáner de recibos", "Escáner de tickets"
        )
    return t


def translate_batch(keys: list[str]) -> dict[str, dict[str, str]]:
    from deep_translator import GoogleTranslator

    tr = GoogleTranslator(source="en", target="es")
    out: dict[str, dict[str, str]] = {}
    for i, key in enumerate(keys):
        if key in MANUAL:
            a, e = MANUAL[key]
            out[key] = {"es-419": a, "es-ES": e}
            continue
        protected, reps = protect_terms(key)
        try:
            raw = tr.translate(protected)
        except Exception:
            time.sleep(1.5)
            raw = tr.translate(protected)
        raw = restore_terms(raw, reps)
        # Preserve placeholders and symbols from source
        for ph in re.findall(r"\{[A-Z_]+\}|[%@]|\%lld", key):
            if ph not in raw and ph in key:
                pass  # translator usually keeps them
        es419 = to_es419(raw)
        es_es = to_es_es(raw)
        # Fix arrow paths Studio
        for label in ("Studio", "Bux Canvas", "BuxMuse", "Card Studio", "Simple Studio", "Pro Studio"):
            es419 = es419.replace(label.lower(), label) if label == "Studio" else es419
        out[key] = {"es-419": es419, "es-ES": es_es}
        if (i + 1) % 25 == 0:
            print(f"  translated {i+1}/{len(keys)}", flush=True)
            time.sleep(0.3)
    return out


def main():
    with KEYS_FILE.open() as f:
        keys = [line.strip() for line in f if line.strip()]
    with PHASE1_FILE.open() as f:
        phase1 = json.load(f)
    partial = {}
    if PARTIAL_FILE.exists():
        with PARTIAL_FILE.open() as f:
            partial = json.load(f)

    eligible = [k for k in keys if not should_skip(k)]
    need_mt = [k for k in eligible if k not in phase1 and k not in partial and k not in MANUAL]

    print(f"Eligible: {len(eligible)}, phase1 reuse, partial, MT: {len(need_mt)}")
    mt = translate_batch(need_mt) if need_mt else {}

    result = {}
    for key in eligible:
        if key in phase1:
            entry = {k: phase1[key][k] for k in ("es-419", "es-ES") if k in phase1[key]}
        elif key in MANUAL:
            entry = {"es-419": MANUAL[key][0], "es-ES": MANUAL[key][1]}
        elif key in partial and key in eligible:
            entry = {k: partial[key][k] for k in ("es-419", "es-ES") if k in partial[key]}
        elif key in mt:
            entry = mt[key]
        else:
            raise RuntimeError(f"Missing translation for: {key}")
        result[key] = entry

    with OUT_FILE.open("w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"Wrote {len(result)} entries -> {OUT_FILE}")


if __name__ == "__main__":
    main()
