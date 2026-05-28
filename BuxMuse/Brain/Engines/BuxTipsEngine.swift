//
//  BuxTipsEngine.swift
//  BuxMuse
//
//  Fetches regional tips from remote JSON, caches locally, picks daily tip.
//

import Foundation

@MainActor
final class BuxTipsEngine {
    static let remoteURL = URL(string: "https://gist.githubusercontent.com/RudeDog1979/ed398f2397ca1a86ec6a53a1d72fb86a/raw/0d8f2c6e9d640c940bef37d963e792888ca03659/buxmuse_news.json")!

    private let cacheKey = "buxmuse.news.cache.v1"
    private let lastFetchKey = "buxmuse.news.lastFetch"
    private let seenTipKey = "buxmuse.news.seenTipId"
    private let refreshInterval: TimeInterval = 12 * 60 * 60

    private var payload: BuxMuseNewsPayload?
    private var isFetching = false

    init() {
        payload = loadCachedPayload() ?? loadBundledPayload()
    }

    func refreshIfNeeded(force: Bool = false) async {
        guard !isFetching else { return }
        let lastFetch = UserDefaults.standard.object(forKey: lastFetchKey) as? Date ?? .distantPast
        guard force || Date().timeIntervalSince(lastFetch) >= refreshInterval else { return }

        isFetching = true
        defer { isFetching = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: Self.remoteURL)
            let decoded = try JSONDecoder().decode(BuxMuseNewsPayload.self, from: data)
            payload = decoded
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: lastFetchKey)
        } catch {
            if payload == nil {
                payload = loadBundledPayload()
            }
        }
    }

    func dailyTip(for countryCode: String) -> DailyTipDisplay {
        let payload = payload ?? loadBundledPayload() ?? emptyPayload()
        let userCountry = countryCode.uppercased()
        let availableKeys = Set(payload.regions.keys)
        let contentRegion = BuxNewsRegionMapper.contentRegion(for: userCountry, availableKeys: availableKeys)
        guard let region = payload.regions[contentRegion] ?? payload.regions["DEFAULT"] else { return .empty }

        let dayKey = dayKeyString(for: Date())
        let id = "\(userCountry)-\(contentRegion)-\(dayKey)"

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: localeIdentifier(for: contentRegion))

        let moneyTip = DailyTipSection(
            kind: .moneyTip,
            title: BuxNewsRegionMapper.moneyTipTitle(for: contentRegion),
            body: region.home_tip
        )
        let watchOut: [DailyTipSection] = [
            DailyTipSection(kind: .scam, title: region.scam.title, body: region.scam.desc),
            DailyTipSection(kind: .security, title: region.alert.title, body: region.alert.desc)
        ]

        return DailyTipDisplay(
            id: id,
            regionCode: userCountry,
            regionFlag: flag(for: userCountry),
            dateLabel: formatter.string(from: Date()),
            contentRegion: contentRegion,
            watchOutHeader: BuxNewsRegionMapper.watchOutHeader(for: contentRegion),
            moneyTip: moneyTip,
            watchOut: watchOut
        )
    }

    func isTipUnseen(for countryCode: String) -> Bool {
        let tip = dailyTip(for: countryCode)
        guard !tip.isEmpty else { return false }
        return UserDefaults.standard.string(forKey: seenTipKey) != tip.id
    }

    func markTipSeen(_ tipId: String) {
        UserDefaults.standard.set(tipId, forKey: seenTipKey)
    }

    // MARK: - Private

    private func flag(for countryCode: String) -> String {
        CountryCatalog.flagEmoji(for: countryCode)
    }

    private func localeIdentifier(for contentRegion: String) -> String {
        switch contentRegion {
        case "ES": return "es_ES"
        case "FR": return "fr_FR"
        case "DE": return "de_DE"
        case "PT": return "pt_PT"
        case "IT": return "it_IT"
        case "NL": return "nl_NL"
        case "PL": return "pl_PL"
        case "SE": return "sv_SE"
        case "NO": return "nb_NO"
        case "DK": return "da_DK"
        case "FI": return "fi_FI"
        case "RU": return "ru_RU"
        case "UA": return "uk_UA"
        case "TR": return "tr_TR"
        case "JP": return "ja_JP"
        case "KR": return "ko_KR"
        case "CN": return "zh_CN"
        case "AE": return "ar_AE"
        case "IN": return "hi_IN"
        case "US": return "en_US"
        default: return "en_GB"
        }
    }

    private func dayKeyString(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func loadCachedPayload() -> BuxMuseNewsPayload? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(BuxMuseNewsPayload.self, from: data)
    }

    private func loadBundledPayload() -> BuxMuseNewsPayload? {
        guard let url = Bundle.main.url(forResource: "buxmuse_news", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BuxMuseNewsPayload.self, from: data)
    }

    private func emptyPayload() -> BuxMuseNewsPayload {
        BuxMuseNewsPayload(
            regions: [
                "DEFAULT": BuxNewsRegion(
                    home_tip: "For cheaper flights, search for fares on Tuesday or Wednesday afternoons.",
                    scam: BuxNewsAlertItem(title: "Romance Scams", desc: "Be wary of dating-app contacts who quickly ask for money."),
                    alert: BuxNewsAlertItem(title: "Phishing DMs", desc: "Avoid unsolicited social media links, even from known contacts."),
                    ticker: ["Global markets show mixed reactions to economic data."]
                )
            ],
            updatedAt: nil,
            version: 1
        )
    }
}
