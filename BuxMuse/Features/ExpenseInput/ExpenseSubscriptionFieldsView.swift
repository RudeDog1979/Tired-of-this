//
//  ExpenseSubscriptionFieldsView.swift
//  BuxMuse
//
//  Subscription / trial / reminder inputs — native Form rows (no card chrome).
//

import SwiftUI

struct ExpenseSubscriptionFieldsView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    @Binding var isSubscription: Bool
    @Binding var isTrial: Bool
    @Binding var subscriptionStartDate: Date
    @Binding var trialEndDate: Date
    @Binding var renewalReminderDays: Int

    private let reminderPresets = [1, 3, 7, 14]

    var body: some View {
        Group {
            Toggle("This is a subscription", isOn: $isSubscription)

            if isSubscription {
                Toggle("This is a trial", isOn: $isTrial)

                if isTrial {
                    DatePicker("Trial end date", selection: $trialEndDate, displayedComponents: .date)
                } else {
                    DatePicker("Subscription start", selection: $subscriptionStartDate, displayedComponents: .date)
                }

                reminderSection
            }
        }
        .tint(themeManager.current.accentColor)
        .animation(nil, value: isSubscription)
        .animation(nil, value: isTrial)
    }

    @ViewBuilder
    private var reminderSection: some View {
        VStack(spacing: 10) {
            Text("Remind me before renewal")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 8) {
                ForEach(reminderPresets, id: \.self) { days in
                    Button {
                        renewalReminderDays = days
                    } label: {
                        Text("\(days)d")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(renewalReminderDays == days ? .white : themeManager.current.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                renewalReminderDays == days
                                    ? themeManager.current.accentColor
                                    : themeManager.current.accentColor.opacity(0.1)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BuxMicroShrinkStyle())
                }

                Stepper(value: $renewalReminderDays, in: 1...30) {
                    Text("\(renewalReminderDays)d")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(themeManager.current.accentColor)
                        .frame(minWidth: 36)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text("Local notification \(renewalReminderDays) day\(renewalReminderDays == 1 ? "" : "s") before renewal.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 4)
    }
}
