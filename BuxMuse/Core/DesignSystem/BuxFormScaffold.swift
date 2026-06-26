//
//  BuxFormScaffold.swift
//  BuxMuse
//
//  Themed grouped Form chrome — M3 card rows when brand themes are on.
//

import SwiftUI

// MARK: - Settings Context Environment Key

private struct IsSettingsContextKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isSettingsContext: Bool {
        get { self[IsSettingsContextKey.self] }
        set { self[IsSettingsContextKey.self] = newValue }
    }
}

// MARK: - Form scaffold backdrop


struct BuxFormScaffold<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .buxThemedPresentation()
    }
}

extension View {
    /// Grouped Form — themed card rows when brand themes are on; Apple neutral when off.
    func buxThemedFormStyle() -> some View {
        modifier(BuxThemedFormStyleModifier())
    }

    /// Alias for settings / sheet forms.
    func buxSystemFormStyle() -> some View {
        buxThemedFormStyle()
    }

    /// Themed fill + outline for TextField / TextEditor plates outside Form rows.
    func buxThemedInputPlate(cornerRadius: CGFloat = BuxMaterialShape.small) -> some View {
        modifier(BuxThemedInputPlateModifier(cornerRadius: cornerRadius))
    }
}

private struct BuxThemedInputPlateModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(themeManager.inputFieldFill(for: colorScheme))
                    .overlay {
                        if settings.brandThemesEnabled {
                            shape.strokeBorder(
                                themeManager.themedCardStroke(for: colorScheme),
                                lineWidth: 0.5
                            )
                        }
                    }
            }
    }
}

private struct BuxThemedFormStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.settingsEnhancedTint) private var settingsEnhancedTint
    @Environment(\.expensesEnhancedTint) private var expensesEnhancedTint
    @Environment(\.studioEnhancedTint) private var studioEnhancedTint
    @ObservedObject private var settings = SettingsStore.shared

    private var usesEnhancedLayout: Bool {
        settingsEnhancedTint || expensesEnhancedTint || studioEnhancedTint
    }

    private var usesThemedGroupedRows: Bool {
        settings.brandThemesEnabled
    }

    func body(content: Content) -> some View {
        if usesThemedGroupedRows {
            content
                .scrollContentBackground(.hidden)
                .buxScrollDismissesKeyboard()
                .listSectionSpacing(BuxLayout.section)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .listRowBackground(themedFormRowBackground)
                .listRowSeparatorTint(themeManager.themedCardStroke(for: colorScheme))
                .modifier(BuxFormListMarginsModifier(enabled: usesEnhancedLayout))
        } else if usesEnhancedLayout {
            content
                .scrollContentBackground(.hidden)
                .buxScrollDismissesKeyboard()
                .buxListContentMargins()
        } else {
            content
                .scrollContentBackground(.hidden)
                .buxScrollDismissesKeyboard()
        }
    }

    private var themedFormRowBackground: some View {
        RoundedRectangle(cornerRadius: BuxLayout.cornerGrouped, style: .continuous)
            .fill(themeManager.cardFill(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: BuxLayout.cornerGrouped, style: .continuous)
                    .strokeBorder(themeManager.themedCardStroke(for: colorScheme), lineWidth: 0.5)
            )
    }
}

private struct BuxFormListMarginsModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.buxListContentMargins()
        } else {
            content
        }
    }
}

// MARK: - Card sheet form (Add Expense pattern — replaces grouped Form white slabs)

struct BuxFormSectionLabel: View {
    let title: String
    @Environment(\.isSettingsContext) private var isSettingsContext

    var body: some View {
        BuxCatalogText.text(title)
            .font(.footnote.weight(.semibold))
            .textCase(nil)
            .buxLabelSecondary()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BuxFormRowDivider: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Divider()
            .overlay(themeManager.themedCardStroke(for: colorScheme).opacity(0.55))
            .padding(.leading, BuxLayout.section)
    }
}

struct BuxThemedCardForm<Content: View>: View {
    @Environment(\.studioEnhancedTint) private var studioEnhancedTint
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: BuxLayout.section) {
                content()
            }
            .buxScreenContentMargins()
            .padding(.top, studioEnhancedTint ? 0 : BuxLayout.tight)
            .padding(.bottom, 32)
        }
        .buxSettingsDrillInChrome()
        .scrollDismissesKeyboard(.interactively)
    }
}

struct BuxFormSection<Content: View>: View {
    let title: String?
    @ViewBuilder var content: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            if let title {
                BuxFormSectionLabel(title: title)
            }
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .buxFormSectionCard()
        }
    }
}

extension View {
    /// Inset for a row inside a themed form card.
    func buxFormFieldPadding() -> some View {
        padding(.horizontal, BuxLayout.section)
            .padding(.vertical, 12)
    }

    /// M3 outlined card — use instead of grouped Form sections.
    func buxFormSectionCard(cornerRadius: CGFloat = 20) -> some View {
        buxThemedCardChrome(cornerRadius: cornerRadius)
    }
}
