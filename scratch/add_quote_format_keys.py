import json

with open("BuxMuse/Localizable.xcstrings", "r") as f:
    data = json.load(f)

strings = data.get("strings", {})

new_keys = {
    "Quote for %@: %@ total": {
        "es": "Presupuesto para %@: %@ en total",
        "es-419": "Presupuesto para %@: %@ en total",
        "es-ES": "Presupuesto para %@: %@ en total"
    },
    "Quote for %@: %@ per hour": {
        "es": "Presupuesto para %@: %@ por hora",
        "es-419": "Presupuesto para %@: %@ por hora",
        "es-ES": "Presupuesto para %@: %@ por hora"
    },
    "Quote for %@: %@": {
        "es": "Presupuesto para %@: %@",
        "es-419": "Presupuesto para %@: %@",
        "es-ES": "Presupuesto para %@: %@"
    }
}

for key, translations in new_keys.items():
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

print("Successfully added new format keys to BuxMuse/Localizable.xcstrings!")
