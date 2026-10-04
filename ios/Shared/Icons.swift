import CoreGraphics
import UIKit

/// The 24 Home Screen icons. Dock apps come first, then the grid. Third-party
/// apps get generic names; people choose which app each icon goes on.
struct AppIconSpec: Identifiable, Hashable {
    let id: String
    let label: String

    static let all: [AppIconSpec] = [
        ("phone", "Phone"), ("messages", "Messages"), ("browser", "Browser"), ("music", "Music"),
        ("mail", "Mail"), ("calendar", "Calendar"), ("photos", "Photos"), ("camera", "Camera"),
        ("maps", "Maps"), ("weather", "Weather"), ("clock", "Clock"), ("notes", "Notes"),
        ("store", "Store"), ("settings", "Settings"), ("videocall", "Video Call"), ("files", "Files"),
        ("wallet", "Wallet"), ("health", "Health"), ("chat", "Chat"), ("social", "Social"),
        ("video", "Video"), ("audio", "Audio"), ("calculator", "Calculator"), ("fitness", "Fitness"),
    ].map { AppIconSpec(id: $0.0, label: $0.1) }

    static var dock: [AppIconSpec] { Array(all.prefix(4)) }
    static var grid: [AppIconSpec] { Array(all.dropFirst(4)) }
}

/// Glyphs on a 24-unit grid, with the same path data as the website.
enum Glyphs {
    enum Op {
        case stroke(String)
        case fill(String)
        case circle(Double, Double, Double, filled: Bool)
        case custom(String)
    }

