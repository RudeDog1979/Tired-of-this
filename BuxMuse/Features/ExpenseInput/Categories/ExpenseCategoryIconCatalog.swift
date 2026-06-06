//
//  ExpenseCategoryIconCatalog.swift
//  BuxMuse
//

import Foundation

enum ExpenseCategoryIconCatalog {
    static let pickerIcons: [String] = [
        "tag.fill", "cart.fill", "fork.knife", "cup.and.saucer.fill", "wineglass.fill",
        "car.fill", "bus.fill", "airplane", "bed.double.fill", "building.2.fill",
        "house.fill", "bag.fill", "gift.fill", "heart.fill", "cross.case.fill",
        "bolt.fill", "drop.fill", "film.fill", "gamecontroller.fill", "book.fill",
        "graduationcap.fill", "briefcase.fill", "scissors", "pawprint.fill",
        "leaf.fill", "figure.run", "dumbbell.fill", "iphone", "creditcard.fill",
        "arrow.triangle.2.circlepath", "sparkles", "star.fill", "hammer.fill",
        "building.columns.fill", "banknote.fill", "dollarsign.circle.fill", "wallet.bifold.fill",
        "percent", "doc.text.fill", "receipt.fill", "chart.pie.fill", "chart.bar.fill",
        "fuelpump.fill", "tshirt.fill", "wifi", "shield.fill", "storefront.fill",
        "bicycle", "suitcase.fill", "tv.fill", "headphones", "play.tv.fill",
        "pills.fill", "stethoscope", "party.popper.fill", "birthday.cake.fill",
        "music.note", "ticket.fill", "paintbrush.fill", "wrench.and.screwdriver.fill",
        "flame.fill", "tree.fill", "key.fill", "lock.fill", "envelope.fill",
        "camera.fill", "sportscourt.fill", "tram.fill", "ferry.fill", "map.fill"
    ]

    static let pickerColors: [String] = [
        "blue", "green", "orange", "purple", "pink", "red", "indigo", "teal", "mint", "yellow", "brown", "cyan"
    ]

    /// Suggests an SF Symbol from a custom category name (e.g. "hotel" → bed icon).
    static func suggestedIcon(for name: String) -> String {
        let tokens = name
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)

        for token in tokens {
            if let match = keywordIcons.first(where: { token.contains($0.key) }) {
                return match.value
            }
        }
        return "tag.fill"
    }

    private static let keywordIcons: [(key: String, value: String)] = [
        ("hotel", "bed.double.fill"),
        ("motel", "bed.double.fill"),
        ("hostel", "bed.double.fill"),
        ("lodging", "bed.double.fill"),
        ("airbnb", "house.fill"),
        ("flight", "airplane"),
        ("airline", "airplane"),
        ("travel", "airplane"),
        ("trip", "airplane"),
        ("taxi", "car.fill"),
        ("uber", "car.fill"),
        ("gas", "fuelpump.fill"),
        ("fuel", "fuelpump.fill"),
        ("grocery", "cart.fill"),
        ("supermarket", "cart.fill"),
        ("restaurant", "fork.knife"),
        ("dining", "fork.knife"),
        ("coffee", "cup.and.saucer.fill"),
        ("cafe", "cup.and.saucer.fill"),
        ("bar", "wineglass.fill"),
        ("shop", "bag.fill"),
        ("shopping", "bag.fill"),
        ("clothes", "tshirt.fill"),
        ("gym", "dumbbell.fill"),
        ("fitness", "figure.run"),
        ("health", "heart.fill"),
        ("doctor", "cross.case.fill"),
        ("medical", "cross.case.fill"),
        ("pharmacy", "cross.case.fill"),
        ("pet", "pawprint.fill"),
        ("vet", "pawprint.fill"),
        ("movie", "film.fill"),
        ("cinema", "film.fill"),
        ("game", "gamecontroller.fill"),
        ("subscription", "arrow.triangle.2.circlepath"),
        ("netflix", "play.tv.fill"),
        ("stream", "play.tv.fill"),
        ("phone", "iphone"),
        ("mobile", "iphone"),
        ("internet", "wifi"),
        ("utility", "bolt.fill"),
        ("electric", "bolt.fill"),
        ("water", "drop.fill"),
        ("rent", "house.fill"),
        ("insurance", "shield.fill"),
        ("bank", "building.columns.fill"),
        ("loan", "percent"),
        ("debt", "percent"),
        ("mortgage", "building.columns.fill"),
        ("cash", "banknote.fill"),
        ("money", "dollarsign.circle.fill"),
        ("wallet", "wallet.bifold.fill"),
        ("bill", "doc.text.fill"),
        ("invoice", "doc.text.fill"),
        ("receipt", "receipt.fill"),
        ("salary", "banknote.fill"),
        ("income", "banknote.fill"),
        ("paycheck", "banknote.fill"),
        ("education", "book.fill"),
        ("school", "graduationcap.fill"),
        ("tuition", "graduationcap.fill"),
        ("gift", "gift.fill"),
        ("beauty", "sparkles"),
        ("hair", "scissors"),
        ("salon", "scissors"),
        ("repair", "wrench.and.screwdriver.fill"),
        ("tool", "hammer.fill")
    ]
}
