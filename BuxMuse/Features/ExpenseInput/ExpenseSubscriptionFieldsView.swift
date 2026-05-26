//
//  ExpenseSubscriptionFieldsView.swift
//  BuxMuse
//
//  Subscription / trial / reminder inputs on add-expense sheet.
//

import SwiftUI

struct ExpenseSubscriptionFieldsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    @Binding var isSubscription: Bool
    @Binding var isTrial: Bool
    @Binding var subscriptionStartDate: Date
    @Binding var trialEndDate: Date
    @Binding var renewalReminderDays: Int

    private let reminderPresets = [1, 3, 7, 14]

    private var cardColor: Color {
        themeManager.cardFill(for: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SUBSCRIPTION")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : Color(red: 140/255, green: 145/255, blue: 160/255))
                .kerning(1.2)

            VStack(spacing: 0) {
                toggleRow("This is a subscription", isOn: $isSubscription)
                if isSubscription {
                    Divider().opacity(0.08)
                    toggleRow("This is a trial", isOn: $isTrial)
                }
            }
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(themeManager.subtleCardStroke(for: colorScheme), lineWidth: 1)
            )

            if isSubscription {
                VStack(alignment: .leading, spacing: 12) {
                    if isTrial {
                        labeledDate("Trial end date", date: $trialEndDate)
                    } else {
                        labeledDate("Subscription start", date: $subscriptionStartDate)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("REMIND ME BEFORE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .kerning(1.2)

                        HStack(spacing: 8) {
                            ForEach(reminderPresets, id: \.self) { days in
                                Button {
                                    withAnimation(.buxSnap) {
                                        renewalReminderDays = days
                                    }
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

                            Stepper("Custom: \(renewalReminderDays)d", value: $renewalReminderDays, in: 1...30)
                                .font(.system(size: 12, weight: .semibold))
                                .labelsHidden()
                        }

                        Text("Local notification \(renewalReminderDays) day\(renewalReminderDays == 1 ? "" : "s") before renewal.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                .padding(16)
                .background(cardColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.subtleCardStroke(for: colorScheme), lineWidth: 1)
                )
                .transition(.buxScaleReveal)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isSubscription)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isTrial)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(.system(size: 15, weight: .semibold))
            .tint(themeManager.current.accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    private func labeledDate(_ title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .kerning(1.2)
            DatePicker("", selection: date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(themeManager.current.accentColor)
        }
    }
}
