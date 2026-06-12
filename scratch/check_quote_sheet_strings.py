import json

with open("BuxMuse/Localizable.xcstrings", "r") as f:
    data = json.load(f)

strings = data.get("strings", {})

candidates = [
    # Payment status / styles
    "Still waiting", "Partially paid", "Paid in full",
    # Section titles
    "Customer", "Job", "How do you get paid?", "How long should it take?", "Payment status", "Advance", "What you spent", "Note",
    # TextFields and cost rows
    "Name", "Phone / WhatsApp", "What is the work?", "Pay type", "Full price you agreed", "Your rate per hour", "Ballpark total (optional)",
    "Set a time for this job", "Lock Screen shows a walker moving toward done — clock can stop when time is up.",
    "Hours", "Minutes", "Stop the clock when time is up", "Example: agreed 2 hours at your hourly rate — set 2 h here and the clock pauses at 2 h.",
    "Paid so far", "Advance for materials", "Materials purchased", "Petrol / gas", "Transport", "Platform fee", "Optional",
    # Job math card
    "Job math", "Agreed with customer", "Spent on job", "You keep (so far)", "You'll keep (when paid)",
    # Actions
    "Send quote", "Save job", "Update job", "Quote job", "Edit job",
    # Quote card
    "Job Quote", "QUOTE", "For", "Agreed price", "Sent via BuxMuse · Not a bank"
]

print("CANDIDATE LOCALIZATION AUDIT:")
for c in candidates:
    if c in strings:
        print(f"  [FOUND] {repr(c)}")
        # Print Spanish translation if exists
        loc = strings[c].get("localizations", {})
        es = loc.get("es", {}).get("stringUnit", {}).get("value")
        print(f"          -> Spanish: {repr(es)}")
    else:
        print(f"  [MISSING] {repr(c)}")
