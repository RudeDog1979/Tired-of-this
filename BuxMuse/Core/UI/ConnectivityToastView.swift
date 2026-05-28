//
//  ConnectivityToastView.swift
//  BuxMuse
//
//  Top-of-screen connectivity banner (below safe area).
//

import SwiftUI

struct ConnectivityToastView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var connectivity = ConnectivityBrain.shared

    var body: some View {
        Group {
            if let toast = connectivity.activeToast {
                HStack(spacing: 10) {
                    Image(systemName: icon(for: toast.style))
                        .font(.system(size: 14, weight: .semibold))
                    Text(toast.message)
                        .font(.system(size: 13, weight: .semibold))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Button {
                        connectivity.dismissToast()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .foregroundColor(foreground(for: toast.style))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(background(for: toast.style))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 12, y: 4)
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaPadding(.top, 4)
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: connectivity.activeToast)
    }

    private func icon(for style: ConnectivityToastStyle) -> String {
        switch style {
        case .offline: return "wifi.slash"
        case .online: return "wifi"
        case .informational: return "info.circle.fill"
        }
    }

    private func foreground(for style: ConnectivityToastStyle) -> Color {
        switch style {
        case .offline: return themeManager.labelPrimary(for: colorScheme)
        case .online: return .white
        case .informational: return themeManager.labelPrimary(for: colorScheme)
        }
    }

    @ViewBuilder
    private func background(for style: ConnectivityToastStyle) -> some View {
        switch style {
        case .offline:
            Rectangle().fill(.ultraThinMaterial)
        case .online:
            Rectangle().fill(
                Color(
                    red: colorScheme == .dark ? 0.12 : 0.10,
                    green: colorScheme == .dark ? 0.55 : 0.48,
                    blue: colorScheme == .dark ? 0.28 : 0.22
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.25), lineWidth: 0.5)
            }
        case .informational:
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}
