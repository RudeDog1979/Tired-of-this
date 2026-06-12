import os
import re

directory = "BuxMuse/Features/Settings/Views/"
files = [os.path.join(directory, f) for f in os.listdir(directory) if f.endswith(".swift")]
# Also include StudioTaxReferenceView.swift because it is shown in Settings
files.append("BuxMuse/Features/Studio/Views/StudioTaxReferenceView.swift")

for filepath in files:
    with open(filepath, "r") as f:
        content = f.read()
    
    # Search for hardcoded all-uppercase strings in quotes (at least 3 characters)
    matches_str = re.findall(r'"([A-Z\s\d&%()/\-·\.,:;?!+]{3,})"', content)
    # Search for .uppercased()
    matches_uppercased = re.findall(r'(\w+\.uppercased\(\))', content)
    
    if matches_str or matches_uppercased:
        print(f"File: {filepath}")
        if matches_str:
            print(f"  All-cap strings: {matches_str}")
        if matches_uppercased:
            print(f"  Uppercased: {matches_uppercased}")
