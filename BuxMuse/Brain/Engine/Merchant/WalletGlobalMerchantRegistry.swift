//
//  WalletGlobalMerchantRegistry.swift
//  BuxMuse
//
//  Worldwide bank + grocery/retail food tokens for on-device wallet categorization.
//  Tokens are internal matching identifiers — never shown in UI.
//

import Foundation

enum WalletGlobalMerchantRegistry: Sendable {
    // MARK: - Financial institutions (banks, neobanks, credit unions)

    nonisolated static let financialInstitutions: [String] = [
        // UK & Ireland
        "hsbc", "barclays", "natwest", "lloyds", "santander", "halifax", "nationwide", "monzo",
        "starling", "metro bank", "tsb", "first direct", "co-operative bank", "cooperative bank",
        "virgin money", "yorkshire bank", "clydesdale", "bank of scotland", "rbs",
        "royal bank of scotland", "handelsbanken", "zopa", "zopa bank", "atom bank", "chip",
        "plum", "nutmeg", "marcus by goldman sachs", "marcus", "tide", "anna money", "cashplus",
        "monese", "oaknorth", "paragon bank", "shawbrook", "aldermore", "metrobank", "chase uk",
        "kroo", "currensea", "bank of ireland", "aib", "allied irish", "permanent tsb", "ptsb",
        "ulster bank", "bank of ireland uk", "coutts", "cater allen", "investec", "close brothers",
        "newday", "capital one uk", "vanquis", "aqua", "fluid", "amex uk", "american express uk",
        // US & Canada
        "chase", "jpmorgan chase", "bank of america", "wells fargo", "citibank", "citi bank",
        "capital one", "usaa", "pnc bank", "td bank", "truist", "us bank", "fifth third",
        "regions bank", "huntington bank", "citizens bank", "keybank", "m&t bank", "bmo harris",
        "ally bank", "discover bank", "sofi", "chime", "varo", "current", "dave", "green dot",
        "go2bank", "mercury", "brex", "silicon valley bank", "first republic", "goldman sachs",
        "morgan stanley", "charles schwab", "fidelity", "vanguard", "td ameritrade", "etrade",
        "bank of montreal", "bmo", "scotiabank", "cibc", "rbc", "royal bank of canada",
        "national bank of canada", "desjardins", "laurentian bank", "tangerine", "simplii",
        "eq bank", "wealthsimple", "koho", "neo financial", "motusbank",
        // Western Europe
        "ing bank", "ing direct", "deutsche bank", "commerzbank", "bnp paribas", "credit agricole",
        "societe generale", "la banque postale", "credit mutuel", "lcl", "boursorama", "fortuneo",
        "n26", "trade republic", "bunq", "knab", "triodos", "rabobank", "abn amro", "sns bank",
        "nordea", "danske bank", "seb", "swedbank", "dnb", "sparebank", "bbva", "caixabank",
        "sabadell", "bankia", "unicredit", "intesa sanpaolo", "fineco", "ubs", "credit suisse",
        "postfinance", "raiffeisen", "erste bank", "kbc", "belfius", "ing belgie", "argenta",
        "bpost bank", "axa bank", "keytrade", "beobank", "crelan", "deutsche kreditbank", "dkb",
        "comdirect", "consorsbank", "1822direkt", "hypovereinsbank", "sparkasse", "volksbank",
        "landesbank", "caixa geral", "millennium bcp", "novo banco", "bankinter", "openbank",
        "ing espana", "caixa economica", "la caixa", "medirect", "bank of valletta",
        // Central / Eastern Europe
        "pko bank", "pko bp", "mbank", "ing polska", "santander bank polska", "pekao",
        "alior bank", "millennium bank", "credit agricole polska", "getin noble bank", "nest bank",
        "revolut poland", "toyota bank", "velobank", "credit europe bank", "raiffeisen polbank",
        "csob", "ceska sporitelna", "komercni banka", "fio banka", "moneta money bank",
        "otp bank", "k&h bank", "erste hungary", "raiffeisen hungary", "mbh bank",
        "brd", "banca transilvania", "raiffeisen romania", "bcr", "ing romania",
        "tbc bank", "bank of georgia", "liberty bank", "alpha bank", "eurobank", "piraeus bank",
        "national bank of greece", "optima bank", "fibank", "dsk bank", "postbank bulgaria",
        "privatbank", "monobank", "oschadbank", "ukrsibbank", "raiffeisen ukraine",
        // Nordics
        "nordea finland", "op financial", "aktia", "danske finland", "swedbank finland",
        "lansforsakringar", "ica banken", "skandiabanken", "avanza", "nordnet",
        // LATAM
        "nubank", "itau", "bradesco", "santander brasil", "banco do brasil", "inter bank",
        "banco inter", "caixa economica federal", "bb americas", "c6 bank", "original bank",
        "banco pan", "safra", "btg pactual", "banrisul", "sicoob", "sicredi",
        "banco de chile", "bancoestado", "bci", "scotiabank chile", "banco falabella",
        "bancolombia", "davivienda", "banco de bogota", "banco popular dominicano",
        "banorte", "bbva mexico", "citibanamex", "santander mexico", "banco azteca",
        "banamex", "inbursa", "banco galicia", "macro", "bbva argentina", "santander rio",
        "banco nacion", "bcp peru", "interbank", "scotiabank peru", "banco guayaquil",
        "produbanco", "banco pichincha", "banco del pacifico",
        // Middle East & Africa
        "emirates nbd", "fab", "adcb", "mashreq", "rakbank", "cbd", "dib", "hsbc uae",
        "qnb", "commercial bank of qatar", "doha bank", "al rajhi bank", "snb", "riyad bank",
        "alinma bank", "bank aljazira", "banque saudi fransi", "nbk", "gulf bank", "burgan bank",
        "bank hapoalim", "bank leumi", "discount bank", "first international bank",
        "standard bank", "absa", "fnb", "nedbank", "capitec", "investec south africa",
        "ecobank", "gtbank", "guaranty trust bank", "zenith bank", "access bank", "uba",
        "first bank of nigeria", "stanbic ibtc", "equity bank", "kcb", "cooperative bank kenya",
        "attijariwafa bank", "cih bank", "bmce bank", "banque populaire", "attijari bank",
        "banque misr", "cib egypt", "qnb alahli", "bank audi", "byblos bank",
        // Asia-Pacific
        "commonwealth bank", "commbank", "anz", "westpac", "nab", "macquarie", "bendigo bank",
        "bank of queensland", "suncorp bank", "ing australia", "up bank", "86 400", "ubank",
        "dbs", "ocbc", "uob", "maybank", "cimb", "standard chartered", "hsbc singapore",
        "posb", "bank of china", "icbc", "china construction bank", "agricultural bank of china",
        "bank of communications", "china merchants bank", "ping an bank", "citic bank",
        "industrial bank", "shanghai pudong development bank", "bank of east asia",
        "hang seng bank", "dbs hong kong", "icici", "hdfc", "axis bank", "kotak", "sbi",
        "state bank of india", "punjab national bank", "bank of baroda", "idfc first bank",
        "yes bank", "indusind bank", "paytm payments bank", "airtel payments bank",
        "federal bank", "rbl bank", "canara bank", "union bank of india", "icici bank",
        "mufg bank", "mizuho bank", "smbc", "sumitomo mitsui", "resona bank", "japan post bank",
        "rakuten bank", "sony bank", "seven bank", "sbi sumishin net bank", "aeon bank",
        "woori bank", "shinhan bank", "kb kookmin bank", "hana bank", "k bank", "kakao bank",
        "toss bank", "cathay united bank", "ctbc bank", "esun bank", "fubon bank",
        "bangkok bank", "kasikornbank", "krung thai bank", "scb", "siam commercial bank",
        "bank rakyat indonesia", "bri", "bank mandiri", "bca", "bank central asia",
        "bank negara indonesia", "bni", "cimb niaga", "maybank indonesia", "danamon",
        "public bank", "hong leong bank", "ambank", "rhb bank", "bank islam",
        "bank islam malaysia", "affin bank", "alliance bank", "vietcombank", "techcombank",
        "vietinbank", "bidv", "acb", "vpbank", "tpbank", "sacombank",
        // Fintech / money apps often on statements
        "revolut", "wise", "transferwise", "klarna bank", "paypal", "venmo", "zelle",
        "cash app", "cashapp", "remitly", "worldremit", "western union", "moneygram",
    ]

