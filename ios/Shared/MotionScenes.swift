import SwiftUI

// Scenes: planets, rivers and race cars.
//
// Whatever moves in them is a motion font (MotionFonts.swift), which iOS
// keeps moving by itself; the views here draw what stays still.

/// Seconds into the current hour, the clock all scenes run on. A cycle whose
/// length divides 3600 seconds loops without a seam when the hour turns.
func sceneTime(_ date: Date) -> Double {
    let start = Calendar.current.dateInterval(of: .hour, for: date)?.start ?? date
    return date.timeIntervalSince(start)
}

// MARK: - Orbit

/// The night sky behind the planets and the constellations: always dark,
/// whatever the theme.
struct SpaceSky: View {
    var body: some View {
        // A picture for each widget size (tools/make_space_art.py): a
        // widget is not drawn at all if one of its images is too large.
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Image(w > h * 1.3 ? "space-sky-medium" : (h < 200 ? "space-sky-small" : "space-sky-large"))
                .resizable()
                .scaledToFill()
                .frame(width: w, height: h)
                .clipped()
        }
    }
}

/// The solar system: the eight planets going round the sun, each at its own
/// speed, and the Moon round the Earth. The planets are a motion font, so
/// they never stop. The sun and the orbit lines are drawn here. A wide
/// widget sees the orbits at a tilt.
struct OrbitView: View {
    let date: Date

    // Orbit sizes as fractions of the scene's width, and how far a wide
    // scene's orbits are flattened: the same numbers as ORBITS_ROUND,
    // ORBITS_WIDE and WIDE_TILT in tools/make_motion_fonts.py.
    private static let round: [Double] = [0.092, 0.138, 0.190, 0.242, 0.308, 0.380, 0.436, 0.480]
    private static let wide: [Double] = [0.118, 0.160, 0.206, 0.252, 0.312, 0.378, 0.432, 0.478]
    private static let wideTilt = 0.42

    var body: some View {
        GeometryReader { geo in
            let w = Double(geo.size.width)
            let h = Double(geo.size.height)
            let isWide = w > h * 1.3
            let side = min(w, h)
            // The scene's width. A small widget zooms in on the planets out
            // to Jupiter; the others pass through its corners.
            let scene = isWide ? w * 0.97 : side * (side < 200 ? 1.5 : 0.96)
            let tilt = isWide ? Self.wideTilt : 1
            ZStack {
                Path { p in
                    for orbit in isWide ? Self.wide : Self.round {
                        let rx = orbit * scene
                        let ry = rx * tilt
                        p.addEllipse(in: CGRect(x: w / 2 - rx, y: h / 2 - ry, width: rx * 2, height: ry * 2))
                    }
                }
                .stroke(Color.white.opacity(0.14), lineWidth: 0.75)
                .frame(width: w, height: h)
                sun(radius: scene * (isWide ? 0.03 : 0.042))
                // The scene can be larger than the widget; it stays centered
                // and the widget's edge crops it.
                TimerGlyph(font: isWide ? .orbitWide : .orbit, date: date, size: scene)
                    .frame(width: w, height: h)
            }
            .frame(width: w, height: h)
        }
    }

    private func sun(radius: Double) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 1, green: 0.66, blue: 0.24).opacity(0.6), Color(red: 1, green: 0.45, blue: 0.1).opacity(0)],
                    center: .center, startRadius: radius * 0.7, endRadius: radius * 3.4))
                .frame(width: radius * 6.8, height: radius * 6.8)
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 1, green: 0.98, blue: 0.88), Color(red: 1, green: 0.85, blue: 0.4), Color(red: 0.98, green: 0.56, blue: 0.14)],
                    center: .center, startRadius: 0, endRadius: radius))
                .frame(width: radius * 2, height: radius * 2)
        }
    }
}

// MARK: - Rivers

/// A region's map with its great rivers, and lights drifting down each one
/// from source to mouth.
struct RiversView: View {
    let region: RiverRegion
    let date: Date
    let colors: WidgetColors

