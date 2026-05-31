//
//  NotificationInboxView.swift
//  BuxMuse
//

import SwiftUI

struct NotificationInboxView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator

    private var inbox: NotificationInboxDisplay { brain.notificationInboxDisplay }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                Group {
                    if inbox.items.isEmpty {
                        ContentUnavailableView {
                            Label("No Notifications", systemImage: "bell.slash")
                        } description: {
                            Text("Budget alerts, renewals, and Studio reminders will appear here.")
                        }
                    } else {
                        List {
                            ForEach(inbox.items) { item in
                                Button {
                                    handleNotificationTap(item)
                                } label: {
                                    notificationRow(item)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            brain.dismissNotification(item.id)
                                        }
                                    } label: {
                                        Label("Dismiss", systemImage: "xmark")
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .buxListContentMargins()
                        .buxSoftScrollChrome()
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .buxThemedSheetContent()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarDoneButton { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !inbox.items.isEmpty {
                        Button("Dismiss All") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                brain.dismissAllNotifications()
                            }
                        }
                        .buxToolbarTextActionStyle(accent: themeManager.current.accentColor)
                    }
                }
            }
        }
    }

    private func notificationRow(_ item: AppNotificationItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor(for: item).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: iconName(for: item))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor(for: item))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 15, weight: item.isRead ? .medium : .semibold))
                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    Spacer(minLength: 8)
                    if !item.isRead {
                        Circle()
                            .fill(themeManager.current.accentColor)
                            .frame(width: 7, height: 7)
                    }
                }
                Text(item.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(relativeDate(item.date))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func iconName(for item: AppNotificationItem) -> String {
        switch item.category {
        case .subscription, .bill: return "arrow.triangle.2.circlepath"
        case .budget: return "chart.pie.fill"
        case .invoice: return "doc.text.fill"
        case .tax: return "percent"
        case .studio: return "macbook"
        case .digest: return "sun.max.fill"
        }
    }

    private func iconColor(for item: AppNotificationItem) -> Color {
        item.severity == "high" ? .red : themeManager.current.accentColor
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }

    private func handleNotificationTap(_ item: AppNotificationItem) {
        brain.markNotificationRead(item.id)
        dismiss()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                switch item.category {
                case .subscription:
                    navigationCoordinator.openSubscriptionHub()
                case .bill:
                    navigationCoordinator.selectedTab = .expense
                case .budget:
                    navigationCoordinator.selectedTab = .settings
                case .invoice:
                    navigationCoordinator.selectedTab = .studio
                case .tax:
                    navigationCoordinator.selectedTab = .studio
                case .studio:
                    navigationCoordinator.selectedTab = .studio
                case .digest:
                    navigationCoordinator.selectedTab = .home
                    navigationCoordinator.openTipPopupRequest = true
                }
            }
        }
    }
}
