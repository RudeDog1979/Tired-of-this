import colorsys

def hsv_to_rgb(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return int(r * 255), int(g * 255), int(b * 255)

def rgb_to_hsv(r, g, b):
    return colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)

def generate_mesh(base_r, base_g, base_b, is_dark, theme_name):
    h, s, v = rgb_to_hsv(base_r, base_g, base_b)
    
    # 9 colors for mesh
    colors = []
    
    shifts = [
        (-0.15, 0.8, 1.1),  # Top Left: Shift hue left, less sat, brighter
        (0.0, 1.0, 1.0),    # Top Mid: Base
        (0.15, 0.9, 1.05),  # Top Right: Shift hue right
        
        (-0.05, 1.1, 0.9),  # Mid Left
        (0.0, 1.0, 1.0),    # Center: Base
        (0.05, 1.1, 0.9),   # Mid Right
        
        (-0.2, 0.7, 1.2),   # Bot Left: Big hue shift left, bright
        (0.0, 0.9, 1.0),    # Bot Mid
        (0.2, 0.7, 1.2)     # Bot Right: Big hue shift right, bright
    ]
    
    if is_dark:
        # For dark mode, saturate more, reduce value
        s_mult = 1.2
        v_mult = 0.6
    else:
        # For light mode, desaturate slightly, increase value
        s_mult = 0.6
        v_mult = 1.1
        
    print(f"        mesh{'Dark' if is_dark else 'Light'}Palette: [")
    out = []
    for dh, ds, dv in shifts:
        new_h = (h + dh) % 1.0
        new_s = min(1.0, max(0.0, s * ds * s_mult))
        new_v = min(1.0, max(0.0, v * dv * v_mult))
        
        r, g, b = hsv_to_rgb(new_h, new_s, new_v)
        out.append(f"            Color(red: {r}/255, green: {g}/255, blue: {b}/255)")
    print(",\n".join(out))
    print("        ],")

def gen_theme(id_str, name, icon, r, g, b):
    print(f"    /// {name} Theme")
    print(f"    static let {id_str} = AppTheme(")
    print(f'        id: "{id_str}",')
    print(f'        name: "{name}",')
    print(f'        icon: "{icon}",')
    
    print(f"        heroDarkGradient: [Color(red: {r}/255, green: {g}/255, blue: {b}/255), Color(red: {int(r*0.7)}/255, green: {int(g*0.7)}/255, blue: {int(b*0.7)}/255)],")
    print(f"        heroLightGradient: [Color(red: {min(255, int(r*1.2))}/255, green: {min(255, int(g*1.2))}/255, blue: {min(255, int(b*1.2))}/255), Color(red: {r}/255, green: {g}/255, blue: {b}/255)],")
    
    generate_mesh(r, g, b, True, name)
    generate_mesh(r, g, b, False, name)
    
    print(f"        accentColor: Color(red: {r}/255, green: {g}/255, blue: {b}/255),")
    print(f"        glowColor: Color(red: {r}/255, green: {g}/255, blue: {b}/255)")
    print("    )\n")

gen_theme("buxDefault", "Bux", "bolt.fill", 90, 85, 245)
gen_theme("midnightOcean", "Ocean", "drop.fill", 0, 180, 216)
gen_theme("sunsetVibes", "Sunset", "sun.horizon.fill", 255, 107, 107)
gen_theme("emeraldCyber", "Emerald", "leaf.fill", 0, 245, 160)
gen_theme("sakuraDream", "Sakura", "heart.fill", 255, 158, 174)
gen_theme("goldPrestige", "Gold", "crown.fill", 255, 215, 0)
gen_theme("crimsonEmber", "Crimson", "flame.fill", 255, 51, 102)
gen_theme("neonHorizon", "Horizon", "sparkles", 155, 93, 229)
gen_theme("quantumVelvet", "Quantum", "moon.stars.fill", 112, 41, 230)
gen_theme("galacticPlasma", "Galactic", "sparkle", 10, 230, 255)
gen_theme("liquidTitanium", "Titanium", "hexagon.fill", 180, 190, 210)
gen_theme("abyssalGlow", "Abyssal", "water.waves", 20, 255, 120)

