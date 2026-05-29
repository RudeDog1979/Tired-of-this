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
    @ObservedObject private var store = SettingsStore.shared
    
    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            BuxHeroMeshBackground()

            Form {
                Section("SWITCHBOARD") {
                    Toggle(isOn: $store.notificationsEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Notifications")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Text("Receive timely financial alerts and insights")
                                .font(.system(size: 11))
                                .buxLabelSecondary()
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                if store.notificationsEnabled {
                    Section("ALERTS & RADAR") {
                        Toggle("Budget Threshold Warnings", isOn: $store.budgetAlertsEnabled)
                        Toggle("Upcoming Bill Reminders", isOn: $store.billRemindersEnabled)
                        Toggle("Invoice Status Updates", isOn: $store.studioInvoiceRemindersEnabled)
                        Toggle("Estimated Tax Reminders", isOn: $store.taxDeadlineRemindersEnabled)
                    }
                    
                    Section("DAILY DIGEST") {
                        Toggle(isOn: $store.dailySummaryEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Daily Financial Summary")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("A compact overview of today's spend & active goals")
                                    .font(.system(size: 11))
                                    .buxLabelSecondary()
                            }
                        }
                    }
                    
                    Section("QUIET HOURS") {
                        DatePicker("Silence Starts", selection: quietHoursStartBinding, displayedComponents: .hourAndMinute)
                        DatePicker("Silence Ends", selection: quietHoursEndBinding, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .buxThemedFormStyle()
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.notificationsEnabled) { _, _ in store.save() }
        .onChange(of: store.budgetAlertsEnabled) { _, _ in store.save() }
        .onChange(of: store.billRemindersEnabled) { _, _ in store.save() }
        .onChange(of: store.studioInvoiceRemindersEnabled) { _, _ in store.save() }
        .onChange(of: store.taxDeadlineRemindersEnabled) { _, _ in store.save() }
        .onChange(of: store.dailySummaryEnabled) { _, _ in store.save() }
    }
    
    // MARK: - Date Bindings
    
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
