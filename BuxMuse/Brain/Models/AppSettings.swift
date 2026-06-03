//
//  AppSettings.swift
//  BuxMuse
//  Brain/Models/
//
//  Global Currency & Region settings model and persistence manager.
//  Supporting every single world currency recognized by ISO 4217.
//

import SwiftUI
import Combine

public struct CurrencySetting: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let flag: String
    public let symbol: String
    public let localeIdentifier: String
    
    public init(id: String, name: String, flag: String, symbol: String, localeIdentifier: String) {
        self.id = id
        self.name = name
        self.flag = flag
        self.symbol = symbol
        self.localeIdentifier = localeIdentifier
    }
}

public final class AppSettingsManager: ObservableObject {
    @Published public var selectedCurrency: CurrencySetting
    @Published public var selectedCountry: CountrySetting
    private let currencyKey = "selected_currency_id"
    private let countryKey = "selected_country_id"
    
    public static let availableCurrencies: [CurrencySetting] = [
        CurrencySetting(id: "AED", name: "UAE Dirham", flag: "🇦🇪", symbol: "د.إ", localeIdentifier: "ar_AE"),
        CurrencySetting(id: "AFN", name: "Afghan Afghani", flag: "🇦🇫", symbol: "؋", localeIdentifier: "ps_AF"),
        CurrencySetting(id: "ALL", name: "Albanian Lek", flag: "🇦🇱", symbol: "L", localeIdentifier: "sq_AL"),
        CurrencySetting(id: "AMD", name: "Armenian Dram", flag: "🇦🇲", symbol: "֏", localeIdentifier: "hy_AM"),
        CurrencySetting(id: "ANG", name: "Neth. Antillean Guilder", flag: "🇨🇼", symbol: "ƒ", localeIdentifier: "nl_CW"),
        CurrencySetting(id: "AOA", name: "Angolan Kwanza", flag: "🇦🇴", symbol: "Kz", localeIdentifier: "ln_AO"),
        CurrencySetting(id: "ARS", name: "Argentine Peso", flag: "🇦🇷", symbol: "$", localeIdentifier: "es_AR"),
        CurrencySetting(id: "AUD", name: "Australian Dollar", flag: "🇦🇺", symbol: "$", localeIdentifier: "en_AU"),
        CurrencySetting(id: "AWG", name: "Aruban Florin", flag: "🇦🇼", symbol: "Afl.", localeIdentifier: "nl_AW"),
        CurrencySetting(id: "AZN", name: "Azerbaijani Manat", flag: "🇦🇿", symbol: "₼", localeIdentifier: "az_AZ"),
        CurrencySetting(id: "BAM", name: "Bosnia-Herzegovina Mark", flag: "🇧🇦", symbol: "KM", localeIdentifier: "bs_BA"),
        CurrencySetting(id: "BBD", name: "Barbadian Dollar", flag: "🇧🇧", symbol: "$", localeIdentifier: "en_BB"),
        CurrencySetting(id: "BDT", name: "Bangladeshi Taka", flag: "🇧🇩", symbol: "৳", localeIdentifier: "bn_BD"),
        CurrencySetting(id: "BGN", name: "Bulgarian Lev", flag: "🇧🇬", symbol: "лв", localeIdentifier: "bg_BG"),
        CurrencySetting(id: "BHD", name: "Bahraini Dinar", flag: "🇧🇭", symbol: ".د.ب", localeIdentifier: "ar_BH"),
        CurrencySetting(id: "BIF", name: "Burundian Franc", flag: "🇧🇮", symbol: "FBu", localeIdentifier: "rn_BI"),
        CurrencySetting(id: "BMD", name: "Bermudian Dollar", flag: "🇧🇲", symbol: "$", localeIdentifier: "en_BM"),
        CurrencySetting(id: "BND", name: "Brunei Dollar", flag: "🇧🇳", symbol: "$", localeIdentifier: "ms_BN"),
        CurrencySetting(id: "BOB", name: "Bolivian Boliviano", flag: "🇧🇴", symbol: "Bs.", localeIdentifier: "es_BO"),
        CurrencySetting(id: "BRL", name: "Brazilian Real", flag: "🇧🇷", symbol: "R$", localeIdentifier: "pt_BR"),
        CurrencySetting(id: "BSD", name: "Bahamian Dollar", flag: "🇧🇸", symbol: "$", localeIdentifier: "en_BS"),
        CurrencySetting(id: "BTN", name: "Bhutanese Ngultrum", flag: "🇧🇹", symbol: "Nu.", localeIdentifier: "dz_BT"),
        CurrencySetting(id: "BWP", name: "Botswanan Pula", flag: "🇧🇼", symbol: "P", localeIdentifier: "en_BW"),
        CurrencySetting(id: "BYN", name: "Belarusian Ruble", flag: "🇧🇾", symbol: "Br", localeIdentifier: "be_BY"),
        CurrencySetting(id: "BZD", name: "Belize Dollar", flag: "🇧🇿", symbol: "$", localeIdentifier: "en_BZ"),
        CurrencySetting(id: "CAD", name: "Canadian Dollar", flag: "🇨🇦", symbol: "$", localeIdentifier: "en_CA"),
        CurrencySetting(id: "CDF", name: "Congolese Franc", flag: "🇨🇩", symbol: "FC", localeIdentifier: "fr_CD"),
        CurrencySetting(id: "CHF", name: "Swiss Franc", flag: "🇨🇭", symbol: "CHF", localeIdentifier: "de_CH"),
        CurrencySetting(id: "CLP", name: "Chilean Peso", flag: "🇨🇱", symbol: "$", localeIdentifier: "es_CL"),
        CurrencySetting(id: "CNY", name: "Chinese Yuan", flag: "🇨🇳", symbol: "¥", localeIdentifier: "zh_CN"),
        CurrencySetting(id: "COP", name: "Colombian Peso", flag: "🇨🇴", symbol: "$", localeIdentifier: "es_CO"),
        CurrencySetting(id: "CRC", name: "Costa Rican Colón", flag: "🇨🇷", symbol: "₡", localeIdentifier: "es_CR"),
        CurrencySetting(id: "CUP", name: "Cuban Peso", flag: "🇨🇺", symbol: "$", localeIdentifier: "es_CU"),
        CurrencySetting(id: "CVE", name: "Cape Verdean Escudo", flag: "🇨🇻", symbol: "Esc", localeIdentifier: "pt_CV"),
        CurrencySetting(id: "CZK", name: "Czech Koruna", flag: "🇨🇿", symbol: "Kč", localeIdentifier: "cs_CZ"),
        CurrencySetting(id: "DJF", name: "Djiboutian Franc", flag: "🇩🇯", symbol: "Fdj", localeIdentifier: "ar_DJ"),
        CurrencySetting(id: "DKK", name: "Danish Krone", flag: "🇩🇰", symbol: "kr", localeIdentifier: "da_DK"),
        CurrencySetting(id: "DOP", name: "Dominican Peso", flag: "🇩🇴", symbol: "$", localeIdentifier: "es_DO"),
        CurrencySetting(id: "DZD", name: "Algerian Dinar", flag: "🇩🇿", symbol: "د.ج", localeIdentifier: "ar_DZ"),
        CurrencySetting(id: "EGP", name: "Egyptian Pound", flag: "🇪🇬", symbol: "E£", localeIdentifier: "ar_EG"),
        CurrencySetting(id: "ERN", name: "Eritrean Nakfa", flag: "🇪🇷", symbol: "Nfk", localeIdentifier: "ti_ER"),
        CurrencySetting(id: "ETB", name: "Ethiopian Birr", flag: "🇪🇹", symbol: "Br", localeIdentifier: "am_ET"),
        CurrencySetting(id: "EUR", name: "Euro", flag: "🇪🇺", symbol: "€", localeIdentifier: "de_DE"),
        CurrencySetting(id: "FJD", name: "Fijian Dollar", flag: "🇫🇯", symbol: "$", localeIdentifier: "en_FJ"),
        CurrencySetting(id: "FKP", name: "Falkland Islands Pound", flag: "🇫🇰", symbol: "£", localeIdentifier: "en_FK"),
        CurrencySetting(id: "GBP", name: "British Pound", flag: "🇬🇧", symbol: "£", localeIdentifier: "en_GB"),
        CurrencySetting(id: "GEL", name: "Georgian Lari", flag: "🇬🇪", symbol: "₾", localeIdentifier: "ka_GE"),
        CurrencySetting(id: "GHS", name: "Ghanaian Cedi", flag: "🇬🇭", symbol: "₵", localeIdentifier: "ak_GH"),
        CurrencySetting(id: "GIP", name: "Gibraltar Pound", flag: "🇬🇮", symbol: "£", localeIdentifier: "en_GI"),
        CurrencySetting(id: "GMD", name: "Gambian Dalasi", flag: "🇬🇲", symbol: "D", localeIdentifier: "en_GM"),
        CurrencySetting(id: "GNF", name: "Guinean Franc", flag: "🇬🇳", symbol: "FG", localeIdentifier: "fr_GN"),
        CurrencySetting(id: "GTQ", name: "Guatemala Quetzal", flag: "🇬🇹", symbol: "Q", localeIdentifier: "es_GT"),
        CurrencySetting(id: "GYD", name: "Guyanese Dollar", flag: "🇬🇾", symbol: "$", localeIdentifier: "en_GY"),
        CurrencySetting(id: "HKD", name: "Hong Kong Dollar", flag: "🇭🇰", symbol: "$", localeIdentifier: "zh_HK"),
        CurrencySetting(id: "HNL", name: "Honduran Lempira", flag: "🇭🇳", symbol: "L", localeIdentifier: "es_HN"),
        CurrencySetting(id: "HRK", name: "Croatian Kuna", flag: "🇭🇷", symbol: "kn", localeIdentifier: "hr_HR"),
        CurrencySetting(id: "HTG", name: "Haitian Gourde", flag: "🇭🇹", symbol: "G", localeIdentifier: "fr_HT"),
        CurrencySetting(id: "HUF", name: "Hungarian Forint", flag: "🇭🇺", symbol: "Ft", localeIdentifier: "hu_HU"),
        CurrencySetting(id: "IDR", name: "Indonesian Rupiah", flag: "🇮🇩", symbol: "Rp", localeIdentifier: "id_ID"),
        CurrencySetting(id: "ILS", name: "Israeli Shekel", flag: "🇮🇱", symbol: "₪", localeIdentifier: "he_IL"),
        CurrencySetting(id: "INR", name: "Indian Rupee", flag: "🇮🇳", symbol: "₹", localeIdentifier: "en_IN"),
        CurrencySetting(id: "IQD", name: "Iraqi Dinar", flag: "🇮🇶", symbol: "ع.د", localeIdentifier: "ar_IQ"),
        CurrencySetting(id: "IRR", name: "Iranian Rial", flag: "🇮🇷", symbol: "﷼", localeIdentifier: "fa_IR"),
        CurrencySetting(id: "ISK", name: "Icelandic Króna", flag: "🇮🇸", symbol: "kr", localeIdentifier: "is_IS"),
        CurrencySetting(id: "JMD", name: "Jamaican Dollar", flag: "🇯🇲", symbol: "$", localeIdentifier: "en_JM"),
        CurrencySetting(id: "JOD", name: "Jordanian Dinar", flag: "🇯🇴", symbol: "د.ا", localeIdentifier: "ar_JO"),
        CurrencySetting(id: "JPY", name: "Japanese Yen", flag: "🇯🇵", symbol: "¥", localeIdentifier: "ja_JP"),
        CurrencySetting(id: "KES", name: "Kenyan Shilling", flag: "🇰🇪", symbol: "KSh", localeIdentifier: "sw_KE"),
        CurrencySetting(id: "KGS", name: "Kyrgyzstani Som", flag: "🇰🇬", symbol: "сом", localeIdentifier: "ky_KG"),
        CurrencySetting(id: "KHR", name: "Cambodian Riel", flag: "🇰🇭", symbol: "៛", localeIdentifier: "km_KH"),
        CurrencySetting(id: "KMF", name: "Comorian Franc", flag: "🇰🇲", symbol: "CF", localeIdentifier: "ar_KM"),
        CurrencySetting(id: "KPW", name: "North Korean Won", flag: "🇰🇵", symbol: "₩", localeIdentifier: "ko_KP"),
        CurrencySetting(id: "KRW", name: "South Korean Won", flag: "🇰🇷", symbol: "₩", localeIdentifier: "ko_KR"),
        CurrencySetting(id: "KWD", name: "Kuwaiti Dinar", flag: "🇰🇼", symbol: "د.ك", localeIdentifier: "ar_KW"),
        CurrencySetting(id: "KYD", name: "Cayman Islands Dollar", flag: "🇰🇾", symbol: "$", localeIdentifier: "en_KY"),
        CurrencySetting(id: "KZT", name: "Kazakhstani Tenge", flag: "🇰🇿", symbol: "₸", localeIdentifier: "kk_KZ"),
        CurrencySetting(id: "LAK", name: "Laotian Kip", flag: "🇱🇦", symbol: "₭", localeIdentifier: "lo_LA"),
        CurrencySetting(id: "LBP", name: "Lebanese Pound", flag: "🇱🇧", symbol: "ل.ل", localeIdentifier: "ar_LB"),
        CurrencySetting(id: "LKR", name: "Sri Lankan Rupee", flag: "🇱🇰", symbol: "Rs", localeIdentifier: "si_LK"),
        CurrencySetting(id: "LRD", name: "Liberian Dollar", flag: "🇱🇷", symbol: "$", localeIdentifier: "en_LR"),
        CurrencySetting(id: "LSL", name: "Lesotho Loti", flag: "🇱🇸", symbol: "L", localeIdentifier: "en_LS"),
        CurrencySetting(id: "LYD", name: "Libyan Dinar", flag: "🇱🇾", symbol: "د.ل", localeIdentifier: "ar_LY"),
        CurrencySetting(id: "MAD", name: "Moroccan Dirham", flag: "🇲🇦", symbol: "د.م.", localeIdentifier: "ar_MA"),
        CurrencySetting(id: "MDL", name: "Moldovan Leu", flag: "🇲🇩", symbol: "L", localeIdentifier: "ro_MD"),
        CurrencySetting(id: "MGA", name: "Malagasy Ariary", flag: "🇲🇬", symbol: "Ar", localeIdentifier: "mg_MG"),
        CurrencySetting(id: "MKD", name: "Macedonian Denar", flag: "🇲🇰", symbol: "ден", localeIdentifier: "mk_MK"),
        CurrencySetting(id: "MMK", name: "Myanmar Kyat", flag: "🇲🇲", symbol: "K", localeIdentifier: "my_MM"),
        CurrencySetting(id: "MNT", name: "Mongolian Tugrik", flag: "🇲🇳", symbol: "₮", localeIdentifier: "mn_MN"),
        CurrencySetting(id: "MOP", name: "Macanese Pataca", flag: "🇲🇴", symbol: "MOP$", localeIdentifier: "zh_MO"),
        CurrencySetting(id: "MRU", name: "Mauritanian Ouguiya", flag: "🇲🇷", symbol: "UM", localeIdentifier: "ar_MR"),
        CurrencySetting(id: "MUR", name: "Mauritian Rupee", flag: "🇲🇺", symbol: "₨", localeIdentifier: "en_MU"),
        CurrencySetting(id: "MVR", name: "Maldivian Rufiyaa", flag: "🇲🇻", symbol: "Rf", localeIdentifier: "dv_MV"),
        CurrencySetting(id: "MWK", name: "Malawian Kwacha", flag: "🇲🇼", symbol: "MK", localeIdentifier: "en_MW"),
        CurrencySetting(id: "MXN", name: "Mexican Peso", flag: "🇲🇽", symbol: "$", localeIdentifier: "es_MX"),
        CurrencySetting(id: "MYR", name: "Malaysian Ringgit", flag: "🇲🇾", symbol: "RM", localeIdentifier: "ms_MY"),
        CurrencySetting(id: "MZN", name: "Mozambican Metical", flag: "🇲🇿", symbol: "MT", localeIdentifier: "pt_MZ"),
        CurrencySetting(id: "NAD", name: "Namibian Dollar", flag: "🇳🇦", symbol: "$", localeIdentifier: "en_NA"),
        CurrencySetting(id: "NGN", name: "Nigerian Naira", flag: "🇳🇬", symbol: "₦", localeIdentifier: "en_NG"),
        CurrencySetting(id: "NIO", name: "Nicaraguan Córdoba", flag: "🇳🇮", symbol: "C$", localeIdentifier: "es_NI"),
        CurrencySetting(id: "NOK", name: "Norwegian Krone", flag: "🇳🇴", symbol: "kr", localeIdentifier: "nb_NO"),
        CurrencySetting(id: "NPR", name: "Nepalese Rupee", flag: "🇳🇵", symbol: "रू", localeIdentifier: "ne_NP"),
        CurrencySetting(id: "NZD", name: "New Zealand Dollar", flag: "🇳🇿", symbol: "$", localeIdentifier: "en_NZ"),
        CurrencySetting(id: "OMR", name: "Omani Rial", flag: "🇴🇲", symbol: "ر.ع.", localeIdentifier: "ar_OM"),
        CurrencySetting(id: "PAB", name: "Panamanian Balboa", flag: "🇵🇦", symbol: "B/.", localeIdentifier: "es_PA"),
        CurrencySetting(id: "PEN", name: "Peruvian Sol", flag: "🇵🇪", symbol: "S/.", localeIdentifier: "es_PE"),
        CurrencySetting(id: "PGK", name: "Papua New Guinean Kina", flag: "🇵🇬", symbol: "K", localeIdentifier: "en_PG"),
        CurrencySetting(id: "PHP", name: "Philippine Peso", flag: "🇵🇭", symbol: "₱", localeIdentifier: "fil_PH"),
        CurrencySetting(id: "PKR", name: "Pakistani Rupee", flag: "🇵🇰", symbol: "₨", localeIdentifier: "ur_PK"),
        CurrencySetting(id: "PLN", name: "Polish Zloty", flag: "🇵🇱", symbol: "zł", localeIdentifier: "pl_PL"),
        CurrencySetting(id: "PYG", name: "Paraguayan Guarani", flag: "🇵🇾", symbol: "₲", localeIdentifier: "gn_PY"),
        CurrencySetting(id: "QAR", name: "Qatari Rial", flag: "🇶🇦", symbol: "ر.ق", localeIdentifier: "ar_QA"),
        CurrencySetting(id: "RON", name: "Romanian Leu", flag: "🇷🇴", symbol: "lei", localeIdentifier: "ro_RON"),
        CurrencySetting(id: "RSD", name: "Serbian Dinar", flag: "🇷🇸", symbol: "дин.", localeIdentifier: "sr_RS"),
        CurrencySetting(id: "RUB", name: "Russian Ruble", flag: "🇷🇺", symbol: "₽", localeIdentifier: "ru_RU"),
        CurrencySetting(id: "RWF", name: "Rwandan Franc", flag: "🇷🇼", symbol: "FRw", localeIdentifier: "rw_RW"),
        CurrencySetting(id: "SAR", name: "Saudi Riyal", flag: "🇸🇦", symbol: "ر.س", localeIdentifier: "ar_SA"),
        CurrencySetting(id: "SBD", name: "Solomon Islands Dollar", flag: "🇸🇧", symbol: "$", localeIdentifier: "en_SB"),
        CurrencySetting(id: "SCR", name: "Seychellois Rupee", flag: "🇸🇨", symbol: "₨", localeIdentifier: "en_SC"),
        CurrencySetting(id: "SDG", name: "Sudanese Pound", flag: "🇸🇩", symbol: "ج.س.", localeIdentifier: "ar_SD"),
        CurrencySetting(id: "SEK", name: "Swedish Krona", flag: "🇸🇪", symbol: "kr", localeIdentifier: "sv_SE"),
        CurrencySetting(id: "SGD", name: "Singapore Dollar", flag: "🇸🇬", symbol: "$", localeIdentifier: "zh_SG"),
        CurrencySetting(id: "SHP", name: "Saint Helena Pound", flag: "🇸🇭", symbol: "£", localeIdentifier: "en_SH"),
        CurrencySetting(id: "SLL", name: "Sierra Leonean Leone", flag: "🇸🇱", symbol: "Le", localeIdentifier: "en_SL"),
        CurrencySetting(id: "SOS", name: "Somali Shilling", flag: "🇸🇴", symbol: "Sh", localeIdentifier: "so_SO"),
        CurrencySetting(id: "SRD", name: "Surinamese Dollar", flag: "🇸🇷", symbol: "$", localeIdentifier: "nl_SR"),
        CurrencySetting(id: "SSP", name: "South Sudanese Pound", flag: "🇸🇸", symbol: "£", localeIdentifier: "en_SS"),
        CurrencySetting(id: "STN", name: "São Tomé Dobra", flag: "🇸🇹", symbol: "Db", localeIdentifier: "pt_ST"),
        CurrencySetting(id: "SVC", name: "Salvadoran Colón", flag: "🇸🇻", symbol: "₡", localeIdentifier: "es_SV"),
        CurrencySetting(id: "SYP", name: "Syrian Pound", flag: "🇸🇾", symbol: "ل.س", localeIdentifier: "ar_SY"),
        CurrencySetting(id: "SZL", name: "Swazi Lilangeni", flag: "🇸🇿", symbol: "L", localeIdentifier: "en_SZ"),
        CurrencySetting(id: "THB", name: "Thai Baht", flag: "🇹🇭", symbol: "฿", localeIdentifier: "th_TH"),
        CurrencySetting(id: "TJS", name: "Tajikistani Somoni", flag: "🇹🇯", symbol: "SM", localeIdentifier: "tg_TJ"),
        CurrencySetting(id: "TMT", name: "Turkmenistani Manat", flag: "🇹🇲", symbol: "m", localeIdentifier: "tk_TM"),
        CurrencySetting(id: "TND", name: "Tunisian Dinar", flag: "🇹🇳", symbol: "د.ت", localeIdentifier: "ar_TN"),
        CurrencySetting(id: "TOP", name: "Tongan Paʻanga", flag: "🇹🇴", symbol: "T$", localeIdentifier: "to_TO"),
        CurrencySetting(id: "TRY", name: "Turkish Lira", flag: "🇹🇷", symbol: "₺", localeIdentifier: "tr_TR"),
        CurrencySetting(id: "TTD", name: "Trinidad Dollar", flag: "🇹🇹", symbol: "$", localeIdentifier: "en_TT"),
        CurrencySetting(id: "TWD", name: "New Taiwan Dollar", flag: "🇹🇼", symbol: "$", localeIdentifier: "zh_TW"),
        CurrencySetting(id: "TZN", name: "Tanzanian Shilling", flag: "🇹🇿", symbol: "TSh", localeIdentifier: "sw_TZ"),
        CurrencySetting(id: "UAH", name: "Ukrainian Hryvnia", flag: "🇺🇦", symbol: "₴", localeIdentifier: "uk_UA"),
        CurrencySetting(id: "UGX", name: "Ugandan Shilling", flag: "🇺🇬", symbol: "USh", localeIdentifier: "lg_UG"),
        CurrencySetting(id: "USD", name: "US Dollar", flag: "🇺🇸", symbol: "$", localeIdentifier: "en_US"),
        CurrencySetting(id: "UYU", name: "Uruguayan Peso", flag: "🇺🇾", symbol: "$", localeIdentifier: "es_UY"),
        CurrencySetting(id: "UZS", name: "Uzbekistani Som", flag: "🇺🇿", symbol: "so'm", localeIdentifier: "uz_UZ"),
        CurrencySetting(id: "VES", name: "Venezuelan Bolívar", flag: "🇻🇪", symbol: "Bs.S", localeIdentifier: "es_VE"),
        CurrencySetting(id: "VND", name: "Vietnamese Dong", flag: "🇻🇳", symbol: "₫", localeIdentifier: "vi_VN"),
        CurrencySetting(id: "VUV", name: "Vanuatu Vatu", flag: "🇻🇺", symbol: "VT", localeIdentifier: "bi_VU"),
        CurrencySetting(id: "WST", name: "Samoan Tala", flag: "🇼🇸", symbol: "WS$", localeIdentifier: "en_WS"),
        CurrencySetting(id: "XAF", name: "Central African CFA", flag: "🇨🇲", symbol: "FCFA", localeIdentifier: "fr_CM"),
        CurrencySetting(id: "XCD", name: "East Caribbean Dollar", flag: "🇩🇲", symbol: "$", localeIdentifier: "en_DM"),
        CurrencySetting(id: "XOF", name: "West African CFA", flag: "🇸🇳", symbol: "CFA", localeIdentifier: "fr_SN"),
        CurrencySetting(id: "XPF", name: "CFP Franc", flag: "🇵🇫", symbol: "₣", localeIdentifier: "fr_PF"),
        CurrencySetting(id: "YER", name: "Yemeni Rial", flag: "🇾🇪", symbol: "﷼", localeIdentifier: "ar_YE"),
        CurrencySetting(id: "ZAR", name: "South African Rand", flag: "🇿🇦", symbol: "R", localeIdentifier: "en_ZA"),
        CurrencySetting(id: "ZMW", name: "Zambian Kwacha", flag: "🇿🇲", symbol: "ZK", localeIdentifier: "en_ZM"),
        CurrencySetting(id: "ZWL", name: "Zimbabwean Dollar", flag: "🇿🇼", symbol: "$", localeIdentifier: "en_ZW")
    ]
    
