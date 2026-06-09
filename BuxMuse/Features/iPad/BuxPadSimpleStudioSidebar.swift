//
//  BuxPadSimpleStudioSidebar.swift
//  BuxMuse — Simple Studio left sidebar (iPad regular width).
//

import SwiftUI

struct BuxPadSimpleStudioSidebar: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var selection: BuxPadSimpleStudioDestination?

    var body: some View {
        List {
            Section {
                sidebarHeader
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
            }

            sidebarSection(title: "Overview", items: BuxPadSimpleStudioDestination.overviewSection)
            sidebarSection(title: "Work", items: BuxPadSimpleStudioDestination.workSection)
            sidebarSection(title: "Money", items: BuxPadSimpleStudioDestination.moneySection)
            sidebarSection(title: "Tools", items: BuxPadSimpleStudioDestination.toolsSection)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .buxPadSidebarToggleTint(themeManager.contrastAccentColor(for: colorScheme))
    }

    private var sidebarHeader: some View {
        SimpleStudioHeader()
            .padding(.horizontal, BuxPadLayout.detailInsetRegular)
    }

    @ViewBuilder
    private func sidebarSection(title: String, items: [BuxPadSimpleStudioDestination]) -> some View {
        Section(title) {
            ForEach(items) { item in
                Button {
                    BuxPadSidebarSelection.select(item, into: $selection)
                } label: {
                    sidebarRow(item, isSelected: selection == item)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    BuxPadSidebarSelection.rowBackground(
                        isSelected: selection == item,
                        themeManager: themeManager,
                        colorScheme: colorScheme
                    )
                )
                .listRowInsets(BuxPadSidebarSelection.rowInsets)
                .listRowSeparator(.hidden)
                .buxPadStudioOpenInNewWindowContextMenu(destination: item.rawValue)
            }
        }
    }

    private func sidebarRow(_ item: BuxPadSimpleStudioDestination, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(item.tint)
                    .frame(width: 34, height: 34)
                    .shadow(color: item.tint.opacity(isSelected ? 0.45 : 0.35), radius: isSelected ? 6 : 5, x: 0, y: 2)
                Image(systemName: item.systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isSelected ? 1.04 : 1)
            .animation(BuxPadSidebarSelection.selectionAnimation, value: isSelected)

            Text(item.title)
                .font(.body.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                .animation(BuxPadSidebarSelection.selectionAnimation, value: isSelected)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .buxPadHoverable()
    }
}
