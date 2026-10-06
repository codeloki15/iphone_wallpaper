import Combine
import SwiftUI
import WidgetKit

enum IconStyle: String, CaseIterable, Identifiable {
    case color, light, dark, mono

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Colors derived from a wallpaper's palette, as on the website: the most
/// vivid mid-tone is the accent, the next distinct hue is the second color,
/// and the clock color contrasts with the area behind the clock.
struct Theme {
    let accent: RGB
    let second: RGB
    let clock: RGB
    let darkWall: Bool

    /// `backgroundLuminance`, when known, is the measured brightness behind
    /// the clock; it beats the palette average on split wallpapers.
    init(wallpaper: Wallpaper, backgroundLuminance: Double? = nil) {
        var unique: [RGB] = []
        for c in wallpaper.colors where !unique.contains(c) { unique.append(c) }
        let scored = unique
            .map { c -> (RGB, Double, Double) in
                let hsl = c.hsl
                return (c, hsl.h, hsl.s * max(0, 1 - abs(hsl.l - 0.55) * 1.4))
            }
            .sorted { $0.2 > $1.2 }
        let top = scored[0]
        func hueGap(_ a: Double, _ b: Double) -> Double { min(abs(a - b), 1 - abs(a - b)) }
        let next = scored.dropFirst().first { hueGap($0.1, top.1) > 0.06 && $0.2 > 0.08 }
            ?? (scored.count > 1 ? scored[1] : top)
        let average = unique.map(\.luminance).reduce(0, +) / Double(unique.count)
        let dark = backgroundLuminance.map { $0 < 0.36 } ?? (average < 0.4)
        accent = top.0
        second = next.0
        darkWall = dark
        clock = dark ? top.0.mix(.white, 0.78) : top.0.mix(.black, 0.55)
    }

    struct IconColors {
        let top: RGB
        let bottom: RGB
        let glyph: RGB
        let sheen: Double
    }

    func iconColors(_ style: IconStyle) -> IconColors {
        switch style {
        case .mono:
            return IconColors(top: RGB(hex: "#222225"), bottom: RGB(hex: "#050506"), glyph: .white, sheen: 0.1)
        case .light:
            let glyph = accent.luminance > 0.35 ? accent.mix(.black, 0.5) : accent
            return IconColors(top: accent.mix(.white, 0.9), bottom: second.mix(.white, 0.8), glyph: glyph, sheen: 0.35)
        case .dark:
            let glyph = accent.luminance < 0.2 ? accent.mix(.white, 0.6) : accent.mix(.white, 0.15)
            return IconColors(top: RGB(hex: "#18181d"), bottom: accent.mix(.black, 0.78), glyph: glyph, sheen: 0.08)
        case .color:
            let top = accent.mix(.white, 0.08)
            var bottom = second.mix(accent, 0.25)
            // No single glyph color reads across a light-to-dark gradient, so
            // soften gradients that span too much.
            if abs(top.luminance - bottom.luminance) > 0.45 { bottom = top.mix(bottom, 0.4) }
            let glyph = top.mix(bottom, 0.5).luminance > 0.4 ? accent.mix(.black, 0.62) : RGB.white
            return IconColors(top: top, bottom: bottom, glyph: glyph, sheen: 0.18)
        }
    }

    func widgetColors(_ style: IconStyle) -> WidgetColors {
        let dark = style == .dark || style == .mono || (style == .color && darkWall)
        let background: RGB
        switch style {
        case .mono: background = RGB(hex: "#0b0b0d")
        case .dark: background = accent.mix(.black, 0.86)
        case .light: background = accent.mix(.white, 0.92)
        case .color: background = dark ? accent.mix(.black, 0.82) : accent.mix(.white, 0.9)
        }
        let accentInk = accent.luminance > 0.6 && !dark ? accent.mix(.black, 0.45) : accent
        let ink = dark ? RGB.white : RGB(hex: "#111114")
        // A second color for scenes with several objects. It must stand
        // out from the background as the accent does.
        var other = second
        if abs(other.luminance - background.luminance) < 0.25 {
            other = other.mix(dark ? .white : .black, 0.5)
        }
        return WidgetColors(
            background: background,
            ink: ink,
            accent: style == .mono ? .white : accentInk,
            second: style == .mono ? RGB(hex: "#8e8e96") : other,
            isDark: dark
        )
    }
}

struct WidgetColors {
    let background: RGB
    let ink: RGB
    let accent: RGB
    let second: RGB
    let isDark: Bool
}

// MARK: - Shared settings

/// The App Group shared by the app and its widgets (set in project.yml).
enum AppGroup {
    static let id: String = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? ""

    static var defaults: UserDefaults {
        if id.isEmpty { return .standard }
        return UserDefaults(suiteName: id) ?? .standard
    }
}

/// What the user picked in the app. The widgets read the same values.
struct ThemeSettings: Equatable {
    var wallpaperID: String
    var iconStyle: IconStyle
    var signature: String
    var clockLuminance: Double?

    static func load() -> ThemeSettings {
        let d = AppGroup.defaults
        return ThemeSettings(
            wallpaperID: d.string(forKey: "wallpaperID") ?? Look.all[0].wallpaperID,
            iconStyle: IconStyle(rawValue: d.string(forKey: "iconStyle") ?? "") ?? Look.all[0].iconStyle,
            signature: d.string(forKey: "signature") ?? Look.all[0].signature,
            clockLuminance: d.object(forKey: "clockLuminance") as? Double
        )
    }

    func save() {
        let d = AppGroup.defaults
        d.set(wallpaperID, forKey: "wallpaperID")
        d.set(iconStyle.rawValue, forKey: "iconStyle")
        d.set(signature, forKey: "signature")
        if let clockLuminance {
            d.set(clockLuminance, forKey: "clockLuminance")
        } else {
            d.removeObject(forKey: "clockLuminance")
        }
    }

    var wallpaper: Wallpaper { Catalog.wallpaper(id: wallpaperID) ?? Catalog.all[0] }
    var theme: Theme { Theme(wallpaper: wallpaper, backgroundLuminance: clockLuminance) }
    var widgetColors: WidgetColors { theme.widgetColors(iconStyle) }
}

/// The app's live copy of the settings. Saving tells every widget to redraw.
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published var settings: ThemeSettings {
        didSet {
            guard settings != oldValue else { return }
            settings.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    init() {
        settings = ThemeSettings.load()
    }
}

/// Average brightness of the area behind the clock and top widgets: the
/// upper left two thirds of the screen.
func clockAreaLuminance(_ image: CGImage) -> Double? {
    let w = 24
    let h = 52
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                              space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
          let data = ctx.data
    else { return nil }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
    var sum = 0.0
    var count = 0
    // Memory row 0 is the top of the image.
    for y in Int(Double(h) * 0.07)..<Int(Double(h) * 0.43) {
        for x in Int(Double(w) * 0.05)..<Int(Double(w) * 0.65) {
            let i = (y * w + x) * 4
            sum += RGB(r: Double(px[i]) / 255, g: Double(px[i + 1]) / 255, b: Double(px[i + 2]) / 255).luminance
            count += 1
        }
    }
    return count > 0 ? sum / Double(count) : nil
}
