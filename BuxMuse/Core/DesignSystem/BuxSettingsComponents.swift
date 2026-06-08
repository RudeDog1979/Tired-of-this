//
//  BuxSettingsComponents.swift
//  BuxMuse
//
//  Premium settings row primitives — layout only; bindings unchanged.
//  iOS 26 first, iOS 18 fallback via BuxLayout width gates.
//

import SwiftUI

// MARK: - Compact layout gate

private struct BuxSettingsUsesStackedRowsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// When true, picker/toggle rows stack vertically (narrow width).
    var buxSettingsUsesStackedRows: Bool {
        get { self[BuxSettingsUsesStackedRowsKey.self] }
        set { self[BuxSettingsUsesStackedRowsKey.self] = newValue }
    }
}

private struct BuxSettingsStackedRowsModifier: ViewModifier {
    @State private var usesStackedRows = false

    func body(content: Content) -> some View {
        content
            .environment(\.buxSettingsUsesStackedRows, usesStackedRows)
            .buxReportsContainerWidth()
            .onPreferenceChange(BuxContainerWidthKey.self) { width in
                guard width > 0 else { return }
                let stacked = width < BuxLayout.compactWidthThreshold + 24
                if stacked != usesStackedRows { usesStackedRows = stacked }
            }
    }
}

extension View {
    /// Adaptive stacked vs inline rows for settings drill-ins.
    func buxSettingsAdaptiveRows() -> some View {
        modifier(BuxSettingsStackedRowsModifier())
    }

    /// Standard navigation + scroll chrome for settings sub-screens.
    func buxSettingsDrillInChrome() -> some View {
        buxSettingsAdaptiveRows()
            .buxDetailScrollChrome()
    }
}

// MARK: - Toggle row

struct BuxSettingsToggleRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buxSettingsUsesStackedRows) private var usesStackedRows
    @EnvironmentObject private var themeManager: ThemeManager

    let titleKey: String
    var subtitleKey: String? = nil
    /// Pre-localized subtitle when copy depends on runtime state (e.g. brand themes on/off).
    var subtitleText: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Group {
            if usesStackedRows, subtitleKey != nil || subtitleText != nil {
                VStack(alignment: .leading, spacing: 10) {
                    labelBlock
                    Toggle("", isOn: $isOn)
                        .labelsHidden()
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                }
            } else {
                Toggle(isOn: $isOn) {
                    labelBlock
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .tint(themeManager.contrastAccentColor(for: colorScheme))
            }
        }
        .buxFormFieldPadding()
    }

    private var labelBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            BuxCatalogDynamicText(key: titleKey)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

            if let subtitleKey {
                BuxCatalogDynamicText(key: subtitleKey)
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            } else if let subtitleText {
                Text(subtitleText)
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
        }
    }
}

// MARK: - Menu picker row

struct BuxSettingsMenuPickerRow<Selection: Hashable, Options: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buxSettingsUsesStackedRows) private var usesStackedRows
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let titleKey: String
    @Binding var selection: Selection
    @ViewBuilder var options: () -> Options

    var body: some View {
        Group {
            if usesStackedRows {
                VStack(alignment: .leading, spacing: 10) {
                    BuxCatalogDynamicText(key: titleKey)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    picker
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    BuxCatalogDynamicText(key: titleKey)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    Spacer(minLength: 8)

                    picker
                }
            }
        }
        .buxFormFieldPadding()
    }

    private var picker: some View {
        Picker(selection: $selection) {
            options()
        } label: {
            Text(BuxCatalogLabel.string(titleKey, locale: appSettingsManager.interfaceLocale))
        }
        .pickerStyle(.menu)
        .tint(themeManager.contrastAccentColor(for: colorScheme))
    }
}

// MARK: - Segmented enum row (menu fallback on narrow screens)

struct BuxSettingsSegmentedEnumRow<Selection: Hashable, Options: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buxSettingsUsesStackedRows) private var usesStackedRows
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let titleKey: String
    @Binding var selection: Selection
    @ViewBuilder var options: () -> Options

    var body: some View {
        Group {
            if usesStackedRows {
                VStack(alignment: .leading, spacing: 10) {
                    BuxCatalogDynamicText(key: titleKey)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Picker(selection: $selection) {
                        options()
                    } label: {
                        Text(BuxCatalogLabel.string(titleKey, locale: appSettingsManager.interfaceLocale))
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buxFormFieldPadding()
            } else {
                Picker(selection: $selection) {
                    options()
                } label: {
                    Text(BuxCatalogLabel.string(titleKey, locale: appSettingsManager.interfaceLocale))
                }
                .buxThemedSegmentedPicker()
                .buxFormFieldPadding()
            }
        }
    }
}

// MARK: - Helper copy block

struct BuxSettingsFootnote: View {
    let key: String

    var body: some View {
        BuxCatalogDynamicText(key: key)
            .font(.system(size: 12, weight: .medium))
            .buxLabelSecondary()
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .buxFormFieldPadding()
    }
}

// MARK: - Adaptive label + value row (e.g. amount fields)

struct BuxSettingsLabeledValueRow<Label: View, Value: View>: View {
    @Environment(\.buxSettingsUsesStackedRows) private var usesStackedRows

    @ViewBuilder var label: () -> Label
    @ViewBuilder var value: () -> Value

    var body: some View {
        Group {
            if usesStackedRows {
                VStack(alignment: .leading, spacing: 10) {
                    label()
                    value()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    label()
                        .layoutPriority(1)
                    Spacer(minLength: 8)
                    value()
                }
            }
        }
        .buxFormFieldPadding()
    }
}
