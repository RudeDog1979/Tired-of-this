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
    /// Pre-resolved domain — stable cache key; resolution never runs on the main thread here.
    public var knownDomain: String?
    /// Changes when a wallet/manual merchant link is created so the list picks up new logos.
    public var merchantRecordId: UUID?
    /// Category SF Symbol while loading / when favicon fetch fails (expense list). Nil → monogram.
    public var categoryFallback: MerchantCategoryAvatarStyle?
    public var size: CGFloat = 44

    @State private var image: UIImage?
    @State private var loadedOpacity: Double = 0

    public init(
        merchantName: String,
        knownDomain: String? = nil,
        merchantRecordId: UUID? = nil,
        categoryFallback: MerchantCategoryAvatarStyle? = nil,
        size: CGFloat = 44
    ) {
        self.merchantName = merchantName
        self.knownDomain = knownDomain
        self.merchantRecordId = merchantRecordId
        self.categoryFallback = categoryFallback
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

    private var cacheKey: String? {
        let domain = knownDomain?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return (domain?.isEmpty == false) ? domain : nil
    }

    /// Domain-first when known — prevents list/edit thrash when batch resolver finishes.
    private var loadIdentity: String {
        if let cacheKey { return "d|\(cacheKey)" }
        let link = merchantRecordId?.uuidString ?? ""
        let fallbackKey = categoryFallback.map { "\($0.symbol)|\($0.colorName)" } ?? ""
        return "n|\(trimmedMerchantName)|\(link)|\(fallbackKey)"
    }

    @ViewBuilder
    private var logoContent: some View {
        ZStack {
            if SettingsStore.shared.dataGuardModeEnabled {
                placeholderAvatar
            } else {
                placeholderAvatar
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
        .onAppear {
            hydrateFromDiskCacheIfNeeded()
        }
        .task(id: loadIdentity) {
            guard !SettingsStore.shared.dataGuardModeEnabled else { return }
            hydrateFromDiskCacheIfNeeded()
            await loadLogo()
        }
    }

    @ViewBuilder
    private var placeholderAvatar: some View {
        if categoryFallback != nil {
            categorySymbolAvatar
        } else {
            monogramAvatar
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

    private var categorySymbolAvatar: some View {
        let style = categoryFallback ?? MerchantCategoryAvatarFallback.style(for: .shopping)
        return ZStack {
            Circle()
                .fill(ExpenseCategoryStyle.background(for: style.colorName))
                .frame(width: size, height: size)
            Image(systemName: style.symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(ExpenseCategoryStyle.foreground(for: style.colorName))
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

    private func hydrateFromDiskCacheIfNeeded() {
        guard image == nil else { return }
        if let cacheKey,
           let cached = MerchantLogoFetchCoordinator.shared.cachedImage(forCacheKey: cacheKey) {
            applyImage(cached, animate: false)
        }
    }

    private func loadLogo() async {
        if image != nil { return }

        let name = trimmedMerchantName
        let domainHint = cacheKey

        if let domainHint,
           MerchantLogoNegativeCache.isFailure(domainHint) {
            return
        }

        if let domainHint,
           let cached = MerchantLogoFetchCoordinator.shared.cachedImage(forCacheKey: domainHint) {
            applyImage(cached, animate: false)
            return
        }

        let plan = await Task.detached(priority: .utility) { () -> MerchantLogoEngine.FetchPlan? in
            if let domainHint,
               let known = MerchantLogoEngine.fetchPlanForKnownDomain(domainHint) {
                return known
            }
            return MerchantLogoEngine.fetchPlan(for: name, knownDomain: domainHint)
        }.value

        guard let plan else {
            return
        }

        if MerchantLogoNegativeCache.isFailure(plan.cacheKey) {
            return
        }

        if let cached = MerchantLogoFetchCoordinator.shared.cachedImage(forCacheKey: plan.cacheKey) {
            applyImage(cached, animate: false)
            return
        }

        let shouldFetch = await MainActor.run { ConnectivityBrain.shared.shouldFetchMerchantIcons }
        guard let fetched = await MerchantLogoFetchCoordinator.shared.image(for: plan, shouldFetch: shouldFetch) else {
            return
        }

        applyImage(fetched, animate: image == nil)
    }

    private func applyImage(_ uiImage: UIImage, animate: Bool) {
        image = uiImage
        if animate {
            loadedOpacity = 0
            withAnimation(.easeOut(duration: 0.15)) {
                loadedOpacity = 1
            }
        } else {
            loadedOpacity = 1
        }
    }
}
