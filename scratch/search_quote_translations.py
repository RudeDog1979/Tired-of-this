import json

with open("BuxMuse/Localizable.xcstrings", "r") as f:
    data = json.load(f)

strings = data.get("strings", {})

for key in strings:
    if "Quote for" in key or "quote" in key.lower():
        print(f"Key: {repr(key)}")
        loc = strings[key].get("localizations", {})
        es = loc.get("es", {}).get("stringUnit", {}).get("value")
        print(f"  -> Spanish: {repr(es)}")