    static let ops: [String: [Op]] = [
        "phone": [.fill("M7.2 3.8l2.3-.3 1.6 4.1-1.9 1.5a11.5 11.5 0 0 0 5.7 5.7l1.5-1.9 4.1 1.6-.3 2.3a2.2 2.2 0 0 1-2.4 1.9C10.6 18.2 5.8 13.4 5.3 6.2a2.2 2.2 0 0 1 1.9-2.4z")],
        "messages": [.fill("M12 4c5 0 9 3.1 9 7c0 3.9-4 7-9 7c-1 0-2-.1-2.9-.4L5 19.5l1.2-3.4C4.2 14.8 3 13 3 11c0-3.9 4-7 9-7z")],
        "browser": [.circle(12, 12, 9, filled: false), .fill("M15.8 8.2l-2.4 5.2-5.2 2.4 2.4-5.2z")],
        "music": [.stroke("M9 17.5V6l10-2v11.5"), .circle(6.5, 17.5, 2.5, filled: true), .circle(16.5, 15.5, 2.5, filled: true)],
        "mail": [.stroke("M5 6h14a1.5 1.5 0 0 1 1.5 1.5v9A1.5 1.5 0 0 1 19 18H5a1.5 1.5 0 0 1-1.5-1.5v-9A1.5 1.5 0 0 1 5 6z"), .stroke("M4 7.2l8 5.8 8-5.8")],
        "calendar": [.stroke("M5 5h14a1.5 1.5 0 0 1 1.5 1.5v12A1.5 1.5 0 0 1 19 20H5a1.5 1.5 0 0 1-1.5-1.5v-12A1.5 1.5 0 0 1 5 5z"), .stroke("M3.5 9.5h17M8 3v4M16 3v4"), .custom("day")],
        "photos": [.stroke("M5 5h14a1.5 1.5 0 0 1 1.5 1.5v11A1.5 1.5 0 0 1 19 19H5a1.5 1.5 0 0 1-1.5-1.5v-11A1.5 1.5 0 0 1 5 5z"), .stroke("M3.8 16l4.7-4.5 3.5 3.5 2.5-2.5 5.5 5"), .circle(15.5, 9.5, 1.6, filled: true)],
        "camera": [.stroke("M4.5 8h2.8l1.6-2.5h6.2L16.7 8h2.8A1.5 1.5 0 0 1 21 9.5v8a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5v-8A1.5 1.5 0 0 1 4.5 8z"), .circle(12, 13.3, 3.4, filled: false)],
        "maps": [.stroke("M12 21s-6.5-5.9-6.5-11a6.5 6.5 0 0 1 13 0c0 5.1-6.5 11-6.5 11z"), .circle(12, 10, 2.3, filled: false)],
        "weather": [.circle(8.5, 8, 3, filled: false), .stroke("M8.5 2.3v1.2M2.8 8H4M4.5 4l.9.9M12.5 4l-.9.9"), .fill("M7.5 19h9.5a4 4 0 0 0 .6-7.95A5.5 5.5 0 0 0 7.1 12.6 3.2 3.2 0 0 0 7.5 19z")],
        "clock": [.circle(12, 12, 9, filled: false), .stroke("M12 7v5.2l3.4 2")],
        "notes": [.stroke("M6 3.5h12A1.5 1.5 0 0 1 19.5 5v14a1.5 1.5 0 0 1-1.5 1.5H6A1.5 1.5 0 0 1 4.5 19V5A1.5 1.5 0 0 1 6 3.5z"), .stroke("M8 9h8M8 12.5h8M8 16h5")],
        "store": [.stroke("M5.5 8.5h13l-1.1 11a1.5 1.5 0 0 1-1.5 1.4H8.1a1.5 1.5 0 0 1-1.5-1.4z"), .stroke("M9 8.5V7a3 3 0 0 1 6 0v1.5")],
        "settings": [.custom("gear")],
        "videocall": [.stroke("M4.5 7h9A1.5 1.5 0 0 1 15 8.5v7a1.5 1.5 0 0 1-1.5 1.5h-9A1.5 1.5 0 0 1 3 15.5v-7A1.5 1.5 0 0 1 4.5 7z"), .fill("M15 10.5l5.5-3v9l-5.5-3z")],
        "files": [.stroke("M3.5 7A1.5 1.5 0 0 1 5 5.5h4.2l2 2.2H19a1.5 1.5 0 0 1 1.5 1.5v8.8a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 18z")],
        "wallet": [.stroke("M4.5 6.5h15A1.5 1.5 0 0 1 21 8v9a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17V8a1.5 1.5 0 0 1 1.5-1.5z"), .stroke("M3 10.5h18M15 14.5h3")],
        "health": [.fill("M12 20s-7.5-4.6-7.5-10.2A4.2 4.2 0 0 1 12 7.3a4.2 4.2 0 0 1 7.5 2.5C19.5 15.4 12 20 12 20z")],
        "audio": [.fill("M12 3.5a3 3 0 0 1 3 3v5a3 3 0 0 1-6 0v-5a3 3 0 0 1 3-3z"), .stroke("M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5v3")],
        "calculator": [.stroke("M7 3.5h10A1.5 1.5 0 0 1 18.5 5v14a1.5 1.5 0 0 1-1.5 1.5H7A1.5 1.5 0 0 1 5.5 19V5A1.5 1.5 0 0 1 7 3.5z"), .stroke("M8.5 7.2h7"), .custom("keys")],
        "chat": [.stroke("M12 3.5a8.5 8.5 0 0 0-7.4 12.7L3.5 20.5l4.4-1.1A8.5 8.5 0 1 0 12 3.5z"), .circle(8.5, 12, 1.1, filled: true), .circle(12, 12, 1.1, filled: true), .circle(15.5, 12, 1.1, filled: true)],
        "social": [.stroke("M7.5 3.5h9a4 4 0 0 1 4 4v9a4 4 0 0 1-4 4h-9a4 4 0 0 1-4-4v-9a4 4 0 0 1 4-4z"), .circle(12, 12, 3.8, filled: false), .circle(17, 7, 1, filled: true)],
        "video": [.stroke("M5 5.5h14a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2z"), .fill("M10 9l5 3-5 3z")],
        "fitness": [.custom("rings")],
    ]

    private static var cache: [String: CGPath] = [:]
    private static let cacheLock = NSLock()

    private static func path(_ d: String) -> CGPath {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let p = cache[d] { return p }
        let p = SVGPath.parse(d)
        cache[d] = p
        return p
    }