    public init() {
        let resolvedCountry: CountrySetting
        if let storedCountryId = UserDefaults.standard.string(forKey: countryKey),
           let matchedCountry = CountryCatalog.country(for: storedCountryId) {
            resolvedCountry = matchedCountry
        } else {
            let detected = CountryCatalog.detectedFromDevice()
            resolvedCountry = detected
            UserDefaults.standard.set(detected.id, forKey: countryKey)
        }
        self.selectedCountry = resolvedCountry

        let defaultCurrencyCode = resolvedCountry.defaultCurrencyCode
        if let storedId = UserDefaults.standard.string(forKey: currencyKey),
           let matched = Self.availableCurrencies.first(where: { $0.id == storedId }) {
            self.selectedCurrency = matched
        } else if let suggested = Self.availableCurrencies.first(where: { $0.id == defaultCurrencyCode }) {
            self.selectedCurrency = suggested
            UserDefaults.standard.set(suggested.id, forKey: currencyKey)
        } else {
            self.selectedCurrency = Self.availableCurrencies.first(where: { $0.id == "USD" }) ?? Self.availableCurrencies[0]
        }
    }
    
    public func updateCurrency(_ currency: CurrencySetting) {
        applyCurrency(currency, persist: true)
    }

    public func updateCountry(_ country: CountrySetting, suggestCurrency: Bool = false) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            selectedCountry = country
        }
        UserDefaults.standard.set(country.id, forKey: countryKey)

        if suggestCurrency,
           let suggested = Self.availableCurrencies.first(where: { $0.id == country.defaultCurrencyCode }) {
            applyCurrency(suggested, persist: true)
        }
    }

    public func applyCurrency(_ currency: CurrencySetting, persist: Bool) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            self.selectedCurrency = currency
        }
        if persist {
            UserDefaults.standard.set(currency.id, forKey: currencyKey)
        }
    }

    /// UI string-catalog locale driven by **Settings → Country/Region**, not the device language.
    public var interfaceLocale: Locale {
        BuxInterfaceLocale.locale(for: selectedCountry)
    }
    
    /// Returns a pre-configured NumberFormatter for currency formatting
    public var formatter: NumberFormatter {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = selectedCurrency.id
        fmt.locale = Locale(identifier: selectedCurrency.localeIdentifier)
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return fmt
    }
    
    /// Formats a Decimal value using the active currency and regional settings
    public func format(_ amount: Decimal) -> String {
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(selectedCurrency.symbol)\(amount)"
    }
    
    /// Formats a double value
    public func format(_ amount: Double) -> String {
        return formatter.string(from: NSNumber(value: amount)) ?? "\(selectedCurrency.symbol)\(amount)"
    }

    public static var preferredCurrencyCode: String {
        UserDefaults.standard.string(forKey: "selected_currency_id") ?? "USD"
    }

    public static func currencySetting(for code: String) -> CurrencySetting {
        Self.availableCurrencies.first { $0.id == code } ?? Self.availableCurrencies.first { $0.id == "USD" }!
    }

    public static func format(amount: Decimal, currency: CurrencySetting) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = currency.id
        fmt.locale = Locale(identifier: currency.localeIdentifier)
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return fmt.string(from: amount as NSDecimalNumber) ?? "\(currency.symbol)\(amount)"
    }

    public static func format(amount: Double, currency: CurrencySetting) -> String {
        format(amount: Decimal(amount), currency: currency)
    }
}
