//
//  WalletCategoryLexicon.swift
//  BuxMuse
//
//  Worldwide normalized tokens for on-device wallet transaction categorization.
//  Matching tokens are internal identifiers — never shown in UI.
//

import Foundation

enum WalletCategoryLexicon: Sendable {
    /// ISO 18245 MCC → BuxMuse category (worldwide standard).
    nonisolated static func category(forMCC code: Int) -> TransactionCategory? {
        switch code {
        // Groceries
        case 5411, 5422, 5441, 5451, 5462, 5499, 5921:
            return .groceries
        // Restaurants
        case 5811, 5812, 5813, 5814:
            return .restaurants
        // Transport
        case 4111, 4112, 4121, 4131, 4119, 4784, 4789, 5541, 5542, 5552, 7512, 7523:
            return .transport
        // Subscriptions / digital services
        case 4899, 5968, 7372, 7379, 5734, 5815, 5816, 5817, 5818:
            return .subscriptions
        // Housing
        case 6513, 7012:
            return .housing
        // Utilities
        case 4812, 4813, 4814, 4816, 4821, 4829, 4900:
            return .utilities
        // Entertainment
        case 7832, 7922, 7929, 7932, 7933, 7941, 7991, 7992, 7993, 7994, 7995, 7996, 7997, 7998, 7999:
            return .entertainment
        // Shopping
        case 5300, 5310, 5311, 5331, 5399, 5611, 5621, 5631, 5641, 5651, 5655, 5661, 5681, 5691, 5699,
             5712, 5719, 5722, 5732, 5733, 5735, 5931, 5941, 5942, 5943, 5944, 5945, 5946, 5947, 5948, 5949,
             5950, 5970, 5971, 5972, 5973, 5977, 5978, 5992, 5993, 5994, 5995, 5999, 5045, 5964, 5965, 5969:
            return .shopping
        // Health
        case 5912, 8011, 8021, 8031, 8041, 8042, 8043, 8044, 8049, 8050, 8062, 8071, 8099:
            return .health
        // Education
        case 8211, 8220, 8241, 8244, 8249, 8299, 8351:
            return .education
        // Personal care / services
        case 7230, 7297, 7298, 7210, 7211, 7216, 7221, 7251, 7261, 7273, 7276, 7277, 7278, 7299:
            return .personal
        // Travel
        case 3000...3299, 3500...3999, 4411, 4511, 4722, 7011, 7032, 7033, 7513, 7519:
            return .travel
        default:
            return nil
        }
    }

    nonisolated static let groceries: [String] =
        WalletGlobalMerchantRegistry.groceryStructureTokens + WalletGlobalMerchantRegistry.groceryRetailers

    nonisolated static let restaurants: [String] = [
        "starbucks", "mcdonald", "mcdonalds", "burger king", "wendy's", "wendys", "kfc", "subway",
        "chipotle", "taco bell", "domino", "pizza hut", "papa john", "five guys", "shake shack",
        "nandos", "nando", "greggs", "pret a manger", "pret", "costa coffee", "costa", "caffe nero",
        "dunkin", "panera", "olive garden", "applebee", "chili's", "chilis", "outback", "texas roadhouse",
        "restaurant", "restaurante", "restauracja", "cafe", "coffee", "bistro", "brasserie", "trattoria",
        "pizzeria", "sushi", "ramen", "diner", "grill", "steakhouse", "pub ", "gastropub", "taqueria",
        "kebab", "doner", "wok", "noodle", "bbq", "bar and grill", "food court", "eatery", "dining",
        "deliveroo", "ubereats", "uber eats", "doordash", "grubhub", "just eat", "justeat", "glovo",
        "rappi", "ifood", "swiggy", "zomato", "foodpanda", "wolt", "menulog", "seamless",
        "bakery", "patisserie", "ice cream", "gelato", "smoothie", "juice bar"
    ]

