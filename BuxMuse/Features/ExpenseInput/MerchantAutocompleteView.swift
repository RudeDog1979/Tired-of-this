//
//  MerchantAutocompleteView.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Autocompletion dropdown list showing merchant candidates in solid BuxMuse style cards.
//

import SwiftUI

struct MerchantAutocompleteView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    let candidates: [MerchantCandidate]
    let onSelect: (MerchantCandidate) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(candidates) { candidate in
                        Button(action: { onSelect(candidate) }) {
                            HStack(spacing: 12) {
                                AsyncMerchantLogoView(
                                    merchantName: candidate.historyLabel ?? candidate.displayName,
                                    size: 32
                                )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(candidate.displayName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                        .lineLimit(1)

                                    Text(candidate.subtitle)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                                        .lineLimit(2)
                                }

                                Spacer()

                                if candidate.matchKind == .newMerchant {
                                    Text("New")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(themeManager.current.accentColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(themeManager.pillActiveChipFill(for: colorScheme))
                                        .clipShape(Capsule())
                                } else if candidate.matchKind == .knownRetailer {
                                    Text("Popular")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(themeManager.current.accentColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(themeManager.pillActiveChipFill(for: colorScheme).opacity(0.65))
                                        .clipShape(Capsule())
                                } else if candidate.matchKind == .aliasVariant {
                                    Text("Pick")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.14))
                                        .clipShape(Capsule())
                                } else {
                                    Image(systemName: "arrow.up.left")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray.opacity(0.6))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(BuxMicroShrinkStyle())

                        Divider().opacity(0.08)
                    }
                }
            }
        }
        .frame(maxHeight: 340)
        .expensesThemedCardChrome(cornerRadius: 16)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 10, x: 0, y: 5)
    }
}