    /// Draws a glyph into `rect` (top-left origin context).
    static func draw(_ id: String, in ctx: CGContext, rect: CGRect, color: RGB) {
        guard let list = ops[id] else { return }
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.minY)
        ctx.scaleBy(x: rect.width / 24, y: rect.height / 24)
        ctx.setFillColor(color.cg())
        ctx.setStrokeColor(color.cg())
        ctx.setLineWidth(1.9)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for op in list {
            switch op {
            case .stroke(let d):
                ctx.addPath(path(d))
                ctx.strokePath()
            case .fill(let d):
                ctx.addPath(path(d))
                ctx.fillPath()
            case let .circle(x, y, r, filled):
                let oval = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                if filled { ctx.fillEllipse(in: oval) } else { ctx.strokeEllipse(in: oval) }
            case .custom(let name):
                custom(name, ctx, color)
            }
        }
        ctx.restoreGState()
    }

    private static func custom(_ name: String, _ ctx: CGContext, _ color: RGB) {
        switch name {
        case "day":
            // Today's date on the calendar page.
            let text = TimeWords.day(Date()) as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: color.uiColor,
            ]
            let size = text.size(withAttributes: attrs)
            UIGraphicsPushContext(ctx)
            text.draw(at: CGPoint(x: 12 - size.width / 2, y: 15.2 - size.height / 2), withAttributes: attrs)
            UIGraphicsPopContext()
        case "gear":
            ctx.saveGState()
            ctx.translateBy(x: 12, y: 12)
            for _ in 0..<8 {
                ctx.rotate(by: .pi / 4)
                ctx.fill(CGRect(x: -1.6, y: -9.6, width: 3.2, height: 3.6))
            }
            ctx.restoreGState()
            ctx.strokeEllipse(in: CGRect(x: 12 - 6.6, y: 12 - 6.6, width: 13.2, height: 13.2))
            ctx.strokeEllipse(in: CGRect(x: 12 - 2.6, y: 12 - 2.6, width: 5.2, height: 5.2))
        case "keys":
            for row in 0..<3 {
                for col in 0..<3 {
                    let x = 9 + Double(col) * 3
                    let y = 11 + Double(row) * 3
                    ctx.fillEllipse(in: CGRect(x: x - 0.95, y: y - 0.95, width: 1.9, height: 1.9))
                }
            }
        case "rings":
            for (r, part) in [(8.8, 0.85), (6.1, 0.7), (3.4, 0.55)] {
                ctx.addArc(center: CGPoint(x: 12, y: 12), radius: CGFloat(r),
                           startAngle: -.pi / 2, endAngle: CGFloat(-Double.pi / 2 + Double.pi * 2 * part), clockwise: false)
                ctx.strokePath()
            }
        default:
            break
        }
    }
}

enum IconRenderer {
    /// A full-bleed square icon (iOS rounds the corners itself).
    static func draw(_ iconID: String, in ctx: CGContext, size: CGFloat, style: IconStyle, theme: Theme) {
        let c = theme.iconColors(style)
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        if let bg = CGGradient(colorsSpace: space, colors: [c.top.cg(), c.bottom.cg()] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(bg, start: .zero, end: CGPoint(x: size, y: size), options: [])
        }
        if let sheen = CGGradient(colorsSpace: space, colors: [RGB.white.cg(c.sheen), RGB.white.cg(0)] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(sheen, start: .zero, end: CGPoint(x: 0, y: size * 0.6), options: [])
        }
        let g = size * 0.56
        Glyphs.draw(iconID, in: ctx, rect: CGRect(x: (size - g) / 2, y: (size - g) / 2, width: g, height: g), color: c.glyph)
    }

    static func image(_ iconID: String, size: CGFloat, style: IconStyle, theme: Theme, scale: CGFloat = 1) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        return renderer.image { context in
            draw(iconID, in: context.cgContext, size: size, style: style, theme: theme)
        }
    }
}

/// A small SVG path parser: M L H V C S Q A Z, absolute and relative.
enum SVGPath {
    private enum Token {
        case command(Character)
        case number(Double)
    }

    static func parse(_ d: String) -> CGPath {
        let tokens = tokenize(d)
        let path = CGMutablePath()
        var i = 0
        var current = CGPoint.zero
        var start = CGPoint.zero
        var command: Character = "M"
        // The previous cubic's second control point, for S (smooth) curves.
        var lastC2: CGPoint?

        func number() -> Double {
            guard i < tokens.count, case .number(let v) = tokens[i] else { return 0 }
            i += 1
            return v
        }

        func hasNumber() -> Bool {
            if i < tokens.count, case .number = tokens[i] { return true }
            return false
        }

        while i < tokens.count {
            if case .command(let c) = tokens[i] {
                command = c
                i += 1
                if c == "Z" || c == "z" {
                    path.closeSubpath()
                    current = start
                    continue
                }
            }
            guard hasNumber() else {
                if i < tokens.count, case .command = tokens[i] { continue }
                i += 1
                continue
            }
            let relative = command.isLowercase
            let prevC2 = lastC2
            lastC2 = nil
            let ox: Double = relative ? Double(current.x) : 0
            let oy: Double = relative ? Double(current.y) : 0
            switch command {
            case "M", "m":
                let p = CGPoint(x: ox + number(), y: oy + number())
                path.move(to: p)
                current = p
                start = p
                // Further coordinate pairs after a move are lines.
                command = relative ? "l" : "L"
            case "L", "l":
                let p = CGPoint(x: ox + number(), y: oy + number())
                path.addLine(to: p)
                current = p
            case "H", "h":
                current = CGPoint(x: ox + number(), y: Double(current.y))
                path.addLine(to: current)
            case "V", "v":
                current = CGPoint(x: Double(current.x), y: oy + number())
                path.addLine(to: current)
            case "C", "c":
                let c1 = CGPoint(x: ox + number(), y: oy + number())
                let c2 = CGPoint(x: ox + number(), y: oy + number())
                let p = CGPoint(x: ox + number(), y: oy + number())
                path.addCurve(to: p, control1: c1, control2: c2)
                lastC2 = c2
                current = p
            case "S", "s":
                // The first control point mirrors the previous curve's second.
                let c1 = prevC2.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let c2 = CGPoint(x: ox + number(), y: oy + number())
                let p = CGPoint(x: ox + number(), y: oy + number())
                path.addCurve(to: p, control1: c1, control2: c2)
                lastC2 = c2
                current = p
            case "Q", "q":
                let c1 = CGPoint(x: ox + number(), y: oy + number())
                let p = CGPoint(x: ox + number(), y: oy + number())
                path.addQuadCurve(to: p, control: c1)
                current = p
            case "A", "a":
                let rx = number()
                let ry = number()
                let rotation = number()
                let large = number() != 0
                let sweep = number() != 0
                let p = CGPoint(x: ox + number(), y: oy + number())
                addArc(path, from: current, rx: rx, ry: ry, rotation: rotation, large: large, sweep: sweep, to: p)
                current = p
            default:
                i += 1
            }
        }
        return path
    }