    nonisolated static let transport: [String] = [
        "uber", "lyft", "bolt", "cabify", "free now", "freenow", "grab", "didi", "ola", "via ",
        "shell", "chevron", "exxon", "mobil", "bp ", "texaco", "aral", "total energies", "totalenergies",
        "orlen", "repsol", "cepsa", "galp", "petrobras", "petronas", "esso", "sunoco", "marathon",
        "gas station", "fuel", "petrol", "diesel", "benzina", "carburant", "combustible", "gasolinera",
        "parking", "parkopedia", "toll", "peage", "autopista", "highway", "metro", "subway", "underground",
        "tube", "tfl", "transit", "tram", "bus ", "coach", "train", "railway", "renfe", "sncf", "bahn",
        "deutsche bahn", "amtrak", "clipper", "oyster", "omny", "ventra", "tap card", "transit authority",
        "lime scooter", "bird scooter", "tier mobility", "voi ", "car rental", "hertz", "avis", "enterprise rent",
        "zipcar", "turo", "sixt", "europcar"
    ]

    nonisolated static let subscriptions: [String] = [
        "netflix", "spotify", "hulu", "disney+", "disney plus", "apple.com/bill", "icloud", "apple music",
        "youtube premium", "youtubetv", "prime video", "amazon prime", "hbo", "paramount+", "peacock",
        "crunchyroll", "audible", "twitch", "patreon", "substack", "siriusxm", "pandora", "deezer", "tidal",
        "playstation", "xbox", "nintendo", "steam", "epic games", "adobe", "creative cloud", "canva", "figma",
        "microsoft 365", "office 365", "google one", "google storage", "dropbox", "slack", "zoom",
        "openai", "chatgpt", "notion", "github", "nordvpn", "expressvpn", "1password", "dashlane",
        "nytimes", "washington post", "wsj", "financial times", "economist", "peloton", "strava",
        "classpass", "duolingo", "headspace", "calm app", "planet fitness", "gym membership",
        "subscription", "suscripcion", "abonnement", "membership fee", "recurring"
    ]

    nonisolated static let housing: [String] = [
        "rent", "renta", "alquiler", "loyer", "miete", "mortgage", "hypothek", "hipoteca",
        "landlord", "property management", "apartment", "housing", "real estate", "inmobiliaria",
        "lease", "tenancy", "roommate", "airbnb host fee"
    ]

    nonisolated static let utilities: [String] = [
        "electric", "electricity", "power company", "energy bill", "gas bill", "water bill", "sewer",
        "utility", "utilities", "internet", "broadband", "fiber", "comcast", "xfinity", "verizon",
        "at&t", "att ", "t-mobile", "tmobile", "vodafone", "orange", "o2 ", "ee limited", "three uk",
        "spectrum", "cox communications", "centurylink", "frontier comm", "telefonica", "movistar",
        "telstra", "optus", "rogers", "bell canada", "hydro", "edf", "engie", "iberdrola", "endesa",
        "british gas", "octopus energy", "eon ", "rwe", "enel", "veolia"
    ]

    nonisolated static let entertainment: [String] = [
        "cinema", "cineplex", "movie", "theatre", "theater", "amc ", "regal cinema", "odeon", "vue cinema",
        "ticketmaster", "eventbrite", "stubhub", "gym", "fitness", "fitness club", "crossfit", "equinox",
        "puregym", "anytime fitness", "concert", "stadium", "arena", "museum", "zoo", "theme park",
        "disneyland", "legoland", "bowling", "arcade", "escape room", "sports club"
    ]

    nonisolated static let shopping: [String] = [
        "amazon", "amzn", "ebay", "etsy", "aliexpress", "alibaba", "shein", "temu", "wish.com",
        "target", "walmart", "best buy", "costco", "ikea", "home depot", "lowe's", "lowes",
        "argos", "currys", "media expert", "allegro", "zalando", "asos", "boohoo", "primark",
        "h&m", "zara", "nike", "adidas", "uniqlo", "decathlon", "dunelm", "john lewis", "next retail",
        "sephora", "ulta", "mac cosmetics", "department store", "retail", "outlet",
        "marketplace", "online store", "ecommerce", "e-commerce", "shopify", "mercado libre",
        "flipkart", "rakuten", "jd.com", "taobao", "shopee", "lazada", "noon.com", "b&Q", "wickes",
        "halfords", "screwfix", "action", "pepco", "tk maxx", "tj maxx", "marshalls", "ross stores"
    ]

