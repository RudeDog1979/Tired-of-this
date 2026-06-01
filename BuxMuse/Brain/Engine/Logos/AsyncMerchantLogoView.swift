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
    public var size: CGFloat = 44

    @State private var image: UIImage?
    @State private var loadedOpacity: Double = 0
    @State private var loadToken = UUID()

    public init(merchantName: String, size: CGFloat = 44) {
        self.merchantName = merchantName
        self.size = size
    }

    public var body: some View {
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
        .frame(width: size, height: size)
        .onAppear { if !SettingsStore.shared.dataGuardModeEnabled { loadLogo() } }
        .onChange(of: merchantName) { _, _ in if !SettingsStore.shared.dataGuardModeEnabled { loadLogo() } }
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

    private func loadLogo() {
        let token = UUID()
        loadToken = token
        image = nil
        loadedOpacity = 0

        guard let plan = MerchantLogoEngine.fetchPlan(for: merchantName) else { return }

        if let cached = LightweightLogoCache.shared.getImage(forKey: plan.cacheKey) {
            image = cached
            loadedOpacity = 1
            return
        }

        Task {
            let shouldFetch = await MainActor.run { ConnectivityBrain.shared.shouldFetchMerchantIcons }
            guard shouldFetch else { return }
            guard let fetched = await MerchantLogoEngine.fetchRemoteLogo(plan: plan) else { return }
            await MainActor.run {
                guard loadToken == token else { return }
                image = fetched
                loadedOpacity = 1
            }
        }
    }

    private var fallbackSymbol: String {
        let normalized = MerchantLogoEngine.normalizeMerchantName(merchantName)
        if normalized.contains("biedronka") || normalized.contains("lidl") || normalized.contains("aldi")
            || normalized.contains("tesco") || normalized.contains("asda") || normalized.contains("sainsbury")
            || normalized.contains("carrefour") || normalized.contains("kaufland") || normalized.contains("zabka") {
            return "cart.fill"
        }
        if normalized.contains("spotify") || normalized.contains("music") || normalized.contains("netflix") {
            return "arrow.triangle.2.circlepath"
        } else if normalized.contains("uber") || normalized.contains("taxi") || normalized.contains("car") {
            return "car.fill"
        } else if normalized.contains("market") || normalized.contains("grocer") || normalized.contains("store") {
            return "cart.fill"
        } else if normalized.contains("starbucks") || normalized.contains("coffee") || normalized.contains("restaurant") || normalized.contains("food") {
            return "fork.knife"
        }
        return "building.2.crop.circle"
    }
}
