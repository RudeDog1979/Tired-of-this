//
//  MerchantLogoEngine.swift
//  BuxMuse
//  Brain/Engine/Logos/
//
//  Privacy-first Merchant Logo Caching and Resolution Engine.
//

import Foundation
import CryptoKit
import ImageIO
#if canImport(UIKit)
import UIKit
#endif

public struct MerchantLogoEngine {
    private nonisolated static let nonAlphanumericWhitespace = CharacterSet.alphanumerics.union(.whitespaces).inverted
    private nonisolated(unsafe) static let normalizationCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 512
        return cache
    }()

    // MARK: - Normalizer
    public nonisolated static func normalizeMerchantName(_ name: String) -> String {
        let key = name as NSString
        if let cached = normalizationCache.object(forKey: key) {
            return cached as String
        }
        let normalized = normalizeMerchantNameUncached(name)
        normalizationCache.setObject(normalized as NSString, forKey: key)
        return normalized
    }

    private nonisolated static func normalizeMerchantNameUncached(_ name: String) -> String {
        var clean = name.lowercased()

        // Remove emojis
        clean = clean.filter { !$0.isEmoji }

        // Domino's → dominos, Nando's → nandos (keeps brand stem before punctuation strip)
        clean = clean.replacingOccurrences(of: "'s", with: "s")
        clean = clean.replacingOccurrences(of: "\u{2019}s", with: "s")

        // Remove common suffixes
        let suffixes = ["ltd", "inc", "s.a.", "sa", "llc", "corp", "co", "incorporated", "limited"]
        for suffix in suffixes {
            let escaped = NSRegularExpression.escapedPattern(for: suffix)
            clean = clean.replacingOccurrences(of: "\\b\(escaped)\\b", with: "", options: .regularExpression)
        }

        // Remove punctuation & special chars
        clean = clean.components(separatedBy: nonAlphanumericWhitespace).joined()

        // Trim edge and consecutive spaces
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return clean
    }

    /// Domain host from a persisted Google favicon URL (`logoURL` on linked merchants).
    public nonisolated static func domain(fromStoredLogoURL logoURL: String) -> String? {
        let trimmed = logoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let domain = components.queryItems?.first(where: { $0.name == "domain" })?.value {
            let clean = domain.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? nil : clean
        }

        // DuckDuckGo ip3 URLs: https://icons.duckduckgo.com/ip3/example.com.ico
        if let range = trimmed.range(of: "/ip3/") {
            let hostPart = String(trimmed[range.upperBound...])
                .replacingOccurrences(of: ".ico", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return hostPart.isEmpty ? nil : hostPart
        }

        return nil
    }
    
    // MARK: - Domain Resolver
    public nonisolated static func resolveDomain(
        for merchantName: String,
        countryISO: String? = nil,
        currencyCode: String? = nil
    ) -> String? {
        MerchantDomainResolver.resolveDomain(
            for: merchantName,
            countryISO: countryISO,
            currencyCode: currencyCode
        )
    }

    /// Low-priority warm-up after merchant persistence — never blocks save/import paths.
    public static func schedulePrefetch(for merchantName: String, knownDomain: String? = nil) {
        let name = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let domain = knownDomain?.trimmingCharacters(in: .whitespacesAndNewlines)
        Task.detached(priority: .utility) {
            let shouldFetch = await MainActor.run { ConnectivityBrain.shared.shouldFetchMerchantIcons }
            guard shouldFetch else { return }
            let plan = fetchPlan(for: name, knownDomain: domain?.isEmpty == false ? domain : nil)
            guard let plan else { return }
            await MerchantLogoFetchCoordinator.shared.prefetch(plan: plan, shouldFetch: true)
        }
    }

    /// After wallet sync, warm every linked merchant logo in parallel (deduped by cache key).
    static func scheduleBulkPrefetch(merchants: [ExpenseMerchantRecord]) {
        var inputs: [(name: String, domain: String?)] = []
        inputs.reserveCapacity(merchants.count)
        for merchant in merchants {
            let name = merchant.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let domain = merchant.logoURL.flatMap { Self.domain(fromStoredLogoURL: $0) }
            inputs.append((name: name, domain: domain))
        }
        guard !inputs.isEmpty else { return }
        Task.detached(priority: .utility) {
            let shouldFetch = await MainActor.run { ConnectivityBrain.shared.shouldFetchMerchantIcons }
            guard shouldFetch else { return }
            var plans: [FetchPlan] = []
            var seen = Set<String>()
            for input in inputs.prefix(32) {
                let plan: FetchPlan?
                if let domain = input.domain, !domain.isEmpty {
                    plan = fetchPlanForKnownDomain(domain) ?? fetchPlan(for: input.name, knownDomain: domain)
                } else {
                    plan = fetchPlan(for: input.name, knownDomain: nil)
                }
                guard let plan, seen.insert(plan.cacheKey).inserted else { continue }
                if MerchantLogoFetchCoordinator.shared.cachedImage(forCacheKey: plan.cacheKey) == nil {
                    plans.append(plan)
                }
            }
            await MerchantLogoFetchCoordinator.shared.prefetchPlans(plans, shouldFetch: true)
        }
    }

    public nonisolated static func googleFaviconURL(for domain: String, size: Int = 256) -> String {
        "https://www.google.com/s2/favicons?sz=\(size)&domain=\(domain)"
    }

    // MARK: - Remote logo fetch

    public struct FetchPlan: Sendable {
        public let cacheKey: String
        public let urls: [URL]
    }

    /// Domain-first cache key so "Biedronka" and typos share the same logo.
    public nonisolated static func fetchPlan(for merchantName: String, knownDomain: String? = nil) -> FetchPlan? {
        if let knownDomain,
           MerchantDomainResolver.isPlausibleLogoHost(knownDomain),
           let plan = fetchPlanForKnownDomain(knownDomain) {
            return plan
        }

        guard let domain = resolveDomain(for: merchantName) else { return nil }
        return fetchPlanForKnownDomain(domain)
    }

    /// Only resolves logos for an explicit known domain — no heuristic `.com` guessing.
    public nonisolated static func fetchPlanForKnownDomain(_ domain: String) -> FetchPlan? {
        let cleanHost = domain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        guard !cleanHost.isEmpty else { return nil }
        let urls = remoteLogoURLs(forHost: cleanHost).compactMap(URL.init(string:))
        guard !urls.isEmpty else { return nil }
        return FetchPlan(cacheKey: cleanHost, urls: urls)
    }

    /// Google first, DuckDuckGo fallback only.
    nonisolated static func remoteLogoURLs(forHost host: String) -> [String] {
        let cleanHost = host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        guard !cleanHost.isEmpty else { return [] }

        return [
            googleFaviconURL(for: cleanHost, size: 256),
            googleFaviconURL(for: cleanHost, size: 128),
            "https://icons.duckduckgo.com/ip3/\(cleanHost).ico",
        ]
    }

    public static func fetchRemoteLogo(plan: FetchPlan) async -> UIImage? {
        for url in plan.urls {
            guard let payload = await fetchLogoPayload(from: url), isUsableLogo(payload) else { continue }
            let normalized = normalizeForDisplay(payload.image)
            LightweightLogoCache.shared.saveImage(normalized, forKey: plan.cacheKey)
            return normalized
        }
        MerchantLogoNegativeCache.markFailure(plan.cacheKey)
        return nil
    }

    private struct LogoPayload {
        let data: Data
        let image: UIImage
        let source: LogoSourceKind
    }

    private enum LogoSourceKind {
        case duckDuckGo
        case google

        init(url: URL) {
            let host = url.host?.lowercased() ?? ""
            if host.contains("duckduckgo.com") {
                self = .duckDuckGo
            } else {
                self = .google
            }
        }
    }

    private static func fetchLogoPayload(from url: URL) async -> LogoPayload? {
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 4)
        request.httpShouldHandleCookies = false
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return nil
            }
            guard let image = decodeLogoImage(from: data) else { return nil }
            return LogoPayload(data: data, image: image, source: LogoSourceKind(url: url))
        } catch {
            return nil
        }
    }

    /// UIImage often fails on `.ico` — ImageIO handles DuckDuckGo responses.
    static func decodeLogoImage(from data: Data) -> UIImage? {
        guard !data.isEmpty else { return nil }
        if let image = UIImage(data: data) { return image }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        var bestImage: UIImage?
        var bestPixels: CGFloat = 0

        for index in 0 ..< count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let image = UIImage(cgImage: cgImage)
            let px = max(image.size.width, image.size.height) * image.scale
            if px > bestPixels {
                bestPixels = px
                bestImage = image
            }
        }

        return bestImage
    }

    private static func isUsableLogo(_ payload: LogoPayload) -> Bool {
        let px = pixelSize(of: payload.image)
        guard px >= 16, payload.data.count >= 48 else { return false }
        return true
    }

    /// Rank candidates — largest crisp source wins (penalize tiny API globes).
    private static func logoQualityScore(_ payload: LogoPayload) -> CGFloat {
        var score = pixelSize(of: payload.image)

        switch payload.source {
        case .google:
            if score <= 40 { score *= 0.35 }
        case .duckDuckGo:
            if score <= 40 { score *= 0.45 }
        }

        return score
    }

    /// Downscale very large assets for cache; never upscale (upscaling blurs tiny favicons).
    private static func normalizeForDisplay(_ image: UIImage) -> UIImage {
        let px = pixelSize(of: image)
        guard px > 320 else { return image }

        let target: CGFloat = 256
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format)
        return renderer.image { _ in
            let aspect = min(target / image.size.width, target / image.size.height)
            let w = image.size.width * aspect
            let h = image.size.height * aspect
            let rect = CGRect(x: (target - w) / 2, y: (target - h) / 2, width: w, height: h)
            image.draw(in: rect)
        }
    }

    private static func pixelSize(of image: UIImage) -> CGFloat {
        max(image.size.width, image.size.height) * image.scale
    }
}