    var body: some View {
        GeometryReader { geo in
            let w = Double(geo.size.width)
            let h = Double(geo.size.height)
            if w > h * 1.3 {
                // Wide: names on the left, the map on the right.
                let mapWidth = min(w * 0.62, h * region.aspect)
                HStack(alignment: .center, spacing: 0) {
                    caption(stacked: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    map.frame(width: mapWidth, height: mapWidth / region.aspect)
                }
            } else {
                // Tall: the names above, and the map as large as it fits.
                let room = h - 52
                let mapWidth = min(w, room * region.aspect)
                VStack(alignment: .leading, spacing: 0) {
                    caption(stacked: false)
                        .frame(height: 52, alignment: .topLeading)
                    map.frame(width: mapWidth, height: mapWidth / region.aspect)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func caption(stacked: Bool) -> some View {
        let names = region.rivers.prefix(5).map(\.name)
        return VStack(alignment: .leading, spacing: stacked ? 6 : 3) {
            Text(stacked ? "Rivers of\n\(region.title)" : "Rivers of \(region.title)")
                .font(.system(size: 17, weight: .bold))
                .lineLimit(stacked ? 2 : 1)
                .minimumScaleFactor(0.7)
            Text(names.joined(separator: stacked ? "\n" : " \u{00B7} "))
                .font(.system(size: 11, weight: .medium))
                .lineSpacing(1)
                .lineLimit(stacked ? 5 : 2)
                .opacity(0.6)
        }
        .foregroundStyle(colors.ink.color)
    }

    private var map: some View {
        ZStack {
            Image(region.landImage)
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(colors.ink.color.opacity(colors.isDark ? 0.22 : 0.16))
            Image(region.riversImage)
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(colors.accent.color.opacity(0.85))
            // The lights are a motion font. Its square is as large as the
            // map's longer side and shares the map's top left corner.
            GeometryReader { geo in
                TimerGlyph(font: .rivers(region), date: date, size: max(geo.size.width, geo.size.height))
                    .foregroundStyle(colors.isDark ? Color.white : colors.ink.color)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
        }
    }
}

// MARK: - Race

/// A race start, over and over: three cars form up on the grid, five red
/// lights come on a second apart, the lights go out and the cars are away.
/// The cars, their wheels and the lit lights are motion fonts; the track
/// and the gantry are drawn here.
struct RaceView: View {
    let date: Date
    let colors: WidgetColors

    var body: some View {
        GeometryReader { geo in
            let w = Double(geo.size.width)
            let h = Double(geo.size.height)
            // The track is laid out by the widget's width, as the fonts
            // are: RACE_TOP, RACE_TRACK and RACE_LIGHTS in
            // tools/make_motion_fonts.py.
            let top = w * 0.075
            let track = w * 0.318
            let red = Color(red: 1, green: 0.16, blue: 0.14)
            ZStack(alignment: .topLeading) {
                // Asphalt, kerbs, lane marks and the start line.
                Rectangle()
                    .fill(colors.ink.color.opacity(colors.isDark ? 0.10 : 0.07))
                    .frame(width: w, height: track)
                    .offset(y: top)
                edges(width: w, top: top, track: track)
                    .stroke(colors.accent.color.opacity(0.9), style: StrokeStyle(lineWidth: 5, dash: [14, 14]))
                edges(width: w, top: top, track: track)
                    .stroke(colors.ink.color.opacity(0.75), style: StrokeStyle(lineWidth: 5, dash: [14, 14], dashPhase: 14))
                Path { p in
                    p.move(to: CGPoint(x: 6, y: top + track / 2))
                    p.addLine(to: CGPoint(x: w, y: top + track / 2))
                }
                .stroke(colors.ink.color.opacity(0.28), style: StrokeStyle(lineWidth: 2, dash: [16, 24]))
                // The start line: two dashed columns, out of step, make a checker.
                ForEach(0..<2, id: \.self) { column in
                    Path { p in
                        let x = w * 0.72 + (Double(column) + 0.5) * track / 12
                        p.move(to: CGPoint(x: x, y: top))
                        p.addLine(to: CGPoint(x: x, y: top + track))
                    }
                    .stroke(colors.ink.color.opacity(0.55), style: StrokeStyle(
                        lineWidth: track / 12, dash: [track / 12, track / 12], dashPhase: column == 0 ? 0 : track / 12))
                }
                // The gantry and its five lamps, unlit.
                RoundedRectangle(cornerRadius: w * 0.012, style: .continuous)
                    .fill(Color(white: colors.isDark ? 0.03 : 0.12))
                    .frame(width: w * 0.196, height: w * 0.042)
                    .position(x: w * 0.80, y: w * 0.037)
                Path { p in
                    for i in 0..<5 {
                        let r = w * 0.0125
                        p.addEllipse(in: CGRect(x: w * (0.728 + 0.036 * Double(i)) - r, y: w * 0.037 - r, width: r * 2, height: r * 2))
                    }
                }
                .fill(Color(red: 0.32, green: 0.07, blue: 0.07))

                scene(.raceA, w).foregroundStyle(colors.accent.color)
                scene(.raceB, w).foregroundStyle(colors.second.color)
                scene(.raceC, w).foregroundStyle((colors.isDark ? RGB(hex: "#e9e9ee") : RGB(hex: "#2a2a30")).color)
                scene(.raceWheels, w).foregroundStyle(colors.isDark ? Color.black : Color(white: 0.12))
                scene(.raceLights, w)
                    .foregroundStyle(red)
                    .shadow(color: red.opacity(0.9), radius: w * 0.012)
            }
            .frame(width: w, height: h, alignment: .topLeading)
            .clipped()
        }
    }

    /// One layer of the moving scene. Its square is the widget's width and
    /// shares its top left corner; the widget crops what hangs below.
    private func scene(_ font: MotionFont, _ w: Double) -> some View {
        TimerGlyph(font: font, date: date, size: w)
    }

    /// The lines the kerbs run along, just outside both edges of the track.
    private func edges(width w: Double, top: Double, track: Double) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: top - 2.5))
            p.addLine(to: CGPoint(x: w, y: top - 2.5))
            p.move(to: CGPoint(x: 0, y: top + track + 2.5))
            p.addLine(to: CGPoint(x: w, y: top + track + 2.5))
        }
    }
}
