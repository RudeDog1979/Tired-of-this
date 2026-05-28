import sys

with open("BuxMuse/Core/Theme/ThemeManager.swift", "r") as f:
    original = f.read()

# We need to replace the AppTheme struct and the extension AppTheme.
# We'll construct the new one and inject it.

new_struct = """struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String

    // Hero card gradient (works in both dark and light mode)
    let heroDarkGradient: [Color]
    let heroLightGradient: [Color]
    
    // Mesh gradients for iOS 18+ Hero Cards
    let meshDarkPalette: [Color]
    let meshLightPalette: [Color]

    // Primary accent — used on pills, active icons, buttons, CTAs
    let accentColor: Color

    // Radial glow color on hero card
    let glowColor: Color

    // Preview swatch colors for the theme picker (2 colors shown as a gradient pill)
    var swatchColors: [Color] { heroDarkGradient }
}"""

with open("scripts/themes_output.txt", "r") as f:
    themes_content = f.read()

new_extension = f"""extension AppTheme {{
{themes_content}
    /// All themes in display order
    static let all: [AppTheme] = [
        .buxDefault, .midnightOcean, .sunsetVibes, .emeraldCyber,
        .sakuraDream, .goldPrestige, .crimsonEmber, .neonHorizon,
        .quantumVelvet, .galacticPlasma, .liquidTitanium, .abyssalGlow
    ]
}}"""

# Extract parts from original
part1 = original.split("struct AppTheme: Identifiable, Equatable {")[0]
after_struct = original.split("var swatchColors: [Color] { heroDarkGradient }\n}")[1]
part2 = after_struct.split("extension AppTheme {")[0]
after_extension = after_struct.split("    ]\n}")[1]
part3 = after_extension

final = part1 + new_struct + part2 + new_extension + part3

with open("BuxMuse/Core/Theme/ThemeManager.swift", "w") as f:
    f.write(final)

