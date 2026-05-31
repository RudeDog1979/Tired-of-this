//
//  MerchantLogoEngine.swift
//  BuxMuse
//  Brain/Engine/Logos/
//
//  Privacy-first Merchant Logo Caching and Resolution Engine.
//

import Foundation
import Combine
import ImageIO
#if canImport(UIKit)
import UIKit
#endif

public struct MerchantLogoEngine {
    
    // MARK: - Normalizer
    public static func normalizeMerchantName(_ name: String) -> String {
        var clean = name.lowercased()
        
        // Remove emojis
        clean = clean.filter { !$0.isEmoji }
        
        // Remove common suffixes
        let suffixes = ["ltd", "inc", "s.a.", "sa", "llc", "corp", "co", "incorporated", "limited"]
        for suffix in suffixes {
            let escaped = NSRegularExpression.escapedPattern(for: suffix)
            clean = clean.replacingOccurrences(of: "\\b\(escaped)\\b", with: "", options: .regularExpression)
        }
        
        // Remove punctuation & special chars
        clean = clean.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet.whitespaces).inverted).joined()
        
        // Trim edge and consecutive spaces
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return clean
    }
    
    // MARK: - Domain Resolver
    public static func resolveDomain(for merchantName: String) -> String? {
        if let catalogDomain = MerchantCatalog.domain(for: merchantName) {
            return catalogDomain
        }

        let normalized = normalizeMerchantName(merchantName)
        guard !normalized.isEmpty else { return nil }
        
        // Legacy inline map (kept for merchants not yet in catalog)
        let knownMerchants: [String: String] = [
            "starbucks": "starbucks.com",
            "apple": "apple.com",
            "netflix": "netflix.com",
            "spotify": "spotify.com",
            "uber": "uber.com",
            "amazon": "amazon.co.uk",
            "mcdonalds": "mcdonalds.com",
            "nike": "nike.com",
            "google": "google.com",
            "microsoft": "microsoft.com",
            "airbnb": "airbnb.com",
            "walmart": "walmart.com",
            "target": "target.com",
            "steam": "steampowered.com",
            "playstation": "playstation.com",
            "xbox": "xbox.com"
        ]
        
        if let directDomain = knownMerchants[normalized] {
            return directDomain
        }
        
        // Heuristic fallback: strip spaces and append .com
        let squished = normalized.replacingOccurrences(of: " ", with: "")
        if !squished.isEmpty {
            return "\(squished).com"
        }
        
        return nil
    }

    public static func googleFaviconURL(for domain: String, size: Int = 256) -> String {
        "https://www.google.com/s2/favicons?sz=\(size)&domain=\(domain)"
    }

    // MARK: - Remote logo fetch

    public struct FetchPlan: Sendable {
        public let cacheKey: String
        public let urls: [URL]
    }

    /// Domain-first cache key so "Biedronka" and typos share the same logo.
    public static func fetchPlan(for merchantName: String) -> FetchPlan? {
        let normalized = normalizeMerchantName(merchantName)
        guard !normalized.isEmpty else { return nil }

        let domain = resolveDomain(for: merchantName)
        let cacheKey = domain ?? normalized
        let host = domain ?? "\(normalized.replacingOccurrences(of: " ", with: "")).com"
        let urls = remoteLogoURLs(forHost: host).compactMap(URL.init(string:))
        guard !urls.isEmpty else { return nil }
        return FetchPlan(cacheKey: cacheKey, urls: urls)
    }

    /// Google first, DuckDuckGo fallback only.
    static func remoteLogoURLs(forHost host: String) -> [String] {
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
        var bestPayload: LogoPayload?
        var bestScore: CGFloat = 0

        await withTaskGroup(of: LogoPayload?.self) { group in
            for url in plan.urls {
                group.addTask { await fetchLogoPayload(from: url) }
            }

            for await payload in group {
                guard let payload, isUsableLogo(payload) else { continue }
                let score = logoQualityScore(payload)
                if score > bestScore {
                    bestScore = score
                    bestPayload = payload
                }
            }
        }

        guard let bestPayload else { return nil }
        let normalized = normalizeForDisplay(bestPayload.image)
        LightweightLogoCache.shared.saveImage(normalized, forKey: plan.cacheKey)
        return normalized
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
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
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
public final class LightweightLogoCache: ObservableObject {
    public static let shared = LightweightLogoCache()
    
    private var memoryCache = NSCache<NSString, UIImage>()
    private var lruList: [String] = []
    private let maxMemoryCount = 50
    private let maxDiskSize: Int = 10 * 1024 * 1024 // 10 MB
    
    private init() {
        memoryCache.countLimit = maxMemoryCount
    }
    
    private var diskCacheDirectory: URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("BuxMuseMerchantLogosV4")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }
    
    public func getImage(forKey key: String) -> UIImage? {
        let nsKey = key as NSString
        
        // 1. Check memory cache
        if let memoryImage = memoryCache.object(forKey: nsKey) {
            touchLRU(key)
            return memoryImage
        }
        
        // 2. Check disk cache
        let fileURL = diskCacheDirectory.appendingPathComponent(key.sanitizedFilename())
        if let fileData = try? Data(contentsOf: fileURL),
           let diskImage = UIImage(data: fileData) {
            // Put back in memory cache
            memoryCache.setObject(diskImage, forKey: nsKey)
            touchLRU(key)
            return diskImage
        }
        
        return nil
    }
    
    public func saveImage(_ image: UIImage, forKey key: String) {
        let nsKey = key as NSString
        
        // 1. Save to memory cache
        memoryCache.setObject(image, forKey: nsKey)
        touchLRU(key)
        
        // 2. Save to disk cache in background
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.diskCacheDirectory.appendingPathComponent(key.sanitizedFilename())
            if let imageData = image.pngData() {
                try? imageData.write(to: fileURL)
                self.pruneDiskCacheIfNeeded()
            }
        }
    }
    
    private func touchLRU(_ key: String) {
        if let idx = lruList.firstIndex(of: key) {
            lruList.remove(at: idx)
        }
        lruList.append(key)
        
        if lruList.count > maxMemoryCount {
            let removedKey = lruList.removeFirst()
            memoryCache.removeObject(forKey: removedKey as NSString)
        }
    }
    
    public func clearCache() {
        memoryCache.removeAllObjects()
        lruList.removeAll()
        let files = try? FileManager.default.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: nil)
        files?.forEach { try? FileManager.default.removeItem(at: $0) }
    }
    
    private func pruneDiskCacheIfNeeded() {
        let dir = diskCacheDirectory
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }
        
        var fileInfos: [(url: URL, size: Int, date: Date)] = []
        var totalSize = 0
        
        for file in files {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = values?.fileSize ?? 0
            let date = values?.contentModificationDate ?? Date.distantPast
            fileInfos.append((url: file, size: size, date: date))
            totalSize += size
        }
        
        // Evict if total size exceeds 10 MB limit
        if totalSize > maxDiskSize {
            // Sort by modification date (oldest first)
            fileInfos.sort(by: { $0.date < $1.date })
            
            for file in fileInfos {
                if totalSize <= Int(Double(maxDiskSize) * 0.8) {
                    break
                }
                try? manager.removeItem(at: file.url)
                totalSize -= file.size
            }
        }
    }
}

// MARK: - Helpers
extension String {
    fileprivate func sanitizedFilename() -> String {
        return self.components(separatedBy: CharacterSet.alphanumerics.inverted).joined() + ".png"
    }
}

extension Character {
    fileprivate var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value >= 0x203C || scalar.properties.isEmojiPresentation)
    }
}
