//
//  MerchantBrandRegionalEntries.swift
//  BuxMuse
//
//  Regional retailer / bank / telco domains — data-only expansion layer.
//

import Foundation

enum MerchantBrandRegionalEntries {
    nonisolated static let all: [MerchantBrandEntry] = dominicanRepublic
        + mexico
        + spain
        + latinAmerica
        + unitedStates
        + europe
        + unitedKingdomExtra
        + globalServices

    // MARK: - Dominican Republic

    private nonisolated static let dominicanRepublic: [MerchantBrandEntry] = [
        entry("La Sirena", "sirena.do", ["La Sirena", "Supermercados La Sirena", "Sirena"], ["DO"]),
        entry("Jumbo", "jumbo.com.do", ["Jumbo", "Jumbo RD"], ["DO"]),
        entry("Nacional", "supermercadosnacional.com", ["Nacional", "Supermercados Nacional", "Supermercado Nacional"], ["DO"]),
        entry("Bravo", "bravo.com.do", ["Bravo", "Supermercados Bravo"], ["DO"]),
        entry("Olé", "ole.com.do", ["Olé", "Ole", "Supermercados Olé"], ["DO"]),
        entry("Plaza Lama", "plazalama.com.do", ["Plaza Lama", "PlazaLama"], ["DO"]),
        entry("Banreservas", "banreservas.com.do", ["Banreservas", "Banco de Reservas"], ["DO"]),
        entry("BHD León", "bhd.com.do", ["BHD", "BHD León", "BHD Leon", "Banco BHD"], ["DO"]),
        entry("Banco Popular", "popularenlinea.com", ["Banco Popular", "Popular", "Popular Dominicano"], ["DO"]),
        entry("APAP", "apap.com.do", ["APAP", "Asociación Popular"], ["DO"]),
        entry("Scotiabank RD", "scotiabank.com.do", ["Scotiabank", "Scotiabank RD"], ["DO"]),
        entry("Claro RD", "clarord.com.do", ["Claro", "Claro RD", "Claro Dominicana"], ["DO"]),
        entry("Altice", "altice.com.do", ["Altice", "Altice Dominicana"], ["DO"]),
        entry("Edenorte", "edenorte.com.do", ["Edenorte"], ["DO"]),
        entry("Edesur", "edesur.com.do", ["Edesur"], ["DO"]),
        entry("Edeeste", "edeeste.com.do", ["Edeeste"], ["DO"]),
        entry("PriceSmart RD", "pricesmart.com", ["PriceSmart", "Pricesmart"], ["DO"]),
        entry("Carrefour RD", "carrefour.com.do", ["Carrefour", "Carrefour RD"], ["DO"]),
        entry("Farmacia Carol", "farmaciacarol.com", ["Carol", "Farmacia Carol"], ["DO"]),
    ]

    // MARK: - Mexico

    private nonisolated static let mexico: [MerchantBrandEntry] = [
        entry("Oxxo", "oxxo.com", ["Oxxo", "Cadena Comercial Oxxo"], ["MX"]),
        entry("Soriana", "soriana.com", ["Soriana", "Tiendas Soriana"], ["MX"]),
        entry("Chedraui", "chedraui.com.mx", ["Chedraui", "Chedraui Selecto"], ["MX"]),
        entry("Liverpool", "liverpool.com.mx", ["Liverpool", "El Puerto de Liverpool"], ["MX"]),
        entry("Coppel", "coppel.com", ["Coppel", "Tiendas Coppel"], ["MX"]),
        entry("Telcel", "telcel.com", ["Telcel", "América Móvil"], ["MX"]),
        entry("Bodega Aurrera", "bodegaaurrera.com.mx", ["Bodega Aurrera", "Aurrera"], ["MX"]),
        entry("Walmart México", "walmart.com.mx", ["Walmart Mexico", "Walmart MX", "Walmart de Mexico"], ["MX"]),
        entry("Sam's Club MX", "sams.com.mx", ["Sam's Club", "Sams Club Mexico"], ["MX"]),
        entry("Costco México", "costco.com.mx", ["Costco Mexico", "Costco MX"], ["MX"]),
        entry("La Comer", "lacomer.com.mx", ["La Comer", "LaComer"], ["MX"]),
        entry("HEB México", "heb.com.mx", ["HEB Mexico", "H-E-B Mexico"], ["MX"]),
        entry("7-Eleven México", "7-eleven.com.mx", ["7-Eleven", "7 Eleven Mexico"], ["MX"]),
        entry("BBVA México", "bbva.mx", ["BBVA Mexico", "BBVA Bancomer", "Bancomer"], ["MX"]),
        entry("Banorte", "banorte.com", ["Banorte", "Banco Mercantil del Norte"], ["MX"]),
        entry("Citibanamex", "banamex.com", ["Banamex", "Citibanamex", "Citi Banamex"], ["MX"]),
        entry("Santander México", "santander.com.mx", ["Santander Mexico", "Santander MX"], ["MX"]),
        entry("Banco Azteca", "bancoazteca.com.mx", ["Banco Azteca", "Azteca"], ["MX"]),
        entry("Rappi", "rappi.com.mx", ["Rappi", "Rappi Mexico"], ["MX"]),
        entry("Mercado Libre MX", "mercadolibre.com.mx", ["Mercado Libre", "MercadoLibre", "Mercado Pago"], ["MX"]),
        entry("Palacio de Hierro", "elpalaciodehierro.com", ["Palacio de Hierro", "El Palacio de Hierro"], ["MX"]),
        entry("Suburbia", "suburbia.com.mx", ["Suburbia"], ["MX"]),
        entry("Office Depot MX", "officedepot.com.mx", ["Office Depot Mexico"], ["MX"]),
        entry("Pemex", "pemex.com", ["Pemex"], ["MX"]),
        entry("AT&T México", "att.com.mx", ["AT&T Mexico", "ATT Mexico"], ["MX"]),
    ]

