import json

with open("BuxMuse/Localizable.xcstrings", "r") as f:
    data = json.load(f)

strings = data.get("strings", {})

checks = [
    "You agreed %@ for this job. Even if you only work %@, they still owe the full agreed price.",
    "You agreed %@. Time logged is for your records — it does not reduce or increase the price.",
    "You agreed %@ for the whole job. Use the clock to remember how long you spent.",
    "Save time on this job (price stays %@)",
    "At %@ per hour, %@ of work = %@.",
    "(Your ballpark quote was %@ — check with the customer if hours ran over.)",
    "Ballpark quote was %@.",
    "This session adds about %@.",
    "Save %@ (~%@)",
    "%d h %d m",
    "%lld h %lld m",
    "%ld h %ld m",
    "%ld h",
    "%ld m",
    "0 m"
]

print("FORMAT KEYS CHECK:")
for c in checks:
    if c in strings:
        print(f"  [FOUND] {repr(c)}")
        loc = strings[c].get("localizations", {})
        es = loc.get("es", {}).get("stringUnit", {}).get("value")
        print(f"          -> Spanish: {repr(es)}")
    else:
        print(f"  [MISSING] {repr(c)}")
