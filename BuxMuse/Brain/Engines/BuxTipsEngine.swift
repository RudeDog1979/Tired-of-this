//
//  BuxTipsEngine.swift
//  BuxMuse
//
//  Fetches regional tips from remote JSON, caches locally, picks daily tip.
//

import Foundation

@MainActor
final class BuxTipsEngine {
    /// Always use `/raw/buxmuse_news.json` — never pin a gist revision SHA or updates never arrive.
    static let remoteURL = URL(string: "https://gist.githubusercontent.com/RudeDog1979/ed398f2397ca1a86ec6a53a1d72fb86a/raw/buxmuse_news.json")!

    /// Capital / primary zone per country when the device is outside that region.
    private static let primaryTimeZoneByCountry: [String: String] = [
        "AE": "Asia/Dubai", "AR": "America/Argentina/Buenos_Aires", "AT": "Europe/Vienna",
        "AU": "Australia/Sydney", "BE": "Europe/Brussels", "BR": "America/Sao_Paulo",
        "CA": "America/Toronto", "CH": "Europe/Zurich", "CL": "America/Santiago",
        "CN": "Asia/Shanghai", "CO": "America/Bogota", "CZ": "Europe/Prague",
        "DE": "Europe/Berlin", "DK": "Europe/Copenhagen", "DO": "America/Santo_Domingo",
        "EG": "Africa/Cairo", "ES": "Europe/Madrid", "FI": "Europe/Helsinki",
        "FR": "Europe/Paris", "GB": "Europe/London", "GR": "Europe/Athens",
        "HK": "Asia/Hong_Kong", "HU": "Europe/Budapest", "ID": "Asia/Jakarta",
        "IE": "Europe/Dublin", "IL": "Asia/Jerusalem", "IN": "Asia/Kolkata",
        "IT": "Europe/Rome", "JP": "Asia/Tokyo", "KE": "Africa/Nairobi",
        "KR": "Asia/Seoul", "MX": "America/Mexico_City", "MY": "Asia/Kuala_Lumpur",
        "NG": "Africa/Lagos", "NL": "Europe/Amsterdam", "NO": "Europe/Oslo",
        "NZ": "Pacific/Auckland", "PH": "Asia/Manila", "PL": "Europe/Warsaw",
        "PT": "Europe/Lisbon", "RO": "Europe/Bucharest", "RU": "Europe/Moscow",
        "SA": "Asia/Riyadh", "SE": "Europe/Stockholm", "SG": "Asia/Singapore",
        "TH": "Asia/Bangkok", "TR": "Europe/Istanbul", "TW": "Asia/Taipei",
        "UA": "Europe/Kyiv", "US": "America/New_York", "VN": "Asia/Ho_Chi_Minh",
        "ZA": "Africa/Johannesburg"
    ]

    private let cacheKey = "buxmuse.news.cache.v2"
    private let lastFetchTipDayKey = "buxmuse.news.lastFetchTipDay"
    private let seenTipKey = "buxmuse.news.seenTipId"
    private let dailyFetchHour = 6

    private var payload: BuxMuseNewsPayload?
    private var isFetching = false

    init() {
        payload = loadCachedPayload() ?? loadBundledPayload()
    }

    /// True when a remote fetch is due for this tip-day (after 6am local, not yet fetched today).
    func shouldFetchRemote(countryCode: String, force: Bool = false) -> Bool {
        if force { return true }
        let timeZone = regionalTimeZone(for: countryCode)
        let now = Date()
        let tipDay = currentTipDayKey(for: now, timeZone: timeZone)
        let lastFetchTipDay = UserDefaults.standard.string(forKey: lastFetchTipDayKey)
        let neverFetched = lastFetchTipDay == nil
        let reachedFetchTime = hasReachedDailyFetchTime(for: now, timeZone: timeZone)
        return (neverFetched && reachedFetchTime)
            || (lastFetchTipDay != tipDay && reachedFetchTime)
    }