// MARK: - Local Cache Manager
public final class LightweightLogoCache: @unchecked Sendable {
    public nonisolated static let shared = LightweightLogoCache()

    private nonisolated(unsafe) var memoryCache = NSCache<NSString, UIImage>()
    private nonisolated(unsafe) var lruList: [String] = []
    private nonisolated let maxMemoryCount = 50
    private nonisolated let maxDiskSize: Int = 10 * 1024 * 1024 // 10 MB
    /// All memory + disk + LRU mutations run on one queue (fixes EXC_BAD_ACCESS from concurrent `lruList` access).
    private nonisolated let cacheQueue = DispatchQueue(label: "com.buxmuse.app.merchant-logo-cache")

    private nonisolated init() {
        memoryCache.countLimit = maxMemoryCount
        removeLegacySharedLogoArtifacts()
    }

    private nonisolated func diskCacheDirectoryURL() -> URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("BuxMuseMerchantLogosV5")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }

    public nonisolated func getImage(forKey key: String) -> UIImage? {
        cacheQueue.sync {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedKey.isEmpty else { return nil }
            let nsKey = trimmedKey as NSString

            if let memoryImage = memoryCache.object(forKey: nsKey) {
                touchLRU(trimmedKey)
                return memoryImage
            }

            let fileURL = diskCacheDirectoryURL().appendingPathComponent(trimmedKey.cacheFilename())
            if let fileData = try? Data(contentsOf: fileURL),
               let diskImage = UIImage(data: fileData) {
                memoryCache.setObject(diskImage, forKey: nsKey)
                touchLRU(trimmedKey)
                return diskImage
            }
            return nil
        }
    }

    public nonisolated func saveImage(_ image: UIImage, forKey key: String) {
        cacheQueue.async { [weak self] in
            guard let self else { return }
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedKey.isEmpty else { return }
            let nsKey = trimmedKey as NSString

            self.memoryCache.setObject(image, forKey: nsKey)
            self.touchLRU(trimmedKey)

            let fileURL = self.diskCacheDirectoryURL().appendingPathComponent(trimmedKey.cacheFilename())
            if let imageData = image.pngData() {
                try? imageData.write(to: fileURL)
                self.pruneDiskCacheIfNeeded()
            }
        }
    }

    private nonisolated func touchLRU(_ key: String) {
        if let idx = lruList.firstIndex(of: key) {
            lruList.remove(at: idx)
        }
        lruList.append(key)
        if lruList.count > maxMemoryCount {
            let removedKey = lruList.removeFirst()
            memoryCache.removeObject(forKey: removedKey as NSString)
        }
    }

    public nonisolated func clearCache() {
        clearCacheSynchronously()
    }

    /// Used during Settings → Delete all data so stale favicons cannot survive a reset.
    public nonisolated func clearCacheSynchronously() {
        cacheQueue.sync {
            memoryCache.removeAllObjects()
            lruList.removeAll()
            removeAllLogoCacheDirectories()
        }
    }

    private nonisolated func removeAllLogoCacheDirectories() {
        let manager = FileManager.default
        guard let caches = manager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        for folder in ["BuxMuseMerchantLogos", "BuxMuseMerchantLogosV3", "BuxMuseMerchantLogosV4", "BuxMuseMerchantLogosV5"] {
            let dir = caches.appendingPathComponent(folder, isDirectory: true)
            if manager.fileExists(atPath: dir.path) {
                try? manager.removeItem(at: dir)
            }
        }
    }

    private nonisolated func pruneDiskCacheIfNeeded() {
        let dir = diskCacheDirectoryURL()
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return }

        var fileInfos: [(url: URL, size: Int, date: Date)] = []
        var totalSize = 0

        for file in files {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = values?.fileSize ?? 0
            let date = values?.contentModificationDate ?? Date.distantPast
            fileInfos.append((url: file, size: size, date: date))
            totalSize += size
        }

        if totalSize > maxDiskSize {
            fileInfos.sort(by: { $0.date < $1.date })
            for file in fileInfos {
                if totalSize <= Int(Double(maxDiskSize) * 0.8) { break }
                try? manager.removeItem(at: file.url)
                totalSize -= file.size
            }
        }
    }

    /// Older builds wrote every empty-key logo to `merchant.png`, which made unrelated merchants share one image.
    private nonisolated func removeLegacySharedLogoArtifacts() {
        let manager = FileManager.default
        guard let caches = manager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        for folder in ["BuxMuseMerchantLogosV4", "BuxMuseMerchantLogosV3", "BuxMuseMerchantLogos"] {
            let legacy = caches.appendingPathComponent(folder).appendingPathComponent("merchant.png")
            try? manager.removeItem(at: legacy)
        }
    }
}

// MARK: - Helpers
extension String {
    nonisolated fileprivate func cacheFilename() -> String {
        let digest = SHA256.hash(data: Data(utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return hex + ".png"
    }
}

extension Character {
    fileprivate nonisolated var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value >= 0x203C || scalar.properties.isEmojiPresentation)
    }
}