    nonisolated static let health: [String] = [
        "pharmacy", "farmacia", "apotheke", "cvs", "walgreens", "boots pharmacy", "rite aid",
        "medical", "hospital", "clinic", "dentist", "dental", "doctor", "physician", "surgery",
        "healthcare", "optician", "optical", "vision care", "lenscrafters", "specsavers",
        "therapy", "physio", "chiropractic", "lab corp", "quest diag", "blood test"
    ]

    nonisolated static let travel: [String] = [
        "airline", "airways", "air ", "flight", "ryanair", "easyjet", "wizz air", "delta air", "united air",
        "american air", "british airways", "lufthansa", "air france", "klm", "emirates", "qatar air",
        "hotel", "marriott", "hilton", "hyatt", "ihg", "accor", "booking.com", "booking com",
        "expedia", "hotels.com", "airbnb", "hostel", "resort", "travel", "trip.com", "kayak", "skyscanner",
        "cruise", "car hire", "avis", "hertz", "turo"
    ]

    nonisolated static let education: [String] = [
        "university", "college", "tuition", "school", "academy", "udemy", "coursera", "edx",
        "skillshare", "masterclass", "education", "training course", "learning", "student",
        "matricula", "escuela", "universidad"
    ]

    nonisolated static let personal: [String] = [
        "salon", "haircut", "barber", "spa", "massage", "nail", "beauty", "laundry", "dry clean",
        "tailor", "alterations", "florist", "gift shop", "charity", "donation", "atm",
        "cash withdrawal", "cash withdraw", "withdrawal", "retrait", "retrait dab", "abhebung",
        "giro atm", "bancomat", "cajero", "efectivo"
    ]

    nonisolated static let p2pAndMoneyMovement: [String] = [
        "paypal", "venmo", "zelle", "cash app", "cashapp", "revolut", "wise", "transferwise",
        "monzo", "starling", "n26", "chime", "bizum", "twint", "swish", "vipps", "mb way",
        "interac", "eft ", "wire transfer", "bank transfer", "sepa", "spei", "pix ", "faster payment",
        "faster payments", "ach ", "zelle payment", "person to person", "p2p", "remittance",
        "western union", "moneygram", "remitly", "worldremit", "xoom"
    ]

    nonisolated static let bankInstitutions: [String] = WalletGlobalMerchantRegistry.financialInstitutions

    /// Label shapes that indicate a bank when no brand is in `bankInstitutions`.
    nonisolated static let financialInstitutionStructure: [String] =
        WalletGlobalMerchantRegistry.financialStructureTokens

    /// Banks/fintech on wallet labels — used to suppress bogus ISO MCC codes and retail fuzzy matches.
    nonisolated static func isFinancialInstitution(_ haystack: String) -> Bool {
        if matchesAny(haystack, bankInstitutions) { return true }
        if matchesAny(haystack, financialInstitutionStructure) { return true }
        return matchesInstitutionBankSuffix(haystack)
    }

    /// `Zopa Bank`, `Banco Santander` — not `Contactless Bank Card Tesco`.
    nonisolated static func matchesInstitutionBankSuffix(_ haystack: String) -> Bool {
        let trimmed = haystack.trimmingCharacters(in: .whitespacesAndNewlines)
        let retailSignals = groceries + restaurants + shopping + transport + health
        let suffixes = [
            " bank", " bank plc", " bank ltd", " bank limited", " bank uk",
            " banco", " banque", " banca", " sparkasse", " volksbank",
        ]
        if suffixes.contains(where: { trimmed.hasSuffix($0) }), !matchesAny(trimmed, retailSignals) {
            return true
        }
        let prefixes = ["banco ", "banque ", "banca ", "sparkasse ", "volksbank "]
        if prefixes.contains(where: { trimmed.hasPrefix($0) }), !matchesAny(trimmed, retailSignals) {
            return true
        }
        return false
    }

