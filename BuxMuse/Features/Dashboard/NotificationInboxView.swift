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

    private var inbox: NotificationInboxDisplay { brain.notificationInboxDisplay }

    var body: some View {
        NavigationStack {
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
                                brain.markNotificationRead(item.id)
                            } label: {
                                notificationRow(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if inbox.unreadCount > 0 {
                        Button("Read All") {
                            brain.markAllNotificationsRead()
                        }
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
}