    // MARK: - Spain

    private nonisolated static let spain: [MerchantBrandEntry] = [
        entry("Mercadona", "mercadona.es", ["Mercadona"], ["ES"]),
        entry("Carrefour España", "carrefour.es", ["Carrefour", "Carrefour ES", "Carrefour España"], ["ES"]),
        entry("El Corte Inglés", "elcorteingles.es", ["El Corte Inglés", "El Corte Ingles", "Corte Ingles", "Hipercor"], ["ES"]),
        entry("Dia España", "dia.es", ["Dia", "Supermercados Dia"], ["ES"]),
        entry("Lidl España", "lidl.es", ["Lidl", "Lidl ES"], ["ES"]),
        entry("Alcampo", "alcampo.es", ["Alcampo"], ["ES"]),
        entry("Eroski", "eroski.es", ["Eroski", "Eroski City"], ["ES"]),
        entry("Consum", "consum.es", ["Consum", "Supermercados Consum"], ["ES"]),
        entry("Repsol", "repsol.es", ["Repsol"], ["ES"]),
        entry("Cepsa", "cepsa.es", ["Cepsa"], ["ES"]),
        entry("BBVA España", "bbva.es", ["BBVA", "BBVA ES"], ["ES"]),
        entry("Santander España", "santander.es", ["Santander", "Banco Santander"], ["ES"]),
        entry("CaixaBank", "caixabank.es", ["CaixaBank", "La Caixa"], ["ES"]),
        entry("Movistar", "movistar.es", ["Movistar"], ["ES"]),
        entry("Orange España", "orange.es", ["Orange", "Orange ES"], ["ES"]),
        entry("Vodafone España", "vodafone.es", ["Vodafone", "Vodafone ES"], ["ES"]),
        entry("Mango", "mango.com", ["Mango"], ["ES"]),
        entry("MediaMarkt", "mediamarkt.es", ["MediaMarkt", "Media Markt"], ["ES"]),
        entry("PcComponentes", "pccomponentes.com", ["PcComponentes", "PC Componentes"], ["ES"]),
        entry("Iberia", "iberia.com", ["Iberia"], ["ES"]),
        entry("Renfe", "renfe.com", ["Renfe"], ["ES"]),
        entry("Cabify", "cabify.com", ["Cabify"], ["ES"]),
        entry("Glovo", "glovoapp.com", ["Glovo"], ["ES"]),
    ]

    // MARK: - Latin America (multi-country)

