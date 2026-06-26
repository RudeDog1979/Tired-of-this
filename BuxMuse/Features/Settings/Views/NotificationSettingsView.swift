//
//  NotificationSettingsView.swift
//  BuxMuse
//
//  Notification options, category alert switches, and quiet hours.
//

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        BuxThemedCardForm {
                BuxFormSection(title: "Switchboard") {
                    Toggle(isOn: $store.notificationsEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            BuxCatalogDynamicText(key: "Enable notifications")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            BuxCatalogDynamicText(key: "Receive timely financial alerts and insights")
                                .font(.system(size: 11))
                                .buxLabelSecondary()
                        }
                    }
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()

                    if authorizationStatus == .denied {
                        BuxFormRowDivider()
                        VStack(alignment: .leading, spacing: 8) {
                            BuxCatalogDynamicText(key: "Notifications are turned off in iOS Settings.")
                                .font(.system(size: 12, weight: .medium))
                                .buxLabelSecondary()
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            } label: {
                                BuxCatalogDynamicText(key: "Open Settings")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            }
                            .buttonStyle(.plain)
                        }
                        .buxFormFieldPadding()
                    }
                }

                if store.notificationsEnabled {
                    BuxFormSection(title: "Priority alerts") {
                        Toggle(isOn: $store.billRemindersEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                BuxCatalogText.text("Bill reminders")
                                    .font(.system(size: 15, weight: .bold))
                                BuxCatalogText.text("Notify me before subscriptions and fixed payments are due")
                                    .font(.system(size: 11, weight: .medium))
                                    .buxLabelSecondary()
                            }
                        }
                            .tint(themeManager.contrastAccentColor(for: colorScheme))
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Toggle(isOn: $store.budgetAlertsEnabled) {
                            Text(BuxCatalogLabel.string("Budget threshold warnings", locale: appSettingsManager.interfaceLocale))
                        }
                            .tint(themeManager.contrastAccentColor(for: colorScheme))
                            .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "More alerts") {
                        Toggle(isOn: $store.studioInvoiceRemindersEnabled) {
                            Text(BuxCatalogLabel.string("Invoice status updates", locale: appSettingsManager.interfaceLocale))
                        }
                            .tint(themeManager.contrastAccentColor(for: colorScheme))
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Toggle(isOn: $store.taxDeadlineRemindersEnabled) {
                            Text(BuxCatalogLabel.string("Estimated tax reminders", locale: appSettingsManager.interfaceLocale))
                        }
                            .tint(themeManager.contrastAccentColor(for: colorScheme))
                            .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Daily digest") {
                        Toggle(isOn: $store.dailySummaryEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                BuxCatalogDynamicText(key: "Daily financial summary")
                                    .font(.system(size: 15, weight: .semibold))
                                BuxCatalogDynamicText(key: "A compact overview of today's spend & active goals")
                                    .font(.system(size: 11))
                                    .buxLabelSecondary()
                            }
                        }
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Toggle(isOn: $store.dailyTipNotificationsEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                BuxCatalogDynamicText(key: "Daily tip & scam alert")
                                    .font(.system(size: 15, weight: .semibold))
                                BuxCatalogDynamicText(key: "Morning notification with today's money tip and scam watch-out")
                                    .font(.system(size: 11))
                                    .buxLabelSecondary()
                            }
                        }
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Quiet hours") {
                        Toggle(isOn: $store.quietHoursEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                BuxCatalogDynamicText(key: "Enable quiet hours")
                                    .font(.system(size: 15, weight: .semibold))
                                BuxCatalogDynamicText(key: "Silence alerts during the hours you choose")
                                    .font(.system(size: 11))
                                    .buxLabelSecondary()
                            }
                        }
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()

                        if store.quietHoursEnabled {
                            BuxFormRowDivider()
                            DatePicker(
                                selection: quietHoursStartBinding,
                                displayedComponents: .hourAndMinute
                            ) {
                                Text(BuxCatalogLabel.string("Silence starts", locale: appSettingsManager.interfaceLocale))
                            }
                                .tint(themeManager.contrastAccentColor(for: colorScheme))
                                .buxFormFieldPadding()
                            BuxFormRowDivider()
                            DatePicker(
                                selection: quietHoursEndBinding,
                                displayedComponents: .hourAndMinute
                            ) {
                                Text(BuxCatalogLabel.string("Silence ends", locale: appSettingsManager.interfaceLocale))
                            }
                                .tint(themeManager.contrastAccentColor(for: colorScheme))
                                .buxFormFieldPadding()
                        }
                    }
                }
            }
        .buxCatalogNavigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.settingsEnhancedTint, true)
        .task {
            authorizationStatus = await BuxNotificationPolicy.authorizationStatus()
        }
        .onChange(of: store.notificationsEnabled) { _, _ in store.save() }
        .onChange(of: store.budgetAlertsEnabled) { _, _ in store.save() }
        .onChange(of: store.billRemindersEnabled) { _, _ in store.save() }
        .onChange(of: store.studioInvoiceRemindersEnabled) { _, _ in store.save() }
        .onChange(of: store.taxDeadlineRemindersEnabled) { _, _ in store.save() }
        .onChange(of: store.dailySummaryEnabled) { _, _ in store.save() }
        .onChange(of: store.dailyTipNotificationsEnabled) { _, _ in store.save() }
        .onChange(of: store.quietHoursEnabled) { _, _ in store.save() }
    }

    private var quietHoursStartBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let cal = Calendar.current
                var components = DateComponents()
                components.hour = store.quietHoursStartHour
                components.minute = store.quietHoursStartMinute
                return cal.date(from: components) ?? Date()
            },
            set: { newDate in
                let cal = Calendar.current
                let components = cal.dateComponents([.hour, .minute], from: newDate)
                store.quietHoursStartHour = components.hour ?? 22
                store.quietHoursStartMinute = components.minute ?? 0
                store.save()
            }
        )
    }

    private var quietHoursEndBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let cal = Calendar.current
                var components = DateComponents()
                components.hour = store.quietHoursEndHour
                components.minute = store.quietHoursEndMinute
                return cal.date(from: components) ?? Date()
            },
            set: { newDate in
                let cal = Calendar.current
                let components = cal.dateComponents([.hour, .minute], from: newDate)
                store.quietHoursEndHour = components.hour ?? 7
                store.quietHoursEndMinute = components.minute ?? 0
                store.save()
            }
        )
    }
}
