import json

with open("BuxMuse/Localizable.xcstrings", "r") as f:
    data = json.load(f)

strings = data.get("strings", {})

checks = [
    "Quote for %@: %@ total",
    "Quote for %@: %@ per hour",
    "Quote for %@: %@",
    "Quote for %1$@: %2$@ total",
    "Quote for %1$@: %2$@ per hour",
    "Quote for %1$@: %2$@"
]

for c in checks:
    if c in strings:
        print(f"FOUND: {repr(c)}")
        loc = strings[c].get("localizations", {})
        es = loc.get("es", {}).get("stringUnit", {}).get("value")
        print(f"  -> Spanish: {repr(es)}")
    else:
        print(f"MISSING: {repr(c)}")