    private nonisolated static let latinAmerica: [MerchantBrandEntry] = [
        entry("Rappi", "rappi.com", ["Rappi"], []),
        entry("Mercado Libre", "mercadolibre.com", ["Mercado Libre", "MercadoLibre", "Mercado Pago"], []),
        entry("Falabella", "falabella.com", ["Falabella"], ["CL", "CO", "PE", "AR"]),
        entry("Ripley", "ripley.cl", ["Ripley"], ["CL", "PE"]),
        entry("Líder", "lider.cl", ["Lider", "Líder", "Walmart Chile"], ["CL"]),
        entry("Jumbo Chile", "jumbo.cl", ["Jumbo Chile", "Jumbo"], ["CL"]),
        entry("Tottus", "tottus.cl", ["Tottus"], ["CL", "PE"]),
        entry("Unimarc", "unimarc.cl", ["Unimarc"], ["CL"]),
        entry("Éxito", "exito.com", ["Exito", "Éxito", "Almacenes Éxito"], ["CO"]),
        entry("Carulla", "carulla.com", ["Carulla"], ["CO"]),
        entry("Bancolombia", "bancolombia.com", ["Bancolombia"], ["CO"]),
        entry("Davivienda", "davivienda.com", ["Davivienda"], ["CO"]),
        entry("Nubank", "nubank.com.br", ["Nubank", "Nu Pagamentos"], ["BR"]),
        entry("Itaú", "itau.com.br", ["Itau", "Itaú", "Banco Itau"], ["BR"]),
        entry("Bradesco", "bradesco.com.br", ["Bradesco"], ["BR"]),
        entry("Pão de Açúcar", "paodeacucar.com", ["Pao de Acucar", "Pão de Açúcar", "GPA"], ["BR"]),
        entry("Assaí", "assai.com.br", ["Assai", "Assaí", "Atacadão"], ["BR"]),
        entry("Magazine Luiza", "magazineluiza.com.br", ["Magazine Luiza", "Magalu"], ["BR"]),
        entry("Carrefour Brasil", "carrefour.com.br", ["Carrefour Brasil", "Carrefour BR"], ["BR"]),
        entry("Coto", "coto.com.ar", ["Coto", "Coto Digital"], ["AR"]),
        entry("Carrefour Argentina", "carrefour.com.ar", ["Carrefour Argentina", "Carrefour AR"], ["AR"]),
        entry("Banco Galicia", "bancogalicia.com", ["Galicia", "Banco Galicia"], ["AR"]),
        entry("BCP", "bcp.com.pe", ["BCP", "Banco de Credito", "Banco de Crédito"], ["PE"]),
        entry("Plaza Vea", "plazavea.com.pe", ["Plaza Vea", "PlazaVea"], ["PE"]),
        entry("Wong", "wong.pe", ["Wong"], ["PE"]),
        entry("Super Selectos", "superselectos.com", ["Super Selectos"], ["SV"]),
        entry("PriceSmart", "pricesmart.com", ["PriceSmart", "Pricesmart"], []),
        entry("Banco Popular Dominicano", "bpd.com.do", ["Banco Popular Dominicano", "BPD"], ["DO"]),
    ]

    // MARK: - United States

    private nonisolated static let unitedStates: [MerchantBrandEntry] = [
        entry("Costco", "costco.com", ["Costco", "Costco Wholesale"], ["US"]),
        entry("Kroger", "kroger.com", ["Kroger", "King Soopers", "Fry's", "Ralphs"], ["US"]),
        entry("Safeway", "safeway.com", ["Safeway"], ["US"]),
        entry("Publix", "publix.com", ["Publix"], ["US"]),
        entry("CVS", "cvs.com", ["CVS", "CVS Pharmacy"], ["US"]),
        entry("Walgreens", "walgreens.com", ["Walgreens"], ["US"]),
        entry("Home Depot", "homedepot.com", ["Home Depot", "The Home Depot"], ["US"]),
        entry("Lowe's", "lowes.com", ["Lowes", "Lowe's"], ["US"]),
        entry("Whole Foods", "wholefoodsmarket.com", ["Whole Foods", "Wholefoods"], ["US"]),
        entry("Trader Joe's", "traderjoes.com", ["Trader Joe's", "Trader Joes"], ["US"]),
        entry("Chase", "chase.com", ["Chase", "JPMorgan Chase", "JP Morgan Chase"], ["US"]),
        entry("Bank of America", "bankofamerica.com", ["Bank of America", "BofA"], ["US"]),
        entry("Wells Fargo", "wellsfargo.com", ["Wells Fargo"], ["US"]),
        entry("Capital One", "capitalone.com", ["Capital One"], ["US"]),
        entry("American Express", "americanexpress.com", ["American Express", "Amex"], ["US"]),
        entry("DoorDash", "doordash.com", ["DoorDash", "Door Dash"], ["US"]),
        entry("Instacart", "instacart.com", ["Instacart"], ["US"]),
        entry("Amazon US", "amazon.com", ["Amazon", "Amazon.com", "AMZN"], ["US"]),
    ]

    // MARK: - Europe (non-UK/ES)

