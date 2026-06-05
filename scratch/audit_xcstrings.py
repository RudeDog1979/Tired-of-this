import json

with open("BuxMuse/Localizable.xcstrings", "r") as f:
    data = json.load(f)

strings = data.get("strings", {})
print(f"Total keys: {len(strings)}")

uppercase_keys = []
for key, val in strings.items():
    # Check if the key itself is uppercase (ignoring numbers, symbols, spaces)
    letters_in_key = [c for c in key if c.isalpha()]
    if letters_in_key and all(c.isupper() for c in letters_in_key):
        uppercase_keys.append((key, "KEY_ALL_CAPS"))
        continue
    
    # Check if English value (which defaults to key if no localizations/en or is explicitly defined)
    # Xcode string catalogs: if there is a localizations dict, check if "en" exists.
    # Otherwise, the key itself is the English source string.
    en_val = key
    localizations = val.get("localizations", {})
    if "en" in localizations:
        unit = localizations["en"].get("stringUnit", {})
        if unit:
            en_val = unit.get("value", key)
            
    letters_in_val = [c for c in en_val if c.isalpha()]
    if len(letters_in_val) >= 3 and all(c.isupper() for c in letters_in_val):
        uppercase_keys.append((key, en_val))

print(f"Found {len(uppercase_keys)} keys with all-uppercase keys or values:")
for key, en_val in sorted(uppercase_keys):
    print(f"  Key: {repr(key)} -> Value: {repr(en_val)}")