    /// Multilingual bank / credit-union shapes on wallet labels.
    nonisolated static let financialStructureTokens: [String] = [
        "building society", "credit union", "savings bank", "mutual bank", "digital bank",
        "neobank", "online bank", "mobile bank", "payments bank", "payment bank",
        "banco", "banque", "banca", "banque populaire", "caixa economica", "caixa geral",
        "caja de ahorros", "caja rural", "sparkasse", "volksbank", "raiffeisenbank",
        "genossenschaftsbank", "kreditunion", "sparebank", "girobank", "girokonto",
        "cooperative bank", "federal credit union", "community bank", "trust company",
        "merchant bank", "private bank", "islamic bank", "sharia bank",
    ]

    // MARK: - Grocery & food retail

    nonisolated static let groceryRetailers: [String] = [
        // UK & Ireland
        "tesco", "sainsbury", "sainsburys", "asda", "morrisons", "waitrose", "aldi", "lidl",
        "iceland", "coop", "co-op", "marks spencer", "m&s", "ocado", "farmfoods", "heron foods",
        "budgens", "londis", "spar uk", "nisa", "booker", "musgrave", "dunnes stores",
        "supervalu", "centra", "tesco ireland", "dunnes", "joyces supermarket",
        // US & Canada
        "whole foods", "wholefoods", "trader joe", "kroger", "safeway", "publix", "walmart",
        "costco", "sam's club", "sams club", "target grocery", "albertsons", "vons", "ralphs",
        "food lion", "giant food", "stop shop", "wegmans", "heb", "h-e-b", "meijer", "sprouts",
        "aldi us", "lidl us", "shoprite", "winco", "hy-vee", "hyvee", "piggly wiggly",
        "save a lot", "dollar general", "family dollar", "fresh market", "market basket",
        "harris teeter", "fred meyer", "king soopers", "smith's", "fry's food", "qfc",
        "loblaws", "no frills", "real canadian superstore", "superstore", "metro quebec",
        "sobeys", "safeway canada", "iga canada", "food basics", "freshco", "longos",
        "farm boy", "save on foods", "thrifty foods",
        // Western Europe
        "carrefour", "auchan", "leclerc", "intermarche", "monoprix", "franprix", "casino",
        "picard", "grand frais", "match", "simply market", "u express", "cora", "super u",
        "spar france", "edeka", "rewe", "penny", "netto", "kaufland", "real", "tegut",
        "famila", "combi", "nahkauf", "hit markt", "billa", "spar austria", "hofer",
        "mercadona", "eroski", "hipercor", "el corte ingles", "dia", "consum", "bonpreu",
        "caprabo", "alcampo", "eroski city", "supercor", "hiperdino", "spar españa",
        "conad", "esselunga", "coop italia", "eurospin", "pam", "despar", "iper",
        "carrefour italia", "lidl italia", "penny market", "md discount", "todis",
        "jumbo", "albert heijn", "ah to go", "plus", "dirk", "hoogvliet", "vomar", "dekamarkt",
        "colruyt", "okay", "bio planet", "delhaize", "carrefour belgium", "spar belgium",
        "migros", "coop ch", "denner", "aldi suisse", "lidl schweiz", "manor food",
        "coop sweden", "ica", "willys", "hemkop", "city gross", "lidl sweden", "tempo",
        "rema 1000", "kiwi", "meny", "coop extra", "joker", "bunnpris", "spar norway",
        "rema", "coop prix", "fotex", "bilka", "netto denmark", "fakta", "lidl denmark",
        "kesko", "k-market", "s-market", "prisma", "lidl finland", "alepa", "sale",
        // Central / Eastern Europe
        "biedronka", "zabka", "lidl pl", "dino polska", "groszek", "stokrotka", "lewiatan",
        "abc", "delikatesy centrum", "intermarche polska", "auchan polska", "carrefour polska",
        "tesco polska", "kaufland polska", "aldi polska", "netto polska", "selgros",
        "albert", "tesco cz", "billa cz", "penny cz", "globus", "coop cz", "lidl cz",
        "tesco sk", "billa sk", "coop jednota", "lidl sk", "kaufland sk",
        "tesco hu", "cba", "coop hungary", "lidl hu", "penny hu", "spar hu", "auchan hungary",
        "kaufland ro", "mega image", "profi", "lidl ro", "penny ro", "carrefour romania",
        "silpo", "atb", "varus", "novus", "metro ukraine", "ashan ukraine", "fozzy",
        "lidl bg", "fantastico", "billa bg", "kaufland bg", "t market",
        // Nordics already partly above
        // LATAM
        "oxxo", "7-eleven mexico", "soriana", "chedraui", "la comer", "heb mexico",
        "walmart mexico", "costco mexico", "sams club mexico", "casa ley",
        "carrefour brasil", "pao de acucar", "assai", "atacadao", "extra mercado",
        "carrefour argentina", "coto", "disco", "jumbo argentina", "vea", "carrefour chile",
        "lider", "jumbo chile", "tottus", "unimarc", "santa isabel", "wong", "plaza vea",
        "exito", "olimpica", "carulla", "jumbo colombia", "metro colombia", "la 14",
        "chedraui colombia", "walmart chile", "falabella supermarket",
        // Middle East & Africa
        "carrefour uae", "lulu hypermarket", "lulu", "spinneys", "waitrose uae", "choithrams",
        "union coop", "al maya", "geant", "hyperone", "seoudi", "metro egypt", "kazyon",
        "shoprite", "checkers", "pick n pay", "spar south africa", "woolworths sa",
        "food lovers market", "boxer", "usave", "game stores", "massmart", "makro",
        "carrefour egypt", "spinneys egypt", "seoudi market", "fathalla market",
        "naivas", "tuskys", "carrefour kenya", "chandarana", "game kenya",
        // Asia-Pacific
        "woolworths", "coles", "iga", "foodland", "pak n save", "countdown", "new world",
        "four square", "freshchoice", "supervalue", "harris farm", "drakes", "foodworks",
        "aldi australia", "costco australia", "kmart grocery", "big w food",
        "ntuc fairprice", "fairprice", "cold storage", "giant singapore", "sheng siong",
        "redmart", "don don donki", "meidi-ya", "jaya grocer", "aeon malaysia",
        "jaya jusco", "lotus's", "tesco lotus", "big c", "makro thailand", "tops supermarket",
        "villa market", "gourmet market", "foodland thailand", "familymart grocery",
        "7-eleven", "lawson", "familymart", "ministop", "seicomart", "don quijote",
        "aeon", "itoyokado", "life supermarket", "summit store", "maruetsu", "seiyu",
        "lotte mart", "emart", "homeplus", "gs25", "cu convenience", "ministop korea",
        "emart24", "nonghyup", "hanaro mart", "lotte super", "mega mart",
        "rt mart", "carrefour taiwan", "px mart", "simple mart", "wellcome", "parknshop",
        "park n shop", "fusion", "market place", "citysuper", "jasons", "manning grocery",
        "reliance fresh", "big bazaar", "dmart", "d-mart", "more megastore", "spencer's",
        "reliance smart", "star bazaar", "nature's basket", "foodhall", "metro cash carry",
        "spar india", "easyday", "vishal mega mart", "heritage fresh", "jiomart",
        "puregold", "sm supermarket", "robinsons supermarket", "rustan's", "landers",
        "shopwise", "alfamart", "indomaret", "hypermart", "transmart", "lotte mart indonesia",
        "hero supermarket", "giant indonesia", "aeon indonesia", "ranch market",
        "vinmart", "bach hoa xanh", "co.opmart", "saigon coop", "lotte mart vietnam",
        "aeon vietnam", "winmart", "circle k grocery",
    ]

    /// Multilingual grocery / supermarket shapes on wallet labels.
    nonisolated static let groceryStructureTokens: [String] = [
        "supermarket", "supermercado", "supermarche", "supermarché", "supermarkt",
        "hypermarket", "hyper marché", "hypermarche", "grocery", "groceries",
        "food market", "foodmart", "minimarket", "mini market", "epicerie", "épicerie",
        "alimentacion", "alimentación", "food hall", "fresh market", "market basket",
        "convenience store", "corner shop", "green grocer", "greengrocer",
        "cash and carry", "cash & carry", "wholesale club", "membership club",
        "tienda de alimentacion", "almacen", "bodega", "abarrotes", "mercado",
        "provision store", "provisions", "delicatessen", "deli ",
    ]
}
