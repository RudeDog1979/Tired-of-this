import json

with open("BuxMuse/Localizable.xcstrings", "r") as f:
    data = json.load(f)

strings = data.get("strings", {})

new_translations = {
    "Indirect tax status": {
        "es": "Estado tributario indirecto",
        "es-419": "Estado tributario indirecto",
        "es-ES": "Estado tributario indirecto"
    },
    "Tax payment schedule": {
        "es": "Calendario de pago de impuestos",
        "es-419": "Calendario de pago de impuestos",
        "es-ES": "Calendario de pago de impuestos"
    },
    "Suggested tax preset": {
        "es": "Preajuste de impuestos sugeridos",
        "es-419": "Preajuste de impuestos sugeridos",
        "es-ES": "Preajuste de impuestos sugeridos"
    },
    "How you earn": {
        "es": "Cómo gana",
        "es-419": "Cómo gana",
        "es-ES": "Cómo gana"
    },
    "Your tax rules": {
        "es": "Sus normas tributarias",
        "es-419": "Sus normas tributarias",
        "es-ES": "Sus normas tributarias"
    },
    "Effective tax rates (for calculator)": {
        "es": "Tasas de impuesto efectivas (para calculadora)",
        "es-419": "Tasas de impuesto efectivas (para calculadora)",
        "es-ES": "Tasas de impuesto efectivas (para calculadora)"
    },
    "Income tax rate %": {
        "es": "Tasa de impuesto sobre la renta %",
        "es-419": "Tasa de impuesto sobre la renta %",
        "es-ES": "Tasa de impuesto sobre la renta %"
    },
    "Self-employed tax rate %": {
        "es": "Tasa de impuesto para autónomos %",
        "es-419": "Tasa de impuesto para autónomos %",
        "es-ES": "Tasa de impuesto para autónomos %"
    },
    "Indirect tax rate % (VAT/GST)": {
        "es": "% de tipo de impuesto indirecto (VAT/GST)",
        "es-419": "% de tipo de impuesto indirecto (VAT/GST)",
        "es-ES": "% de tipo de impuesto indirecto (VAT/GST)"
    }
}

for key, translations in new_translations.items():
    strings[key] = {
        "extractionState": "manual",
        "localizations": {
            lang: {
                "stringUnit": {
                    "state": "translated",
                    "value": val
                }
            }
            for lang, val in translations.items()
        }
    }

data["strings"] = strings

with open("BuxMuse/Localizable.xcstrings", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("Added new sentence-case tax keys to BuxMuse/Localizable.xcstrings successfully!")
