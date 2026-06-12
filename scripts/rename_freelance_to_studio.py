#!/usr/bin/env python3
"""One-shot Freelance → Studio rename for BuxMuse Swift sources."""
from __future__ import annotations
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGETS = [
    ROOT / "BuxMuse",
    ROOT / "BuxMuseTests",
]

# Longest-first token replacements (identifiers / types / properties)
REPLACEMENTS = [
    ("FreelanceHubDisplay", "StudioHubDisplay"),
    ("FreelanceInvoiceSettings", "StudioInvoiceSettings"),
    ("FreelanceInvoiceMaintenance", "StudioInvoiceMaintenance"),
    ("FreelanceInvoiceLineItem", "StudioInvoiceLineItem"),
    ("FreelanceTaxProfileEditorView", "StudioTaxProfileEditorView"),
    ("FreelanceTaxReferenceCardModifier", "StudioTaxReferenceCardModifier"),
    ("FreelanceTaxReferenceView", "StudioTaxReferenceView"),
    ("FreelanceTaxOverviewView", "StudioTaxOverviewView"),
    ("FreelanceTaxProfile", "StudioTaxProfile"),
    ("FreelanceTaxEngine", "StudioTaxEngine"),
    ("FreelanceTaxDisplay", "StudioTaxDisplay"),
    ("FreelanceTaxSection", "StudioTaxSection"),
    ("FreelanceIncomeTaxEngine", "StudioIncomeTaxEngine"),
    ("FreelanceDeductionEngine", "StudioDeductionEngine"),
    ("FreelanceDeductionMath", "StudioDeductionMath"),
    ("FreelanceDeductionDisplay", "StudioDeductionDisplay"),
    ("FreelanceDeductionsSnapshotDisplay", "StudioDeductionsSnapshotDisplay"),
    ("FreelanceDeductionsView", "StudioDeductionsView"),
    ("FreelanceCashflowEngine", "StudioCashflowEngine"),
    ("FreelanceCashflowDisplay", "StudioCashflowDisplay"),
    ("FreelanceCashflowView", "StudioCashflowView"),
    ("FreelanceCashflowSection", "StudioCashflowSection"),
    ("FreelanceDashboardWidget", "StudioDashboardWidget"),
    ("FreelanceClientEngine", "StudioClientEngine"),
    ("FreelanceInvoiceEngine", "StudioInvoiceEngine"),
    ("FreelanceProjectEngine", "StudioProjectEngine"),
    ("FreelanceReceiptEngine", "StudioReceiptEngine"),
    ("FreelanceInvoicePDFRenderer", "StudioInvoicePDFRenderer"),
    ("FreelanceHeroDisplay", "StudioHeroDisplay"),
    ("FreelanceHeroCard", "StudioHeroCard"),
    ("FreelanceHubEmptyState", "StudioHubEmptyState"),
    ("FreelanceHubView", "StudioHubView"),
    ("FreelanceHubSections", "StudioHubSections"),
    ("FreelanceAlertDisplay", "StudioAlertDisplay"),
    ("FreelanceAlertsSection", "StudioAlertsSection"),
    ("FreelanceInvoiceSummaryDisplay", "StudioInvoiceSummaryDisplay"),
    ("FreelanceInvoicesSection", "StudioInvoicesSection"),
    ("FreelanceClientDisplay", "StudioClientDisplay"),
    ("FreelanceClientsSection", "StudioClientsSection"),
    ("FreelanceProjectsDisplay", "StudioProjectsDisplay"),
    ("FreelanceProjectsSection", "StudioProjectsSection"),
    ("FreelanceReceiptsDisplay", "StudioReceiptsDisplay"),
    ("FreelanceReceiptsSection", "StudioReceiptsSection"),
    ("FreelanceDeductionsSection", "StudioDeductionsSection"),
    ("FreelanceMetricsGrid", "StudioMetricsGrid"),
    ("FreelanceSectionShell", "StudioSectionShell"),
    ("FreelanceInvoicesListView", "StudioInvoicesListView"),
    ("FreelanceClientsListView", "StudioClientsListView"),
    ("FreelanceProjectsListView", "StudioProjectsListView"),
    ("FreelanceReceiptsListView", "StudioReceiptsListView"),
    ("FreelanceInvoiceEditorView", "StudioInvoiceEditorView"),
    ("FreelanceInvoiceViews", "StudioInvoiceViews"),
    ("FreelanceClientViews", "StudioClientViews"),
    ("FreelanceProjectViews", "StudioProjectViews"),
    ("FreelanceReceiptViews", "StudioReceiptViews"),
    ("FreelanceProfileView", "StudioProfileView"),
    ("FreelanceExpenseEditorView", "StudioExpenseEditorView"),
    ("FreelanceInvoiceSettingsView", "StudioInvoiceSettingsView"),
    ("FreelanceSEModuleViews", "StudioSEModuleViews"),
    ("FreelanceTaxAndCashflowViews", "StudioTaxAndCashflowViews"),
    ("FreelanceHubSections", "StudioHubSections"),
    ("FreelanceComplianceAssistantView", "StudioComplianceAssistantView"),
    ("FreelanceIncomeTaxCalculatorView", "StudioIncomeTaxCalculatorView"),
    ("FreelanceQuarterlyTaxView", "StudioQuarterlyTaxView"),
    ("FreelanceSettingsView", "StudioSettingsView"),
    ("FreelanceBrain", "StudioBrain"),
    ("FreelanceStore", "StudioStore"),
    ("FreelanceSnapshot", "StudioSnapshot"),
    ("FreelanceProfile", "StudioProfile"),
    ("FreelanceClient", "StudioClient"),
    ("FreelanceInvoice", "StudioInvoice"),
    ("FreelanceProject", "StudioProject"),
    ("FreelanceReceipt", "StudioReceipt"),
    ("FreelanceEngines", "StudioEngines"),
    ("FreelanceSEEngines", "StudioSEEngines"),
    ("FreelanceModels", "StudioModels"),
    ("FreelanceDisplays", "StudioDisplays"),
    ("freelanceInvoiceRemindersEnabled", "studioInvoiceRemindersEnabled"),
    ("includeFreelanceDataInExports", "includeStudioDataInExports"),
    ("freelanceProfileId", "studioProfileId"),
    ("freelanceEnabled", "studioEnabled"),
    ("freelanceStore", "studioStore"),
    ("freelanceBrain", "studioBrain"),
    ("freelanceAlerts", "studioAlerts"),
    ("freelanceInvoices", "studioInvoices"),
    ("freelance_hub_v1", "studio_hub_v1"),
    ("freelance_hub", "studio_hub"),
    ("freelance_locale_migrated", "studio_locale_migrated"),
    ("FreelanceHub", "Studio"),
    ("freelanceEnabled", "studioEnabled"),  # idempotent safety
]

FILENAME_REPLACEMENTS = [
    ("Freelance", "Studio"),
]


def patch_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    original = text
    for old, new in REPLACEMENTS:
        text = text.replace(old, new)
    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> None:
    changed = 0
    for base in TARGETS:
        if not base.exists():
            continue
        for path in base.rglob("*.swift"):
            if patch_file(path):
                changed += 1
                print(f"patched {path.relative_to(ROOT)}")
    print(f"Done. {changed} files patched.")


if __name__ == "__main__":
    main()
