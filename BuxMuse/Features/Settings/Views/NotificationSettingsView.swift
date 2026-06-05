//
//  NotificationSettingsView.swift
//  BuxMuse
//
//  Notification options, category alert switches, and quiet hours.
//

import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

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
                    .tint(themeManager.current.accentColor)
                    .buxFormFieldPadding()
                }

                if store.notificationsEnabled {
                    BuxFormSection(title: "Alerts & radar") {
                        Toggle(isOn: $store.budgetAlertsEnabled) {
                            Text(BuxCatalogLabel.string("Budget threshold warnings", locale: appSettingsManager.interfaceLocale))
                        }
                            .tint(themeManager.current.accentColor)
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Toggle(isOn: $store.billRemindersEnabled) {
                            Text(BuxCatalogLabel.string("Upcoming bill reminders", locale: appSettingsManager.interfaceLocale))
                        }
                            .tint(themeManager.current.accentColor)
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Toggle(isOn: $store.studioInvoiceRemindersEnabled) {
                            Text(BuxCatalogLabel.string("Invoice status updates", locale: appSettingsManager.interfaceLocale))
                        }
                            .tint(themeManager.current.accentColor)
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Toggle(isOn: $store.taxDeadlineRemindersEnabled) {
                            Text(BuxCatalogLabel.string("Estimated tax reminders", locale: appSettingsManager.interfaceLocale))
                        }
                            .tint(themeManager.current.accentColor)
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
                        .tint(themeManager.current.accentColor)
                        .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Quiet hours") {
                        DatePicker(
                            selection: quietHoursStartBinding,
                            displayedComponents: .hourAndMinute
                        ) {
                            Text(BuxCatalogLabel.string("Silence starts", locale: appSettingsManager.interfaceLocale))
                        }
                            .tint(themeManager.current.accentColor)
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        DatePicker(
                            selection: quietHoursEndBinding,
                            displayedComponents: .hourAndMinute
                        ) {
                            Text(BuxCatalogLabel.string("Silence ends", locale: appSettingsManager.interfaceLocale))
                        }
                            .tint(themeManager.current.accentColor)
                            .buxFormFieldPadding()
                    }
                }
            }
        }
        .buxCatalogNavigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.settingsEnhancedTint, true)
        .onChange(of: store.notificationsEnabled) { _, _ in store.save() }
        .onChange(of: store.budgetAlertsEnabled) { _, _ in store.save() }
        .onChange(of: store.billRemindersEnabled) { _, _ in store.save() }
        .onChange(of: store.studioInvoiceRemindersEnabled) { _, _ in store.save() }
        .onChange(of: store.taxDeadlineRemindersEnabled) { _, _ in store.save() }
        .onChange(of: store.dailySummaryEnabled) { _, _ in store.save() }
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
