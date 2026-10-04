import SwiftUI
import UIKit

/// An sRGB color with components from 0 to 1. Used for palette math (mixing,
/// luminance) before handing colors to Core Graphics or SwiftUI.
struct RGB: Equatable, Hashable {
    var r: Double
    var g: Double
    var b: Double

    static let white = RGB(r: 1, g: 1, b: 1)
    static let black = RGB(r: 0, g: 0, b: 0)

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// Parses "#rrggbb".
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt32(s, radix: 16) ?? 0
        r = Double((v >> 16) & 0xff) / 255
        g = Double((v >> 8) & 0xff) / 255
        b = Double(v & 0xff) / 255
    }

    var hex: String {
        func byte(_ c: Double) -> Int { Int((min(max(c, 0), 1) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", byte(r), byte(g), byte(b))
    }

    /// Linear blend toward `other` by `t` (0 = self, 1 = other).
    func mix(_ other: RGB, _ t: Double) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    /// WCAG relative luminance.
    var luminance: Double {
        func channel(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    var hsl: (h: Double, s: Double, l: Double) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let l = (maxC + minC) / 2
        if maxC == minC { return (0, 0, l) }
        let d = maxC - minC
        let s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)
        var h: Double
        if maxC == r {
            h = (g - b) / d + (g < b ? 6 : 0)
        } else if maxC == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        h /= 6
        return (h, s, l)
    }

    func cg(_ alpha: Double = 1) -> CGColor {
        CGColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(alpha))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    var uiColor: UIColor { UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1) }
}

/// The seeded generator the website uses (mulberry32), so a wallpaper's
/// layout is the same every time it is drawn.
final class Rand {
    private var a: UInt32

    init(seed: UInt32) {
        a = seed
    }

    func callAsFunction() -> Double {
        a = a &+ 0x6D2B_79F5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4_294_967_296.0
    }
}

/// FNV-1a over UTF-16 code units, matching the website's seeds.
func fnvHash(_ s: String) -> UInt32 {
    var h: UInt32 = 2_166_136_261
    for unit in s.utf16 {
        h ^= UInt32(unit)
        h = h &* 16_777_619
    }
    return h
}

/// "Torn Mono" -> "torn-mono"
func slug(_ s: String) -> String {
    var out = ""
    var dash = false
    for ch in s.lowercased() {
        if ch.isLetter || ch.isNumber {
            out.append(ch)
            dash = false
        } else if !dash && !out.isEmpty {
            out.append("-")
            dash = true
        }
    }
    if out.hasSuffix("-") { out.removeLast() }
    return out
}
