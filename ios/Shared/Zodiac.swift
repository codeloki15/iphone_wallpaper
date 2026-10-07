import SwiftUI

// The Zodiac widget: a constellation of the zodiac as it appears in the
// sky, with its name and dates. The star maps are in ZodiacData.swift
// (made by tools/make_zodiac.py); the sparkles are a motion font
// (MotionFonts.swift), so the stars keep twinkling.

extension ZodiacSign {
    /// The sign the sun is in on `date`.
    static func current(on date: Date) -> ZodiacSign {
        let parts = Calendar.current.dateComponents([.month, .day], from: date)
        let day = (parts.month ?? 1) * 100 + (parts.day ?? 1)
        let match = all.first { sign in
            let first = sign.first.0 * 100 + sign.first.1
            let last = sign.last.0 * 100 + sign.last.1
            // Capricorn runs over the new year.
            return first <= last ? (first...last).contains(day) : (day >= first || day <= last)
        }
        return match ?? all[0]
    }

    static func named(_ key: String) -> ZodiacSign? {
        all.first { $0.key == key }
    }

    /// As in "Dec 22 \u{2013} Jan 19".
    var dates: String {
        let months = Calendar.current.shortMonthSymbols
        return "\(months[first.0 - 1]) \(first.1) \u{2013} \(months[last.0 - 1]) \(last.1)"
    }
}

struct ZodiacView: View {
    let sign: ZodiacSign
    let date: Date

    private let gold = Color(red: 0.95, green: 0.82, blue: 0.58)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if w > h * 1.3 {
                // Wide: the figure on the left, its name and dates beside it.
                HStack(spacing: 0) {
                    figure(size: h)
                    caption(nameSize: 21, detailed: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                        .padding(.trailing, 14)
                }
            } else if h > 250 {
                // Large: the figure above, the name and dates below.
                let room: CGFloat = 92
                VStack(spacing: 0) {
                    figure(size: min(w, h - room))
                        .frame(maxWidth: .infinity)
                    caption(nameSize: 24, detailed: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .frame(height: room, alignment: .top)
                }
            } else {
                // Small: the figure fills the widget, with the name over it.
                ZStack(alignment: .bottomLeading) {
                    figure(size: min(w, h))
                        .frame(width: w, height: h)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(sign.symbol)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(gold)
                        Text(sign.name.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .padding(.leading, 14)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func caption(nameSize: CGFloat, detailed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(sign.name)
                    .font(.system(size: nameSize, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(sign.symbol)
                    .font(.system(size: nameSize * 0.9))
                    .foregroundStyle(gold)
            }
            Text(sign.dates.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(gold)
            if detailed {
                Text("\(sign.element) sign \u{00B7} Brightest star \(sign.brightest)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
    }

    /// The constellation in a square: its lines, its stars, and over them
    /// the font that makes the stars sparkle.
    private func figure(size: CGFloat) -> some View {
        let count = sign.stars.count / 3
        func point(_ i: Int) -> CGPoint {
            CGPoint(x: sign.stars[i * 3] * size, y: sign.stars[i * 3 + 1] * size)
        }
        /// Brighter stars are larger: the rule the font uses (star_radius in
        /// tools/make_motion_fonts.py).
        func radius(_ i: Int) -> CGFloat {
            max(6.5, 19 - 3.2 * sign.stars[i * 3 + 2]) / 1000 * size
        }
        return ZStack {
            Path { p in
                for line in sign.lines {
                    p.addLines(line.map(point))
                }
            }
            .stroke(Color(red: 0.72, green: 0.80, blue: 1).opacity(0.42), style: StrokeStyle(lineWidth: max(0.7, size * 0.005), lineCap: .round, lineJoin: .round))
            // Each star's glow, then the stars themselves.
            Path { p in
                for i in 0..<count {
                    let r = radius(i) * 2.6
                    p.addEllipse(in: CGRect(x: point(i).x - r, y: point(i).y - r, width: r * 2, height: r * 2))
                }
            }
            .fill(Color(red: 0.62, green: 0.75, blue: 1).opacity(0.2))
            Path { p in
                for i in 0..<count {
                    let r = radius(i)
                    p.addEllipse(in: CGRect(x: point(i).x - r, y: point(i).y - r, width: r * 2, height: r * 2))
                }
            }
            .fill(Color.white)
            TimerGlyph(font: .stars(sign), date: date, size: size)
        }
        .frame(width: size, height: size)
    }
}