    private nonisolated static let europe: [MerchantBrandEntry] = [
        entry("REWE", "rewe.de", ["REWE", "Rewe"], ["DE"]),
        entry("Edeka", "edeka.de", ["Edeka"], ["DE"]),
        entry("Aldi DE", "aldi.de", ["Aldi Süd", "Aldi Nord", "Aldi DE"], ["DE"]),
        entry("Lidl DE", "lidl.de", ["Lidl DE", "Lidl Deutschland"], ["DE"]),
        entry("Leclerc", "e-leclerc.com", ["Leclerc", "E.Leclerc"], ["FR"]),
        entry("Intermarché", "intermarche.com", ["Intermarche", "Intermarché"], ["FR"]),
        entry("Monoprix", "monoprix.fr", ["Monoprix"], ["FR"]),
        entry("Carrefour FR", "carrefour.fr", ["Carrefour France", "Carrefour FR"], ["FR"]),
        entry("Albert Heijn", "ah.nl", ["Albert Heijn", "AH"], ["NL"]),
        entry("Jumbo NL", "jumbo.com", ["Jumbo"], ["NL"]),
        entry("ICA", "ica.se", ["ICA"], ["SE"]),
        entry("Coop Sweden", "coop.se", ["Coop", "Coop Sverige"], ["SE"]),
        entry("Migros", "migros.ch", ["Migros"], ["CH"]),
        entry("Coop CH", "coop.ch", ["Coop CH", "Coop Schweiz"], ["CH"]),
        entry("Esselunga", "esselunga.it", ["Esselunga"], ["IT"]),
        entry("Conad", "conad.it", ["Conad"], ["IT"]),
        entry("Tesco IE", "tesco.ie", ["Tesco Ireland"], ["IE"]),
        entry("Dunnes Stores", "dunnesstores.com", ["Dunnes", "Dunnes Stores"], ["IE"]),
    ]

    // MARK: - UK gaps

    private nonisolated static let unitedKingdomExtra: [MerchantBrandEntry] = [
        entry("Aldi UK", "aldi.co.uk", ["Aldi UK", "Aldi GB"], ["GB"]),
        entry("Lidl UK", "lidl.co.uk", ["Lidl UK", "Lidl GB"], ["GB"]),
        entry("HSBC UK", "hsbc.co.uk", ["HSBC", "HSBC UK"], ["GB"]),
        entry("Barclays", "barclays.co.uk", ["Barclays"], ["GB"]),
        entry("NatWest", "natwest.com", ["NatWest", "Nat West"], ["GB"]),
        entry("Lloyds", "lloydsbank.com", ["Lloyds", "Lloyds Bank"], ["GB"]),
        entry("Monzo", "monzo.com", ["Monzo"], ["GB"]),
        entry("Starling Bank", "starlingbank.com", ["Starling", "Starling Bank"], ["GB"]),
        entry("Shell UK", "shell.co.uk", ["Shell UK"], ["GB"]),
        entry("BP UK", "bp.com", ["BP UK"], ["GB"]),
        entry("Very", "very.co.uk", ["Very", "Very.co.uk", "Shop Direct"], ["GB"]),
        entry("Zopa", "zopa.com", ["Zopa", "Zopa Bank"], ["GB"]),
        entry("Wasabi", "wasabi.uk.com", ["Wasabi", "Wasabi Sushi"], ["GB"]),
        entry("Cursor", "cursor.com", ["Cursor", "Cursor IDE", "Cursor AI"], []),
        entry("Roblox", "roblox.com", ["Roblox", "Roblox Corp", "RBLX"], []),
        entry("Community Fibre", "communityfibre.co.uk", ["Community Fibre", "CommunityFibre"], ["GB"]),
        entry("VOXI", "voxi.co.uk", ["VOXI", "Voxi", "WWW.VOXI.COM", "Voxi Mobile"], ["GB"]),
    ]

    // MARK: - Global

    private nonisolated static let globalServices: [MerchantBrandEntry] = [
        entry("YouTube Premium", "youtube.com", ["YouTube", "YouTube Premium", "Google YouTube"], []),
        entry("HBO Max", "max.com", ["HBO", "HBO Max", "Max"], []),
        entry("Prime Video", "primevideo.com", ["Prime Video", "Amazon Prime Video"], []),
        entry("Adobe", "adobe.com", ["Adobe", "Adobe Creative Cloud"], []),
        entry("OpenAI", "openai.com", ["OpenAI", "ChatGPT"], []),
    ]

    private nonisolated static func entry(
        _ displayName: String,
        _ domain: String,
        _ tokens: [String],
        _ countries: [String]
    ) -> MerchantBrandEntry {
        MerchantBrandEntry(displayName: displayName, domain: domain, tokens: tokens, countries: countries)
    }
}