    private static func tokenize(_ d: String) -> [Token] {
        var out: [Token] = []
        let chars = Array(d)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if "MmLlHhVvCcSsQqAaZz".contains(c) {
                out.append(.command(c))
                i += 1
            } else if c == "-" || c == "+" || c == "." || c.isNumber {
                var s = ""
                var j = i
                if chars[j] == "-" || chars[j] == "+" {
                    s.append(chars[j])
                    j += 1
                }
                var dot = false
                while j < chars.count {
                    let ch = chars[j]
                    if ch.isNumber {
                        s.append(ch)
                    } else if ch == "." && !dot {
                        dot = true
                        s.append(ch)
                    } else {
                        break
                    }
                    j += 1
                }
                out.append(.number(Double(s) ?? 0))
                i = max(j, i + 1)
            } else {
                i += 1
            }
        }
        return out
    }

    /// SVG elliptical arc, converted to cubic Béziers (at most 90° each).
    private static func addArc(_ path: CGMutablePath, from p0: CGPoint, rx rxIn: Double, ry ryIn: Double,
                               rotation: Double, large: Bool, sweep: Bool, to p1: CGPoint) {
        var rx = abs(rxIn)
        var ry = abs(ryIn)
        let x0 = Double(p0.x), y0 = Double(p0.y), x1 = Double(p1.x), y1 = Double(p1.y)
        if rx == 0 || ry == 0 || (x0 == x1 && y0 == y1) {
            path.addLine(to: p1)
            return
        }
        let phi = rotation * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)
        let dx = (x0 - x1) / 2, dy = (y0 - y1) / 2
        let xp = cosP * dx + sinP * dy
        let yp = -sinP * dx + cosP * dy
        let lambda = (xp * xp) / (rx * rx) + (yp * yp) / (ry * ry)
        if lambda > 1 {
            rx *= sqrt(lambda)
            ry *= sqrt(lambda)
        }
        let rx2 = rx * rx, ry2 = ry * ry
        let num = max(0, rx2 * ry2 - rx2 * yp * yp - ry2 * xp * xp)
        let den = rx2 * yp * yp + ry2 * xp * xp
        var coef = den == 0 ? 0 : sqrt(num / den)
        if large == sweep { coef = -coef }
        let cxp = coef * rx * yp / ry
        let cyp = -coef * ry * xp / rx
        let cx = cosP * cxp - sinP * cyp + (x0 + x1) / 2
        let cy = sinP * cxp + cosP * cyp + (y0 + y1) / 2

        func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        }
        let theta1 = angle(1, 0, (xp - cxp) / rx, (yp - cyp) / ry)
        var delta = angle((xp - cxp) / rx, (yp - cyp) / ry, (-xp - cxp) / rx, (-yp - cyp) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }

        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let step = delta / Double(segments)
        let k = 4.0 / 3.0 * tan(step / 4)
        func map(_ x: Double, _ y: Double) -> CGPoint {
            let sx = x * rx, sy = y * ry
            return CGPoint(x: cosP * sx - sinP * sy + cx, y: sinP * sx + cosP * sy + cy)
        }
        var t = theta1
        for _ in 0..<segments {
            let c1 = cos(t), s1 = sin(t)
            let c2 = cos(t + step), s2 = sin(t + step)
            path.addCurve(
                to: map(c2, s2),
                control1: map(c1 - k * s1, s1 + k * c1),
                control2: map(c2 + k * s2, s2 - k * c2)
            )
            t += step
        }
    }
}
