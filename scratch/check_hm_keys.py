import json

with open("BuxMuse/Localizable.xcstrings", "r") as f:
    data = json.load(f)

strings = data.get("strings", {})

checks = [
    "%lld h",
    "%lld m",
    "%d h",
    "%d m",
    "%ld h",
    "%ld m",
    "%lld h %lld m",
    "%d h %d m",
    "%ld h %ld m"
]

for c in checks:
    if c in strings:
        print(f"FOUND: {repr(c)}")
        loc = strings[c].get("localizations", {})
        es = loc.get("es", {}).get("stringUnit", {}).get("value")
        print(f"  -> Spanish: {repr(es)}")
    else:
        print(f"MISSING: {repr(c)}")
