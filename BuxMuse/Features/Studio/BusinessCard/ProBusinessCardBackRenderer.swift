//
//  ProBusinessCardBackRenderer.swift
//  BuxMuse
//
//  Standard back-of-card layout — logo, contact, optional note.
//

import SwiftUI

struct ProBusinessCardBackRenderer: View {
    let design: ProBusinessCardDesign
    let logoData: Data?

    private var palette: ProBusinessCardPalette { design.palette }
    private var back: ProBusinessCardBackSide { design.backSide }

    var body: some View {
        let size = design.aspect.previewSize
        ZStack {
            Color(hex: palette.backgroundHex)
            accentBand
            VStack(spacing: 14) {
                if back.showsLogo, let logo = logoImage {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: size.width * 0.28, maxHeight: size.height * 0.22)
                } else if back.showsLogo {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color(hex: palette.accentHex))
                }

                if !design.content.name.isEmpty {
                    Text(design.content.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: palette.foregroundHex))
                        .multilineTextAlignment(.center)
                }

                if back.showsContact {
                    VStack(spacing: 6) {
                        if !design.content.phone.isEmpty {
                            contactLine("phone.fill", design.content.phone)
                        }
                        if !design.content.email.isEmpty {
                            contactLine("envelope.fill", design.content.email)
                        }
                        if !design.content.website.isEmpty {
                            contactLine("globe", design.content.website)
                        }
                    }
                }

                if !back.note.isEmpty {
                    Text(back.note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: palette.foregroundHex).opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 18)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var accentBand: some View {
        VStack {
            Color(hex: palette.accentHex)
                .frame(height: 6)
            Spacer()
        }
    }

    private func contactLine(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(hex: palette.accentHex))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: palette.foregroundHex))
        }
    }

    private var logoImage: UIImage? {
        guard let logoData, let img = UIImage(data: logoData) else { return nil }
        return img
    }
}

enum ProBusinessCardSide: String, CaseIterable, Identifiable {
    case front, back
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