    /// MerchantCatalog display-name keys → category (built from catalog + extensions).
    nonisolated static let catalogBrandCategories: [String: TransactionCategory] = {
        var map: [String: TransactionCategory] = [:]
        func put(_ names: [String], _ category: TransactionCategory) {
            for name in names {
                let key = MerchantLogoEngine.normalizeMerchantName(name)
                guard !key.isEmpty else { continue }
                map[key] = category
            }
        }
        for entry in MerchantCatalog.entries {
            let category = categoryForCatalogEntry(entry)
            put(entry.searchNames + [entry.displayName], category)
        }
        put(WalletGlobalMerchantRegistry.financialInstitutions, .personal)
        put(WalletGlobalMerchantRegistry.groceryRetailers, .groceries)
        return map
    }()

    private nonisolated static func categoryForCatalogEntry(_ entry: MerchantCatalogEntry) -> TransactionCategory {
        let blob = (entry.displayName + " " + entry.searchNames.joined(separator: " ")).lowercased()
        if entry.domain.contains("boots") { return .health }
        if isFinancialInstitution(blob) || entry.domain.contains("bank") { return .personal }
        if matchesAny(blob, groceries) { return .groceries }
        if matchesAny(blob, restaurants) { return .restaurants }
        if matchesAny(blob, transport) { return .transport }
        if matchesAny(blob, subscriptions) { return .subscriptions }
        if matchesAny(blob, shopping) { return .shopping }
        if matchesAny(blob, travel) { return .travel }
        if matchesAny(blob, health) { return .health }
        if matchesAny(blob, entertainment) { return .entertainment }
        if entry.domain.contains("paypal") { return .personal }
        if entry.domain.contains("netflix") || entry.domain.contains("spotify") || entry.domain.contains("disney") {
            return .subscriptions
        }
        if entry.domain.contains("uber") && blob.contains("eats") { return .restaurants }
        if entry.domain.contains("uber") { return .transport }
        if entry.domain.contains("deliveroo") || entry.domain.contains("just-eat") { return .restaurants }
        if entry.domain.contains("ryanair") || entry.domain.contains("wizzair") || entry.domain.contains("booking") || entry.domain.contains("airbnb") {
            return .travel
        }
        return .shopping
    }

    nonisolated static func matchesAny(_ haystack: String, _ tokens: [String]) -> Bool {
        tokens.contains { containsLexiconToken(haystack, $0) }
    }

    /// Avoids false positives such as `chase` inside `purchase` or `rwe` inside `überweisung`.
    nonisolated static func containsLexiconToken(_ haystack: String, _ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        if token.contains(" ") || token.hasPrefix(" ") || token.hasSuffix(" ") {
            return haystack.contains(token)
        }
        return containsBoundedToken(haystack, token)
    }

    nonisolated static func containsBoundedToken(_ haystack: String, _ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        var searchStart = haystack.startIndex
        while searchStart < haystack.endIndex,
              let range = haystack.range(of: token, range: searchStart..<haystack.endIndex) {
            let beforeOK = range.lowerBound == haystack.startIndex
                || !isAlphanumeric(haystack[haystack.index(before: range.lowerBound)])
            let afterOK = range.upperBound == haystack.endIndex
                || !isAlphanumeric(haystack[range.upperBound])
            if beforeOK, afterOK { return true }
            searchStart = haystack.index(after: range.lowerBound)
        }
        return false
    }

    private nonisolated static func isAlphanumeric(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }

    nonisolated static func category(forBrandToken normalized: String, haystack: String) -> TransactionCategory? {
        if let hit = catalogBrandCategories[normalized] { return hit }
        for key in catalogBrandCategories.keys.sorted(by: { $0.count > $1.count }) where key.count >= 3 {
            guard let category = catalogBrandCategories[key] else { continue }
            if normalized == key || containsBoundedToken(normalized, key) {
                return category
            }
            if haystack == key || containsBoundedToken(haystack, key) {
                return category
            }
        }
        let checks: [(TransactionCategory, [String])] = [
            (.groceries, groceries),
            (.restaurants, restaurants),
            (.transport, transport),
            (.subscriptions, subscriptions),
            (.housing, housing),
            (.utilities, utilities),
            (.entertainment, entertainment),
            (.shopping, shopping),
            (.health, health),
            (.travel, travel),
            (.education, education),
            (.personal, personal)
        ]
        for (category, tokens) in checks where matchesAny(haystack, tokens) {
            return category
        }
        return nil
    }
}