    /// Fetches remote tips at most once per tip-day, after 6:00 in the user's local timezone.
    func refreshIfNeeded(countryCode: String, force: Bool = false) async {
        guard !isFetching else { return }
        guard shouldFetchRemote(countryCode: countryCode, force: force) else { return }

        let timeZone = regionalTimeZone(for: countryCode)
        let tipDay = currentTipDayKey(for: Date(), timeZone: timeZone)

        isFetching = true
        defer { isFetching = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: Self.remoteURL)
            let decoded = try JSONDecoder().decode(BuxMuseNewsPayload.self, from: data)
            payload = decoded
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(tipDay, forKey: lastFetchTipDayKey)
        } catch {
            if payload == nil {
                payload = loadBundledPayload()
            }
        }
    }

    /// True when a new 6am tip-day started since the last successful remote fetch.
    func isNewTipDaySinceLastFetch(countryCode: String) -> Bool {
        let timeZone = regionalTimeZone(for: countryCode)
        let tipDay = currentTipDayKey(for: Date(), timeZone: timeZone)
        let lastFetchTipDay = UserDefaults.standard.string(forKey: lastFetchTipDayKey)
        return lastFetchTipDay != tipDay
    }

    func dailyTip(for countryCode: String) -> DailyTipDisplay {
        let payload = payload ?? loadBundledPayload() ?? emptyPayload()
        let userCountry = countryCode.uppercased()
        let availableKeys = Set(payload.regions.keys)
        let contentRegion = BuxNewsRegionMapper.contentRegion(for: userCountry, availableKeys: availableKeys)
        guard let region = payload.regions[contentRegion] ?? payload.regions["DEFAULT"] else { return .empty }

        let timeZone = regionalTimeZone(for: countryCode)
        let now = Date()
        let tipDay = currentTipDayKey(for: now, timeZone: timeZone)
        let contentStamp = payload.updatedAt ?? tipDay
        let id = "\(userCountry)-\(contentRegion)-\(contentStamp)"

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: localeIdentifier(for: contentRegion))
        formatter.timeZone = timeZone
        let tipDayStart = tipDayStartDate(for: now, timeZone: timeZone)

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
            dateLabel: formatter.string(from: tipDayStart),
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

    /// Uses the device timezone when it matches the selected country; otherwise the country's primary zone.
    private func regionalTimeZone(for countryCode: String) -> TimeZone {
        let code = countryCode.uppercased()
        if Locale.current.region?.identifier.uppercased() == code {
            return TimeZone.current
        }
        if let id = Self.primaryTimeZoneByCountry[code],
           let timeZone = TimeZone(identifier: id) {
            return timeZone
        }
        return TimeZone.current
    }

    private func calendar(for timeZone: TimeZone) -> Calendar {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar
    }

    /// Tip-day rolls at 6:00 local. Before 6am we still show the previous day's tip.
    private func currentTipDayKey(for date: Date, timeZone: TimeZone) -> String {
        let calendar = calendar(for: timeZone)
        let hour = calendar.component(.hour, from: date)
        let anchor = hour >= dailyFetchHour
            ? date
            : (calendar.date(byAdding: .day, value: -1, to: date) ?? date)
        return dayKeyString(for: anchor, calendar: calendar)
    }

    private func hasReachedDailyFetchTime(for date: Date, timeZone: TimeZone) -> Bool {
        calendar(for: timeZone).component(.hour, from: date) >= dailyFetchHour
    }

    private func tipDayStartDate(for date: Date, timeZone: TimeZone) -> Date {
        let calendar = calendar(for: timeZone)
        let tipDay = currentTipDayKey(for: date, timeZone: timeZone)
        var components = DateComponents()
        components.year = Int(tipDay.prefix(4))
        components.month = Int(tipDay.dropFirst(5).prefix(2))
        components.day = Int(tipDay.suffix(2))
        components.hour = dailyFetchHour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? date
    }

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

    private func dayKeyString(for date: Date, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone
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

    // MARK: - Tips History

    private let historyKey = "buxmuse.tips.history"

    func saveTipToHistory(tip: DailyTipDisplay) {
        guard !tip.isEmpty else { return }
        var list = loadTipHistory()
        if !list.contains(where: { $0.id == tip.id }) {
            list.append(HistoricalTipRecord(
                id: tip.id,
                date: Date(),
                title: tip.moneyTip.title,
                message: tip.moneyTip.body
            ))
            if list.count > 7 {
                list.removeFirst(list.count - 7)
            }
            if let data = try? JSONEncoder().encode(list) {
                UserDefaults.standard.set(data, forKey: historyKey)
            }
        }
    }

    func loadTipHistory() -> [HistoricalTipRecord] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let list = try? JSONDecoder().decode([HistoricalTipRecord].self, from: data) else {
            return []
        }
        return list
    }
}
