import json

with open("BuxMuse/Localizable.xcstrings", "r") as f:
    data = json.load(f)

strings = data.get("strings", {})
malformed = []
for key in strings:
    if "\\(" in key or "\\\\" in key or "%(" in key:
        malformed.append(key)

print(f"Found {len(malformed)} malformed interpolation keys:")
for k in malformed:
    print(f"  {repr(k)}")
