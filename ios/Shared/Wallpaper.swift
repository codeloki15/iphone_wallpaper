import Foundation

/// The drawing routines in Generators.swift. Each matches a generator on
/// the website.
enum Generator: String {
    case aurora, linear, waves, mountains, night, rings, synthwave, torn, tornDiagonal
}

struct Wallpaper: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let generator: Generator
    let palette: [String]

    var seed: UInt32 { fnvHash(name) }
    var colors: [RGB] { palette.map { RGB(hex: $0) } }
}

enum Catalog {
    static let all: [Wallpaper] = rows.map { name, category, generator, palette in
        Wallpaper(id: slug(name), name: name, category: category, generator: generator, palette: palette)
    }

    static var categories: [String] {
        var seen: [String] = []
        for wall in all where !seen.contains(wall.category) {
            seen.append(wall.category)
        }
        return ["All"] + seen
    }

    static func wallpaper(id: String) -> Wallpaper? {
        all.first { $0.id == id }
    }

    private static let rows: [(String, String, Generator, [String])] = [
        // Art
        ("Torn Mono", "Art", .tornDiagonal, ["#0b0b0d", "#ebe8ee", "#ffffff"]),
        ("Torn Graphite", "Art", .tornDiagonal, ["#131315", "#4c4a51", "#76737c"]),
        ("Torn Terracotta", "Art", .torn, ["#8f5b3c", "#e6bf9e", "#f7ebdd"]),
        ("Torn Sage", "Art", .torn, ["#5c7762", "#e0e6d6", "#f6f3ea"]),
        ("Torn Midnight", "Art", .torn, ["#1d2842", "#c7d1e4", "#eef1f7"]),
        // Gradient
        ("Aurora", "Gradient", .aurora, ["#0b1026", "#3a86ff", "#8338ec", "#ff006e", "#00f5d4"]),
        ("Peach Fizz", "Gradient", .aurora, ["#ffe5d9", "#ffb4a2", "#e5989b", "#ffcdb2", "#b5838d"]),
        ("Lagoon", "Gradient", .aurora, ["#012a36", "#29b6f6", "#00e5a0", "#1de9b6", "#0277bd"]),
        ("Cotton Candy", "Gradient", .aurora, ["#fde2ff", "#a0c4ff", "#ffc6ff", "#bdb2ff", "#caffbf"]),
        ("Twilight", "Gradient", .linear, ["#0f0c29", "#302b63", "#ff6a88"]),
        ("Citrus", "Gradient", .linear, ["#f7971e", "#ffd200", "#fff5c0"]),
        ("Mint Haze", "Gradient", .linear, ["#d4fc79", "#96e6a1", "#4facfe"]),
        // Nature
        ("Alpine Dawn", "Nature", .mountains, ["#fbc2a4", "#fde4cf", "#fff1e6", "#9a8c98", "#22223b"]),
        ("Misty Peaks", "Nature", .mountains, ["#cfd8dc", "#eceff1", "#ffffff", "#90a4ae", "#263238"]),
        ("Desert Dusk", "Nature", .mountains, ["#2b1055", "#f76b1c", "#ffd166", "#a4508b", "#2b1055"]),
        ("Pacific", "Nature", .waves, ["#a1c4fd", "#c2e9fb", "#4f9dde", "#0a2a66"]),
        ("Coral Sea", "Nature", .waves, ["#ffecd2", "#fcb69f", "#ff8c94", "#355c7d"]),
        ("Starry Ridge", "Nature", .night, ["#020111", "#20124d", "#f5f3ce", "#0b0a1f"]),
        ("Moonlit Hills", "Nature", .night, ["#0b132b", "#1c2541", "#e0e1dd", "#050a14"]),
        // Minimal
        ("Sunset Rings", "Minimal", .rings, ["#fff4e6", "#ff9f1c", "#ffbf69", "#cb997e", "#e76f51"]),
        ("Sage Rings", "Minimal", .rings, ["#f1f5ee", "#a3b18a", "#588157", "#dad7cd"]),
        // Dark
        ("Midnight Aurora", "Dark", .aurora, ["#000000", "#0d3b66", "#1b998b", "#5f0f40", "#2e294e"]),
        ("Obsidian Waves", "Dark", .waves, ["#000000", "#111111", "#2b2d42", "#0b0b0f"]),
        ("Eclipse Rings", "Dark", .rings, ["#000000", "#111111", "#1e1e24", "#2a2a33", "#ff2e63"]),
        // Retro
        ("Synthwave", "Retro", .synthwave, ["#0b0033", "#ff007f", "#ffe600", "#ff3cac", "#00f0ff"]),
        ("Outrun Dawn", "Retro", .synthwave, ["#1a1033", "#f15bb5", "#fee440", "#f15bb5", "#9b5de5"]),
        ("Vaporwave", "Retro", .synthwave, ["#2d0b4e", "#ff71ce", "#01cdfe", "#b967ff", "#05ffa1"]),
    ]
}

/// One-tap presets: a wallpaper with an icon style and signature.
struct Look: Identifiable {
    let name: String
    let wallpaperID: String
    let iconStyle: IconStyle
    let signature: String

    var id: String { name }

    static let all: [Look] = [
        Look(name: "Black Vision", wallpaperID: "torn-mono", iconStyle: .mono, signature: "Black Vision"),
        Look(name: "Terracotta Day", wallpaperID: "torn-terracotta", iconStyle: .color, signature: "Terracotta"),
        Look(name: "Graphite", wallpaperID: "torn-graphite", iconStyle: .dark, signature: "Graphite"),
        Look(name: "Night Drive", wallpaperID: "synthwave", iconStyle: .dark, signature: "Night Drive"),
        Look(name: "Alpine Morning", wallpaperID: "alpine-dawn", iconStyle: .light, signature: "Alpine"),
        Look(name: "Pacific Calm", wallpaperID: "pacific", iconStyle: .light, signature: "Pacific"),
    ]
}
