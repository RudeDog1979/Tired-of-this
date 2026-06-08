//
//  OnboardingWizardView.swift
//  BuxMuse
//
//  Premium, 5-card paging onboarding wizard displayed on first launch.
//

import SwiftUI

struct OnboardingWizardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared

    @State private var currentTab = 0
    @State private var showCountrySheet = false
    @State private var showCurrencySheet = false
    @State private var isAnimatingLogo = false
    @State private var logoDidAppear = false
    @State private var logoFloating = false
    @State private var orbitAngle: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                BuxLandingTintBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top header bar with dynamic buttons
                    headerBar

                    // Paging Cards Container
                    TabView(selection: $currentTab) {
                        welcomeCard.tag(0)
                        setupCard.tag(1)
                        studioCard.tag(2)
                        backupCard.tag(3)
                        tutorialCard.tag(4)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: currentTab)

                    // Navigation controls
                    footerBar
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                // Wait for sheet presentation to finish so user actually SEES the animation
                try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
                withAnimation(.spring(response: 0.7, dampingFraction: 0.5)) {
                    logoDidAppear = true
                }
                
                // After entrance settles, start floating
                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    logoFloating = true
                }
                
                // Add a tiny micro-pause to stop SwiftUI from merging the 3.0s and 150s animations together
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                
                // Start orbiting icons — slow continuous rotation
                withAnimation(.linear(duration: 150).repeatForever(autoreverses: false)) {
                    orbitAngle = 360
                }
            }
            .sheet(isPresented: $showCountrySheet) {
                CountryPickerView { country in
                    appSettingsManager.updateCountry(country, suggestCurrency: true)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .environment(\.settingsEnhancedTint, true)
                .buxThemedSheetContent()
            }
            .sheet(isPresented: $showCurrencySheet) {
                CurrencyRegionPickerView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .environment(\.settingsEnhancedTint, true)
                    .buxThemedSheetContent()
            }
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            Spacer()
            if currentTab < 4 {
                Button {
                    completeOnboarding()
                } label: {
                    BuxCatalogText.text("Skip")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .buttonStyle(BuxMicroShrinkStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .frame(height: 50)
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        VStack(spacing: 12) {
            if currentTab < 4 {
                BuxButton(
                    title: "Continue",
                    systemImage: "arrow.right",
                    role: .primary,
                    expands: true
                ) {
                    currentTab += 1
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } else {
                BuxButton(
                    title: "Start Using BuxMuse",
                    systemImage: "sparkles",
                    role: .primary,
                    expands: true
                ) {
                    completeOnboarding()
                }
            }
        }
        .padding(.horizontal, BuxLayout.marginHorizontal)
        .padding(.bottom, 36)
    }

    private func completeOnboarding() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        store.hasCompletedOnboarding = true
        store.save()
        dismiss()
    }

    // MARK: - Slide 1: Welcome
    private var welcomeCard: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                // Hero logo — dramatic entrance, then gentle float, with orbiting tool icons
                VStack(spacing: 20) {
                    ZStack {
                        // Orbiting tool icons
                        orbitingIcons
                            .opacity(logoDidAppear ? 1.0 : 0)
                            .scaleEffect(logoDidAppear ? 1.0 : 0.3)
                            .animation(.easeOut(duration: 1.0).delay(0.6), value: logoDidAppear)

                        // Logo (unchanged animations)
                        Image("BuxMuseLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .scaleEffect(logoDidAppear ? 1.0 : 0.05)
                            .opacity(logoDidAppear ? 1.0 : 0)
                            .offset(y: logoDidAppear ? (logoFloating ? -12 : 0) : 80)
                            .rotationEffect(.degrees(logoDidAppear ? 0 : -8))
                    }
                    .frame(width: 300, height: 300)

                    VStack(spacing: 6) {
                        BuxCatalogText.text("Welcome to BuxMuse")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .opacity(logoDidAppear ? 1.0 : 0)
                            .offset(y: logoDidAppear ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.3), value: logoDidAppear)

                        BuxCatalogText.text("Your money. Your rules. Offline, always.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .opacity(logoDidAppear ? 1.0 : 0)
                            .offset(y: logoDidAppear ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.5), value: logoDidAppear)
                    }
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 16) {
                    Text(BuxCatalogLabel.string("BuxMuse is built for everyone — from everyday spenders tracking their grocery budget, to self-employed professionals managing invoices and taxes. Private, 100% on-device, zero sign-in required.", locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 14) {
                        bulletRow(icon: "person.2.fill", text: "Everyday users, self-employed & freelancers alike")
                        bulletRow(icon: "shield.fill", text: "100% private — your data never leaves this device")
                        bulletRow(icon: "network.slash", text: "Fully functional offline, zero cloud dependencies")
                        bulletRow(icon: "checkmark.shield.fill", text: "No account, no passwords, no tracking of any kind")
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(22)
                .padding(.horizontal, BuxLayout.marginHorizontal)
            }
            .padding(.bottom, 24)
        }
        .buxScrollEdgeMask(edges: .top, size: 28)
    }

    // MARK: - Slide 2: Setup
    private var setupCard: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header block
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(themeManager.current.accentColor.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "globe")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }

                    BuxCatalogText.text("Regional & Budget")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .multilineTextAlignment(.center)

                    BuxCatalogText.text("Set up your baseline preferences")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Inline form elements
                VStack(spacing: 16) {
                    Button(action: { showCountrySheet = true }) {
                        HStack {
                            BuxCatalogText.text("Country / Region")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Spacer()
                            Text("\(appSettingsManager.selectedCountry.flag) \(appSettingsManager.selectedCountry.id)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(themeManager.chevronMuted(for: colorScheme))
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Divider().opacity(0.08)

                    Button(action: { showCurrencySheet = true }) {
                        HStack {
                            BuxCatalogText.text("Display Currency")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Spacer()
                            Text("\(appSettingsManager.selectedCurrency.flag) \(appSettingsManager.selectedCurrency.id)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(themeManager.chevronMuted(for: colorScheme))
                        }
                    }
                    .buttonStyle(.plain)

                    Divider().opacity(0.08)

                    // Budget Input Row
                    HStack {
                        BuxCatalogText.text("Monthly Budget limit")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text(appSettingsManager.selectedCurrency.symbol)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                            
                            TextField(BuxCatalogLabel.string("Limit", locale: appSettingsManager.interfaceLocale), value: Binding(
                                // If the value is 0, return nil so the text field can be completely empty
                                get: { store.simpleBudgetLimit == 0 ? nil : store.simpleBudgetLimit },
                                // If the user clears the field (nil), safely save 0 to the store
                                set: {
                                    store.simpleBudgetLimit = $0 ?? 0
                                    store.save()
                                }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            .frame(width: 80)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button(BuxCatalogLabel.string("Done", locale: appSettingsManager.interfaceLocale)) {
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    }
                                    .font(.system(size: 16, weight: .bold))
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(.horizontal, BuxLayout.marginHorizontal)
                
                // Income source info
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    
                    BuxCatalogText.text("You can adjust budgeting start dates, income sources, and weekly tracking targets at any time in Settings.")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal + 4)
            }
        }
        .buxScrollEdgeMask(edges: .top, size: 28)
    }

    // MARK: - Slide 3: Studio Mode
    private var studioCard: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header block
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.indigo.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color.indigo)
                    }

                    BuxCatalogText.text("Studio Suite")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .multilineTextAlignment(.center)

                    BuxCatalogText.text("Built-in tools for professionals")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Tier header bar
                HStack(spacing: 0) {
                    // Simple column header
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(BuxCatalogLabel.string("Simple Studio", locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Pro column header
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        Text(BuxCatalogLabel.string("Pro Studio", locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.indigo, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)

                // Feature comparison rows
                VStack(spacing: 0) {
                    studioFeatureRow(icon: "doc.richtext.fill",      feature: "PDF Invoices",         simple: "Templates included",           pro: "Full designer & custom branding")
                    studioFeatureRow(icon: "person.2.fill",          feature: "Clients & Workspace",   simple: "Up to 3 clients",              pro: "Unlimited + dedicated workspaces")
                    studioFeatureRow(icon: "percent",                feature: "Tax Studio",            simple: "Basic overview",               pro: "Deductions, profiles & forecasts")
                    studioFeatureRow(icon: "creditcard.fill",        feature: "Business Card Studio",  simple: "Preview only",                 pro: "Custom design, colors & PDF print")
                    studioFeatureRow(icon: "car.fill",               feature: "Mileage Log",           simple: "Manual entries",               pro: "Unlimited, categorized & auto")
                    studioFeatureRow(icon: "doc.text.fill",          feature: "Agreement Drafts",      simple: "Read-only templates",          pro: "Full editor, clauses & sign-off")
                    studioFeatureRow(icon: "chart.xyaxis.line",      feature: "Studio Insights",       simple: "Summary view",                 pro: "Deep analytics & cashflow")
                    studioFeatureRow(icon: "scope",                  feature: "Project Management",    simple: "—",                           pro: "Milestones, scope radar & teams", isLast: true)
                }
                .background(.ultraThinMaterial)
                .cornerRadius(18)
                .padding(.horizontal, BuxLayout.marginHorizontal)

                // CTA
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    Text(BuxCatalogLabel.string("Activate Studio in Settings → Studio. Choose Simple or unlock Pro Studio.", locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(themeManager.current.accentColor.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(themeManager.current.accentColor.opacity(0.25), lineWidth: 1)
                )
                .cornerRadius(14)
                .padding(.horizontal, BuxLayout.marginHorizontal)
            }
            .padding(.bottom, 24)
        }
        .buxScrollEdgeMask(edges: .top, size: 28)
    }

    // MARK: - Slide 4: Backup & Privacy
    private var backupCard: some View {
        cardContentScaffold(
            icon: "bell.badge.fill",
            iconColor: Color.teal,
            title: "Backup & Protection Reminders",
            subtitle: "Never lose your financial history",
            description: "Because BuxMuse is 100% offline with no servers, your ledger exists only on this device. We recommend setting up local notification alerts to remind you to back up your ledger."
        ) {
            VStack(spacing: 16) {
                // Reminders Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        BuxCatalogText.text("Enable Backup Reminders")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        Text(BuxCatalogLabel.string("Get local alerts to safeguard your ledger", locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { store.autoBackupFrequency != .off },
                        set: { isOn in
                            let newFreq: AutoBackupFrequency = isOn ? .weekly : .off
                            store.autoBackupFrequency = newFreq
                            store.save()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task {
                                await BackupNotificationScheduler.reschedule(frequency: newFreq)
                            }
                        }
                    ))
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .labelsHidden()
                }
                .padding(16)
                .background(Color.black.opacity(colorScheme == .dark ? 0.15 : 0.02))
                .cornerRadius(16)

                // Frequency Picker (Only visible if reminders are enabled)
                if store.autoBackupFrequency != .off {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(BuxCatalogLabel.string("Reminder Frequency", locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        
                        Picker(selection: Binding(
                            get: { store.autoBackupFrequency },
                            set: { newValue in
                                store.autoBackupFrequency = newValue
                                store.save()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                Task {
                                    await BackupNotificationScheduler.reschedule(frequency: newValue)
                                }
                            }
                        )) {
                            ForEach(AutoBackupFrequency.allCases) { freq in
                                if freq != .off {
                                    Text(BuxCatalogLabel.string(freq.rawValue, locale: appSettingsManager.interfaceLocale)).tag(freq)
                                }
                            }
                        } label: {
                            Text(BuxCatalogLabel.string("Frequency", locale: appSettingsManager.interfaceLocale))
                        }
                        .pickerStyle(.segmented)

                        if store.autoBackupFrequency == .custom {
                            HStack {
                                Text(BuxCatalogLabel.string("Remind me every", locale: appSettingsManager.interfaceLocale))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                                Spacer()
                                Stepper(value: Binding(
                                    get: { store.customBackupIntervalDays },
                                    set: { newValue in
                                        store.customBackupIntervalDays = max(1, min(30, newValue))
                                        store.save()
                                        Task {
                                            await BackupNotificationScheduler.reschedule(frequency: .custom)
                                        }
                                    }
                                ), in: 1...30) {
                                    Text("\(store.customBackupIntervalDays) ") + Text(BuxCatalogLabel.string(store.customBackupIntervalDays == 1 ? "day" : "days", locale: appSettingsManager.interfaceLocale))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(colorScheme == .dark ? 0.15 : 0.02))
                    .cornerRadius(16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Info card
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 20))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    VStack(alignment: .leading, spacing: 4) {
                        BuxCatalogText.text("Encrypted Backups")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        Text(BuxCatalogLabel.string("When you back up, your settings and ledger files are securely encrypted. Only BuxMuse can read them back.", locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                            .lineSpacing(2)
                    }
                }
                .padding(14)
                .background(Color.black.opacity(colorScheme == .dark ? 0.2 : 0.03))
                .cornerRadius(14)
            }
            .animation(.easeInOut(duration: 0.25), value: store.autoBackupFrequency)
        }
    }

    // MARK: - Slide 5: Tutorial (Core Features)
    private var tutorialCard: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header block
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(themeManager.current.accentColor.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: sym("info.bubble.fill", or: "info.circle.fill"))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }

                    BuxCatalogText.text("Guided Tour")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .multilineTextAlignment(.center)

                    BuxCatalogText.text("Master BuxMuse in 3 simple steps")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Tutorial rows
                VStack(spacing: 20) {
                    tutorialRow(
                        symbol: "plus.circle.fill",
                        color: themeManager.contrastAccentColor(for: colorScheme),
                        headline: "1. Rapid Entry FAB (+)",
                        bodyText: "Tap the floating action button at the bottom of the home tab. This opens a rapid entry panel allowing you to log transactions manually in seconds."
                    )
                    
                    Divider().opacity(0.08)

                    tutorialRow(
                        symbol: sym("doc.text.viewfinder", or: "viewfinder"),
                        color: Color.blue,
                        headline: "2. Receipt Vision OCR Scan",
                        bodyText: "Tap the scanner icon to capture physical receipts. On-device optical character recognition automatically extracts the merchant, transaction date, total, and logs itemized details directly into notes."
                    )

                    Divider().opacity(0.08)

                    tutorialRow(
                        symbol: sym("gauge.with.needle.fill", or: "gauge"),
                        color: Color.orange,
                        headline: "3. Payday Budget Meters",
                        bodyText: "A prominent budget indicator displays on your home tab to keep you informed of your remaining limits before the next paycheck or calendar period starts."
                    )
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(22)
                .padding(.horizontal, BuxLayout.marginHorizontal)
            }
            .padding(.bottom, 24)
        }
        .buxScrollEdgeMask(edges: .top, size: 28)
    }

    // MARK: - Helper Views & Builders
    @ViewBuilder
    private func cardContentScaffold<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        description: String,
        @ViewBuilder extraContent: () -> Content
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header block
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: icon)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(iconColor)
                    }

                    BuxCatalogText.text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .multilineTextAlignment(.center)

                    BuxCatalogText.text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 16) {
                    Text(BuxCatalogLabel.string(description, locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    extraContent()
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(22)
                .padding(.horizontal, BuxLayout.marginHorizontal)
            }
            .padding(.bottom, 24)
        }
        .buxScrollEdgeMask(edges: .top, size: 28)
    }

    private func bulletRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                .frame(width: 18, height: 18)
                .padding(.top, 1)

            Text(BuxCatalogLabel.string(text, locale: appSettingsManager.interfaceLocale))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Orbiting Tool Icons
    private var orbitingIcons: some View {
        let icons: [(name: String, color: Color)] = [
            ("hammer.fill",       .orange),
            ("scissors",          .pink),
            ("paintbrush.fill",   .purple),
            ("wrench.fill",       .blue),
            ("screwdriver.fill",  .teal),
            ("hammer",            .yellow)
        ]
        let radius: CGFloat = 130
        let count = icons.count

        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                let baseAngle = (360.0 / Double(count)) * Double(index)
                Image(systemName: icons[index].name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(icons[index].color.opacity(0.75))
                    .rotationEffect(.degrees(-orbitAngle)) // counter-rotate to stay upright
                    .offset(
                        x: radius * cos(CGFloat((baseAngle + orbitAngle) * .pi / 180)),
                        y: radius * sin(CGFloat((baseAngle + orbitAngle) * .pi / 180))
                    )
            }
        }
        .rotationEffect(.degrees(orbitAngle))
    }
    // Kept for any future use; replaced in studioCard with studioFeatureRow
    private func comparisonRow(feature: String, simple: String, pro: String, proHighlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(BuxCatalogLabel.string(feature, locale: appSettingsManager.interfaceLocale))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(BuxCatalogLabel.string("Simple Studio", locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    Text(BuxCatalogLabel.string(simple, locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(BuxCatalogLabel.string("Pro Studio", locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(proHighlight ? themeManager.current.accentColor : themeManager.labelSecondary(for: colorScheme))
                        Image(systemName: "crown.fill")
                            .font(.system(size: 8))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                    Text(BuxCatalogLabel.string(pro, locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func studioFeatureRow(icon: String, feature: String, simple: String, pro: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                // Feature name
                Text(BuxCatalogLabel.string(feature, locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Simple value
                Text(BuxCatalogLabel.string(simple, locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 90, alignment: .center)

                // Pro value
                Text(BuxCatalogLabel.string(pro, locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.indigo)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 100, alignment: .center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if !isLast {
                Divider()
                    .padding(.leading, 46)
                    .opacity(0.08)
            }
        }
    }

    private func tutorialRow(
        symbol: String,
        color: Color,
        headline: String,
        bodyText: String
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                BuxCatalogText.text(headline)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                Text(BuxCatalogLabel.string(bodyText, locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - iOS 26 Symbol Fallback Helper
    /// Returns `ios26Name` when running on iOS 26 or later,
    /// and `fallback` on iOS 18–25. Add new entries here as
    /// SF Symbols 6 (iOS 26) introduces improved or renamed glyphs.
    private func sym(_ ios26Name: String, or fallback: String) -> String {
        if #available(iOS 26, *) {
            return ios26Name
        }
        return fallback
    }
}
