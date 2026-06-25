//
//  AsyncMerchantLogoView.swift
//  BuxMuse
//  Brain/Engine/Logos/
//
//  Asynchronous SwiftUI image view with local cache lookup and soft fade-in transitions.
//

import SwiftUI

public struct AsyncMerchantLogoView: View {
    public let merchantName: String
    /// Resolved domain from merchant record or offline resolver — skips guesswork at fetch time.
    public var knownDomain: String?
    /// Changes when a wallet/manual merchant link is created so the list picks up new logos.
    public var merchantRecordId: UUID?
    public var size: CGFloat = 44

    @State private var image: UIImage?
    @State private var loadedOpacity: Double = 0

    public init(
        merchantName: String,
        knownDomain: String? = nil,
        merchantRecordId: UUID? = nil,
        size: CGFloat = 44
    ) {
        self.merchantName = merchantName
        self.knownDomain = knownDomain
        self.merchantRecordId = merchantRecordId
        self.size = size
    }

    public var body: some View {
        Group {
            if trimmedMerchantName.isEmpty {
                emptyPlaceholder
            } else {
                logoContent
            }
        }
        .frame(width: size, height: size)
    }

    private var trimmedMerchantName: String {
        merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var loadIdentity: String {
        let domain = knownDomain?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let link = merchantRecordId?.uuidString ?? ""
        return "\(trimmedMerchantName)|\(domain)|\(link)"
    }

    @ViewBuilder
    private var logoContent: some View {
        ZStack {
            if SettingsStore.shared.dataGuardModeEnabled {
                monogramAvatar
            } else {
                monogramAvatar
                    .opacity(image == nil ? 1 : 0)

                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .opacity(loadedOpacity)
                }
            }
        }
        .task(id: loadIdentity) {
            guard !SettingsStore.shared.dataGuardModeEnabled else { return }
            await loadLogo()
        }
    }

    private var emptyPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.12))
                .frame(width: size, height: size)
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.gray)
        }
    }

    private var monogramAvatar: some View {
        ZStack {
            Circle()
                .fill(monogramBackground)
                .frame(width: size, height: size)
            Text(monogramInitials)
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    private var monogramInitials: String {
        let words = merchantName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        if words.count >= 2 {
            return String((words[0].first ?? Character("?")).uppercased() + (words[1].first ?? Character("?")).uppercased())
        } else if let first = words.first, !first.isEmpty {
            return String(first.prefix(2).uppercased())
        }
        return "?"
    }

    private var monogramBackground: Color {
        let hash = abs(merchantName.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.62)
    }

    private func loadLogo() async {
        let name = trimmedMerchantName
        let domain = knownDomain?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let domain, !domain.isEmpty,
           let cached = MerchantLogoFetchCoordinator.shared.cachedImage(forCacheKey: domain) {
            applyImage(cached, animate: image == nil)
            return
        }

        let plan = await Task.detached(priority: .userInitiated) {
            MerchantLogoEngine.fetchPlan(
                for: name,
                knownDomain: domain?.isEmpty == false ? domain : nil
            )
        }.value

        guard let plan else { return }

        if let cached = MerchantLogoFetchCoordinator.shared.cachedImage(forCacheKey: plan.cacheKey) {
            applyImage(cached, animate: image == nil)
            return
        }

        let shouldFetch = await MainActor.run { ConnectivityBrain.shared.shouldFetchMerchantIcons }
        guard let fetched = await MerchantLogoFetchCoordinator.shared.image(for: plan, shouldFetch: shouldFetch) else {
            return
        }

        applyImage(fetched, animate: true)
    }

    private func applyImage(_ uiImage: UIImage, animate: Bool) {
        image = uiImage
        if animate {
            loadedOpacity = 0
            withAnimation(.easeOut(duration: 0.2)) {
                loadedOpacity = 1
            }
        } else {
            loadedOpacity = 1
        }
    }
}
