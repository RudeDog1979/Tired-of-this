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
    
    @State private var image: UIImage? = nil
    @State private var loadedOpacity: Double = 0.0
    
    public init(merchantName: String, size: CGFloat = 44) {
        self.merchantName = merchantName
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            if let uiImage = image {
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
        .onAppear {
            loadLogo()
        }
        .onChange(of: merchantName) { oldValue, newValue in
            loadLogo()
        }
    }
    
    private func loadLogo() {
        let key = MerchantLogoEngine.normalizeMerchantName(merchantName)
        guard !key.isEmpty else { return }
        
        // 1. Instant cache hit
        if let cached = LightweightLogoCache.shared.getImage(forKey: key) {
            self.image = cached
            return
        }
        
        // 2. Resolve domain
        guard let domain = MerchantLogoEngine.resolveDomain(for: merchantName) else {
            return
        }
        
        // 3. Fetch in background asynchronously without blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            // Google API
            let googleUrl = URL(string: "https://www.google.com/s2/favicons?sz=256&domain=\(domain)")!
            
            // Build a privacy-safe URLRequest without cookies, analytics, or identifiers
            var request = URLRequest(url: googleUrl, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 5.0)
            request.httpShouldHandleCookies = false
            request.allHTTPHeaderFields = ["User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)"]
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let data = data,
                   let img = UIImage(data: data),
                   img.size.width > 16 { // Ensure it's a valid icon size, not empty pixel
                    LightweightLogoCache.shared.saveImage(img, forKey: key)
                    DispatchQueue.main.async {
                        self.image = img
                    }
                    return
                }
                
                // Fallback to DuckDuckGo API
                let ddgUrl = URL(string: "https://icons.duckduckgo.com/ip3/\(domain).ico")!
                var ddgRequest = URLRequest(url: ddgUrl, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 5.0)
                ddgRequest.httpShouldHandleCookies = false
                
                URLSession.shared.dataTask(with: ddgRequest) { data, response, error in
                    if let data = data,
                       let img = UIImage(data: data) {
                        LightweightLogoCache.shared.saveImage(img, forKey: key)
                        DispatchQueue.main.async {
                            self.image = img
                        }
                    }
                }.resume()
                
            }.resume()
        }
    }
    
    private var fallbackSymbol: String {
        let normalized = MerchantLogoEngine.normalizeMerchantName(merchantName)
        if normalized.contains("spotify") || normalized.contains("music") || normalized.contains("netflix") {
            return "arrow.triangle.2.circlepath" // subscription pattern
        } else if normalized.contains("uber") || normalized.contains("taxi") || normalized.contains("car") {
            return "car.fill"
        } else if normalized.contains("market") || normalized.contains("grocer") || normalized.contains("store") || normalized.contains("cart") {
            return "cart.fill"
        } else if normalized.contains("starbucks") || normalized.contains("coffee") || normalized.contains("restaurant") || normalized.contains("food") {
            return "fork.knife"
        }
        return "building.2.crop.circle"
    }
}
