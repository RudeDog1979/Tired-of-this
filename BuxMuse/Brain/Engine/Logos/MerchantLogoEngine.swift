//
//  MerchantLogoEngine.swift
//  BuxMuse
//  Brain/Engine/Logos/
//
//  Privacy-first Merchant Logo Caching and Resolution Engine.
//

import SwiftUI
import Combine

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
        let normalized = normalizeMerchantName(merchantName)
        guard !normalized.isEmpty else { return nil }
        
        // Known merchant map
        let knownMerchants: [String: String] = [
            "starbucks": "starbucks.com",
            "apple": "apple.com",
            "netflix": "netflix.com",
            "spotify": "spotify.com",
            "uber": "uber.com",
            "amazon": "amazon.com",
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
        let dir = paths[0].appendingPathComponent("BuxMuseMerchantLogos")
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
