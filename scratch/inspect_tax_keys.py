import json

with open("BuxMuse/Localizable.xcstrings", "r") as f:
    data = json.load(f)

keys = [
    "INDIRECT TAX STATUS",
    "TAX PAYMENT SCHEDULE",
    "SUGGESTED TAX PRESET",
    "HOW YOU EARN",
    "YOUR TAX RULES",
    "EFFECTIVE TAX RATES (FOR CALCULATOR)",
    "INCOME TAX RATE %",
    "SELF-EMPLOYED TAX RATE %",
    "INDIRECT TAX RATE % (VAT/GST)"
]

strings = data.get("strings", {})
for k in keys:
    if k in strings:
        print(f"Key: {k}")
        print(json.dumps(strings[k], indent=2, ensure_ascii=False))
    else:
        print(f"Key NOT found: {k}")
