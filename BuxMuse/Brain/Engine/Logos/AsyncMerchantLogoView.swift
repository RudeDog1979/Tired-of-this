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
    /// When set (linked merchants), skips fuzzy catalog matching during plan resolution.
    public var knownDomain: String?
    public var size: CGFloat = 44

    @State private var image: UIImage?
    @State private var loadedOpacity: Double = 0
    @State private var loadToken = UUID()

    public init(merchantName: String, knownDomain: String? = nil, size: CGFloat = 44) {
        self.merchantName = merchantName
        self.knownDomain = knownDomain
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
        return "\(trimmedMerchantName)|\(domain)"
    }

    @ViewBuilder
    private var logoContent: some View {
        ZStack {
            // Data Guard: render text monogram instead of any logo network call
            if SettingsStore.shared.dataGuardModeEnabled {
                monogramAvatar
            } else if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .opacity(loadedOpacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.3)) {
                            loadedOpacity = 1.0
                        }
                    }
            } else {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: size, height: size)

                    Image(systemName: fallbackSymbol)
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundColor(.gray)
                }
                .transition(.opacity)
            }
        }
        .task(id: loadIdentity) {
            guard !SettingsStore.shared.dataGuardModeEnabled else { return }
            await Task.yield()
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

    /// Premium monogram avatar rendered locally — no network, no data cost.
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
        // Deterministic pastel hue from merchant name hash
        let hash = abs(merchantName.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.62)
    }

    private func loadLogo() async {
        let token = UUID()
        let name = trimmedMerchantName
        let domain = knownDomain?.trimmingCharacters(in: .whitespacesAndNewlines)

        await MainActor.run {
            loadToken = token
        }

        let plan = await Task.detached(priority: .utility) {
            MerchantLogoEngine.fetchPlan(for: name, knownDomain: domain)
        }.value

        guard let plan else {
            await MainActor.run {
                guard loadToken == token else { return }
                image = nil
                loadedOpacity = 0
            }
            return
        }

        let cached = await MainActor.run {
            LightweightLogoCache.shared.getImage(forKey: plan.cacheKey)
        }

        if let cached {
            await MainActor.run {
                guard loadToken == token else { return }
                image = cached
                loadedOpacity = 1
            }
            return
        }

        await MainActor.run {
            guard loadToken == token else { return }
            image = nil
            loadedOpacity = 0
        }

        let shouldFetch = await MainActor.run { ConnectivityBrain.shared.shouldFetchMerchantIcons }
        guard shouldFetch else { return }

        guard let fetched = await MerchantLogoEngine.fetchRemoteLogo(plan: plan) else { return }

        await MainActor.run {
            guard loadToken == token else { return }
            image = fetched
            loadedOpacity = 1
        }
    }

    private var fallbackSymbol: String {
        let lower = trimmedMerchantName.lowercased()
        if lower.contains("biedronka") || lower.contains("lidl") || lower.contains("aldi")
            || lower.contains("tesco") || lower.contains("asda") || lower.contains("sainsbury")
            || lower.contains("carrefour") || lower.contains("kaufland") || lower.contains("zabka") {
            return "cart.fill"
        }
        if lower.contains("spotify") || lower.contains("music") || lower.contains("netflix") {
            return "arrow.triangle.2.circlepath"
        } else if lower.contains("uber") || lower.contains("taxi") || lower.contains("car") {
            return "car.fill"
        } else if lower.contains("market") || lower.contains("grocer") || lower.contains("store") {
            return "cart.fill"
        } else if lower.contains("starbucks") || lower.contains("coffee") || lower.contains("restaurant") || lower.contains("food") {
            return "fork.knife"
        }
        return "building.2.crop.circle"
    }
}
