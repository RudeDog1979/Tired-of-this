//
//  SettingsView.swift
//  BuxMuse
//
//  Features/Settings/
//
//  Unified premium Settings Cockpit managing identity, budgets, security, and data.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared

    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }
    
    var cardColor: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {

                        // Premium Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Settings")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                            
                            // User display name welcome message
                            Text(store.userDisplayName != nil ? "Welcome, \(store.userDisplayName!)" : "Personalize your BuxMuse experience")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : Color(red: 140/255, green: 145/255, blue: 160/255))
                        }
                        .padding(.top, 24)

                        // Generate layout dynamically from SettingsBrain display structs
                        let display = SettingsBrain.generateOverview(
                            store: store,
                            currentThemeName: themeManager.current.name,
                            activeCurrencyCode: appSettingsManager.selectedCurrency.id,
                            activeCurrencyFlag: appSettingsManager.selectedCurrency.flag
                        )
                        
                        ForEach(display.sections) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(section.title)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : Color(red: 140/255, green: 145/255, blue: 160/255))
                                    .kerning(1.2)
                                    .padding(.leading, 4)

                                VStack(spacing: 0) {
                                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                                        NavigationLink(value: row.destination) {
                                            SettingsRow(
                                                icon: row.iconName,
                                                label: row.title,
                                                color: Color(hex: row.hexColor),
                                                trailingText: row.trailingText
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        
                                        if index < section.rows.count - 1 {
                                            Divider().opacity(0.08)
                                        }
                                    }
                                }
                                .background(cardColor)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                                )
                            }
                        }

                        Spacer(minLength: 80)
                    }
                    .buxScreenContentMargins()
                }
                .buxReportsContainerWidth()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationDestination(for: SettingsDestinationType.self) { destination in
                switch destination {
                case .profile:
                    ProfileSettingsView()
                case .appearance:
                    AppearanceSettingsView()
                case .regionCurrency:
                    RegionCurrencySettingsView()
                case .budgets:
                    BudgetSettingsView()
                case .freelance:
                    FreelanceSettingsView()
                case .notifications:
                    NotificationSettingsView()
                case .security:
                    SecuritySettingsView()
                case .data:
                    DataSettingsView()
                case .about:
                    AboutSettingsView()
                }
            }
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let label: String
    let color: Color
    var trailingText: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))

            Spacer()

            if let trailing = trailingText {
                Text(trailing)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.current.accentColor)
                    .padding(.trailing, 4)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : Color(red: 180/255, green: 185/255, blue: 196/255))
        }
        .padding(.horizontal, BuxLayout.section)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Appearance Theme Picker View (Bottom Sheet Grid Panel) - PRESERVED UNCHANGED

struct AppearanceThemePickerView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    var sheetBgColor: Color {
        colorScheme == .dark ? Color(red: 18/255, green: 19/255, blue: 24/255) : Color(red: 245/255, green: 247/255, blue: 250/255)
    }

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Appearance")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                    Text("Select a creative brand preset")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : Color(red: 140/255, green: 145/255, blue: 160/255))
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                            .frame(width: 32, height: 32)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                }
            }
            .padding(.horizontal, BuxLayout.marginHorizontal)
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AppTheme.all) { theme in
                        ThemeSwatchCard(theme: theme, isSelected: themeManager.current.id == theme.id) {
                            themeManager.select(theme)
                        }
                    }
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sheetBgColor.ignoresSafeArea())
    }
}

// MARK: - Theme Swatch Card (Grid card layout) - PRESERVED UNCHANGED

struct ThemeSwatchCard: View {
    @Environment(\.colorScheme) var colorScheme
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: theme.heroDarkGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: theme.accentColor.opacity(0.3), radius: 8, x: 0, y: 3)

                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 56, height: 56)

                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: theme.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.95))
                    }
                }

                Text(theme.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSelected
                        ? (colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                        : Color(red: 140/255, green: 145/255, blue: 160/255))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isSelected ? theme.accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(
                color: isSelected ? theme.accentColor.opacity(0.2) : Color.black.opacity(0.04),
                radius: isSelected ? 12 : 6,
                x: 0, y: 4
            )
        }
        .buttonStyle(BuxMicroShrinkStyle())
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.buxBounce, value: isSelected)
    }
}

// MARK: - Currency Region Picker View (Frosted glass sheet selector) - PRESERVED UNCHANGED

struct CurrencyRegionPickerView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""

    var sheetBgColor: Color {
        colorScheme == .dark ? Color(red: 18/255, green: 19/255, blue: 24/255) : Color(red: 245/255, green: 247/255, blue: 250/255)
    }
    
    var filteredCurrencies: [CurrencySetting] {
        if searchText.isEmpty {
            return AppSettingsManager.availableCurrencies
        } else {
            let lowerQuery = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return AppSettingsManager.availableCurrencies.filter {
                $0.name.lowercased().contains(lowerQuery) ||
                $0.id.lowercased().contains(lowerQuery) ||
                $0.symbol.contains(lowerQuery)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Currency & Region")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                    Text("Choose your preferred regional formatting")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : Color(red: 140/255, green: 145/255, blue: 160/255))
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                            .frame(width: 32, height: 32)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                }
            }
            .padding(.horizontal, BuxLayout.marginHorizontal)
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4))
                    .font(.system(size: 16, weight: .bold))
                
                TextField("Search region, code or symbol...", text: $searchText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, BuxLayout.marginHorizontal)
            .padding(.bottom, 16)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if filteredCurrencies.isEmpty {
                        VStack(spacing: 16) {
                            Spacer(minLength: 40)
                            Image(systemName: "globe")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.6))
                            Text("No currencies found")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    } else {
                        ForEach(filteredCurrencies) { currency in
                            CurrencyRowCard(
                                currency: currency,
                                isSelected: appSettingsManager.selectedCurrency.id == currency.id
                            ) {
                                appSettingsManager.updateCurrency(currency)
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sheetBgColor.ignoresSafeArea())
    }
}

// MARK: - Currency Row Card - PRESERVED UNCHANGED

struct CurrencyRowCard: View {
    @Environment(\.colorScheme) var colorScheme
    let currency: CurrencySetting
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(currency.flag)
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(currency.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                    Text("\(currency.id) (\(currency.symbol))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : Color(red: 140/255, green: 145/255, blue: 160/255))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.purple)
                } else {
                    Circle()
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 1.5)
            )
            .shadow(
                color: isSelected ? Color.purple.opacity(0.1) : Color.black.opacity(0.02),
                radius: 6,
                x: 0, y: 3
            )
        }
        .buttonStyle(BuxMicroShrinkStyle())
    }
}
