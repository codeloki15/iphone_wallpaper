import SwiftUI

// Widgets that move: planets, rivers, a thunderstorm and race cars.
//
// WidgetKit only animates a widget from one timeline entry to the next, so
// each scene is a function of the entry's date: it says where everything is
// at that moment, and attaches an animation that carries it there from the
// previous entry. iOS stores every entry's view (about 10 MB at most for a
// whole timeline), so the scenes use few views: fixed artwork is an image
// or a single path, and only the moving pieces are views of their own.

/// Seconds into the current hour, the clock all scenes run on. A cycle whose
/// length divides 3600 seconds loops without a seam when the hour turns.
func sceneTime(_ date: Date) -> Double {
    let start = Calendar.current.dateInterval(of: .hour, for: date)?.start ?? date
    return date.timeIntervalSince(start)
}

extension Motion {
    /// A scene's own animation into this entry, or none if the value should
    /// snap (the scene is not running, or `snap` says the object is jumping
    /// back to its start while out of sight).
    func animation(_ animation: Animation, snap: Bool = false) -> Animation? {
        self == .running && !snap ? animation : nil
    }
}

// MARK: - Orbit

/// A sun with six planets going round at their own speeds. In a wide
/// widget the orbits are tilted into ellipses to fill the space.
struct OrbitView: View {
    let date: Date
    let colors: WidgetColors
    var motion: Motion = .running

    private struct Planet {
        /// Orbit radius and planet diameter, as fractions of the system's radius.
        let orbit: Double
        let size: Double
        /// Seconds per revolution. Each divides 3600.
        let period: Double
        /// Starting angle in degrees.
        let phase: Double
        let tone: Int
        var ringed = false
        var moon = false
    }

    private static let planets = [
        Planet(orbit: 0.21, size: 0.050, period: 24, phase: 40, tone: 2),
        Planet(orbit: 0.33, size: 0.066, period: 40, phase: 200, tone: 1),
        Planet(orbit: 0.47, size: 0.076, period: 72, phase: 110, tone: 0, moon: true),
        Planet(orbit: 0.62, size: 0.060, period: 120, phase: 300, tone: 3),
        Planet(orbit: 0.79, size: 0.120, period: 240, phase: 20, tone: 1, ringed: true),
        Planet(orbit: 0.95, size: 0.086, period: 450, phase: 170, tone: 2),
    ]

    /// A scattering of stars, the same every time.
    private static let stars: [(Double, Double, Double)] = {
        let rand = Rand(seed: 7)
        return (0..<26).map { _ in (rand(), rand(), 0.5 + rand() * 0.9) }
    }()

    private func tone(_ index: Int) -> RGB {
        switch index {
        case 0: return colors.accent
        case 1: return colors.second
        case 2: return colors.ink.mix(colors.background, 0.25)
        default: return colors.accent.mix(colors.ink, 0.5)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = Double(geo.size.width)
            let h = Double(geo.size.height)
            let wide = w > h * 1.3
            let radius = (wide ? w : min(w, h)) / 2 * 0.95
            // How much the orbits are squashed to fit a wide widget.
            let tilt = wide ? min(1, h * 0.92 / (radius * 2)) : 1
            let t = sceneTime(date)
            ZStack {
                Path { p in
                    // Squares, which at this size read as dots and take a
                    // quarter of the path data that circles would.
                    for (x, y, size) in Self.stars {
                        p.addRect(CGRect(x: x * w, y: y * h, width: size, height: size))
                    }
                }
                .fill(colors.ink.color.opacity(0.45))

                ZStack {
                    Path { p in
                        for planet in Self.planets {
                            let r = planet.orbit * radius
                            p.addEllipse(in: CGRect(x: radius - r, y: radius - r, width: r * 2, height: r * 2))
                        }
                    }
                    .stroke(colors.ink.color.opacity(0.16), lineWidth: 1)
                    ForEach(Self.planets.indices, id: \.self) { i in
                        planet(Self.planets[i], radius: radius, tilt: tilt, t: t)
                    }
                }
                .frame(width: radius * 2, height: radius * 2)
                .scaleEffect(x: 1, y: tilt)
                .frame(width: w, height: h)

                Circle()
                    .fill(RadialGradient(
                        colors: [colors.accent.color.opacity(0.5), colors.accent.color.opacity(0)],
                        center: .center, startRadius: radius * 0.05, endRadius: radius * 0.2))
                    .frame(width: radius * 0.4, height: radius * 0.4)
                Circle()
                    .fill(RadialGradient(
                        colors: [colors.accent.mix(.white, 0.6).color, colors.accent.color],
                        center: .center, startRadius: 0, endRadius: radius * 0.08))
                    .frame(width: radius * 0.16, height: radius * 0.16)
            }
            .frame(width: w, height: h)
        }
    }

    private func planet(_ planet: Planet, radius: Double, tilt: Double, t: Double) -> some View {
        let angle = planet.phase + t / planet.period * 360
        let d = planet.size * radius * 2
        let color = tone(planet.tone)
        return ZStack {
            if planet.ringed {
                Ellipse()
                    .stroke(color.mix(colors.ink, 0.4).color.opacity(0.8), lineWidth: max(1, d * 0.09))
                    .frame(width: d * 1.9, height: d * 0.6)
                    .rotationEffect(.degrees(-18))
            }
            Circle()
                .fill(LinearGradient(
                    colors: [color.mix(.white, 0.35).color, color.mix(.black, 0.25).color],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: d, height: d)
            if planet.moon {
                Circle()
                    .fill(colors.ink.color.opacity(0.75))
                    .frame(width: d * 0.3, height: d * 0.3)
                    .offset(x: d * 0.95)
                    .rotationEffect(.degrees(t / 12 * 360))
            }
        }
        // Undo the tilt and the turn, so the planet stays round and upright
        // while it travels round the squashed orbit.
        .scaleEffect(x: 1, y: 1 / tilt)
        .rotationEffect(.degrees(-angle))
        .offset(x: planet.orbit * radius)
        .rotationEffect(.degrees(angle))
        .animation(motion.animation(wraps: t < motionStep), value: date)
    }
}

// MARK: - Rivers

/// A region's map with its great rivers, and lights drifting down each one
/// from source to mouth.
struct RiversView: View {
    let region: RiverRegion
    let date: Date
    let colors: WidgetColors
    var motion: Motion = .running

    /// Seconds for a light to run a river. Each divides 3600.
    private static let periods: [Double] = [40, 60, 48, 72, 45, 90, 50, 80, 36]

    private struct Light: Identifiable {
        let id: Int
        let x: Double
        let y: Double
        let opacity: Double
        let wraps: Bool
    }

    private func lights(at t: Double) -> [Light] {
        var out: [Light] = []
        for (r, river) in region.rivers.enumerated() {
            let period = Self.periods[r % Self.periods.count]
            let stride = motionStep / period
            // Two lights on the first few rivers, one on the rest.
            let count = r < 4 ? 2 : 1
            for k in 0..<count {
                let turns = t / period + Double(k) / Double(count) + Double(r) * 0.137
                let p = turns - turns.rounded(.down)
                let point = Self.point(on: river.course, at: p)
                // Fade in after the source and out before the mouth, so the
                // jump back to the source happens while the light is dark.
                let fade = min(1, p / 0.1) * min(1, max(0, 1 - stride - p) / 0.14)
                out.append(Light(id: r * 4 + k, x: point.0, y: point.1, opacity: max(0, fade), wraps: p < stride))
            }
        }
        return out
    }

    /// The point a fraction `p` of the way along a course of evenly spaced x, y pairs.
    private static func point(on course: [Double], at p: Double) -> (Double, Double) {
        let last = course.count / 2 - 1
        let f = min(max(p, 0), 1) * Double(last)
        let i = min(Int(f), last - 1)
        let u = f - Double(i)
        return (
            course[i * 2] + (course[i * 2 + 2] - course[i * 2]) * u,
            course[i * 2 + 1] + (course[i * 2 + 3] - course[i * 2 + 1]) * u
        )
    }

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
            GeometryReader { geo in
                let w = Double(geo.size.width)
                let h = Double(geo.size.height)
                let size = max(3.5, w * 0.03)
                ForEach(lights(at: sceneTime(date))) { light in
                    Circle()
                        .fill(colors.isDark ? Color.white : colors.ink.color)
                        .frame(width: size, height: size)
                        .opacity(motion == .resting ? 0 : light.opacity)
                        .position(x: light.x * w, y: light.y * h)
                        .animation(motion.animation(wraps: light.wraps), value: date)
                }
            }
        }
    }
}

// MARK: - Storm

/// The sky behind the storm: always dark, with a hint of the theme's color.
struct StormSky: View {
    let colors: WidgetColors

    var body: some View {
        let top = RGB(hex: "#0b0e16").mix(colors.accent, 0.10)
        let bottom = RGB(hex: "#1a2030").mix(colors.accent, 0.16)
        LinearGradient(colors: [top.color, bottom.color], startPoint: .top, endPoint: .bottom)
    }
}

/// Clouds, slanting rain, and lightning every so often.
struct StormView: View {
    let date: Date
    let colors: WidgetColors
    var motion: Motion = .running

    /// Rain falls in sheets: each is one path of a few streaks, so a whole
    /// sheet costs one view. A streak is (x, y, length), each 0...1 within
    /// its sheet.
    private static let sheets: [[(Double, Double, Double)]] = {
        let rand = Rand(seed: 21)
        return (0..<6).map { _ in
            (0..<9).map { i in
                let x: Double = (Double(i) + 0.1 + rand() * 0.8) / 9
                let y: Double = rand()
                let length: Double = 0.7 + rand() * 0.6
                return (x, y, length)
            }
        }
    }()

    /// When each sheet starts to fall within its step.
    private static let sheetDelays: [Double] = [0, 0.33, 0.66, 0.16, 0.5, 0.83]

    /// Seconds into each minute at which lightning strikes, and which bolt.
    private static let strikes: [(at: Double, bolt: Int)] = [(6, 0), (20, 1), (24, 0), (44, 1), (52, 0)]

    var body: some View {
        GeometryReader { geo in
            let w = Double(geo.size.width)
            let h = Double(geo.size.height)
            let t = sceneTime(date)
            let step = Int((t / motionStep).rounded())
            let inMinute = t.truncatingRemainder(dividingBy: 60)
            // A bolt is lit for the one entry that starts at its strike time.
            let lit = motion == .resting ? nil : Self.strikes.first { abs($0.at - inMinute) < 0.5 }?.bolt
            ZStack {
                // The whole sky brightens with the bolt.
                Rectangle()
                    .fill(Color.white)
                    .opacity(lit == nil ? 0 : 0.16)
                    .animation(flash(on: lit != nil), value: date)
                ForEach(0..<2, id: \.self) { i in
                    bolt(i, width: w, height: h)
                        .opacity(lit == i ? 1 : 0)
                        .animation(flash(on: lit == i), value: date)
                }
                ForEach(Self.sheets.indices, id: \.self) { i in
                    sheet(i, step: step, width: w, height: h)
                }
                cloud(width: w, height: h, y: -0.03, scale: 1.0)
                    .fill(Color.white.opacity(0.13))
                    .offset(x: sin(t / 120 * 2 * .pi) * w * 0.03)
                    .animation(motion.animation(), value: date)
                cloud(width: w, height: h, y: 0.07, scale: 0.8)
                    .fill(Color.white.opacity(0.10))
                    .offset(x: w * 0.12 + cos(t / 90 * 2 * .pi) * w * 0.04)
                    .animation(motion.animation(), value: date)
            }
            .frame(width: w, height: h)
            .clipped()
        }
    }

    /// Lightning comes on late in its entry and dies away early in the
    /// next, so it shows for about a second.
    private func flash(on: Bool) -> Animation? {
        motion.animation(on ? .easeOut(duration: 0.07).delay(1.45) : .easeIn(duration: 0.45))
    }

    /// Three sheets fall during even steps and three during odd ones. In
    /// the step between, a sheet jumps back above the top, out of sight.
    private func sheet(_ i: Int, step: Int, width w: Double, height h: Double) -> some View {
        let falling = (step + i) % 2 == 0
        let tall = h * 0.9
        let slant = 0.2
        // The sheet's top edge: above the widget, or below it. At rest the
        // sheets hang at different heights.
        let top = motion == .resting ? h * (Double(i) / 6 - 0.4) : (falling ? h * 1.05 : -tall * 1.05)
        return Path { p in
            for (x, y, length) in Self.sheets[i] {
                let x0 = (x * 1.25 - y * slant) * w
                let y0 = y * tall
                let dy = h * 0.085 * length
                p.move(to: CGPoint(x: x0, y: y0))
                p.addLine(to: CGPoint(x: x0 - dy * slant, y: y0 + dy))
            }
        }
        .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        .frame(width: w, height: tall, alignment: .topLeading)
        .offset(x: -top * slant, y: top)
        .animation(motion.animation(.linear(duration: 1.05).delay(Self.sheetDelays[i]), snap: !falling), value: date)
    }

    private func bolt(_ i: Int, width w: Double, height h: Double) -> some View {
        // Two zigzags, each given as x, y pairs down the widget (0...1).
        let shapes: [[Double]] = [
            [0.30, 0.16, 0.24, 0.42, 0.31, 0.42, 0.22, 0.74, 0.37, 0.36, 0.30, 0.36, 0.36, 0.16],
            [0.72, 0.20, 0.66, 0.40, 0.72, 0.40, 0.62, 0.66, 0.78, 0.35, 0.71, 0.35, 0.77, 0.20],
        ]
        let v = shapes[i]
        // The bolt keeps its proportions in widgets of any shape.
        let unit = min(w, h * 1.6)
        let left = (w - unit) / 2
        return Path { p in
            p.move(to: CGPoint(x: left + v[0] * unit, y: v[1] * h))
            for k in stride(from: 2, to: v.count, by: 2) {
                p.addLine(to: CGPoint(x: left + v[k] * unit, y: v[k + 1] * h))
            }
            p.closeSubpath()
        }
        .fill(Color(red: 1, green: 0.94, blue: 0.62))
    }

    /// A cloud bank across the top, as one path of overlapping puffs.
    private func cloud(width w: Double, height h: Double, y: Double, scale: Double) -> Path {
        let puffs: [(Double, Double, Double)] = [
            (0.05, 0.10, 0.20), (0.20, 0.06, 0.26), (0.38, 0.11, 0.24), (0.55, 0.05, 0.28),
            (0.72, 0.10, 0.24), (0.90, 0.07, 0.24), (1.02, 0.12, 0.18),
        ]
        return Path { p in
            for (x, py, size) in puffs {
                let r = size * h * scale
                p.addEllipse(in: CGRect(x: x * w - r, y: (y + py) * h - r * 0.75, width: r * 2, height: r * 1.5))
            }
            p.addRect(CGRect(x: -w * 0.2, y: -h * 0.3, width: w * 1.5, height: (y + 0.3) * h + h * 0.06))
        }
    }
}

// MARK: - Race

/// Race cars streaking down a straight, each at its own pace.
struct RaceView: View {
    let date: Date
    let colors: WidgetColors
    var motion: Motion = .running

    private struct Car {
        /// Lane center down the track (0...1) and size relative to the track's height.
        let lane: Double
        let size: Double
        /// The car passes once every `every` steps, taking `seconds` to
        /// cross after waiting `delay`. `offset` staggers the cars.
        let every: Int
        let offset: Int
        let seconds: Double
        let delay: Double
        let tone: Int
    }

    // The first and third take turns, one of them on the track for nearly
    // the whole of every step; the others overtake now and then.
    private static let cars = [
        Car(lane: 0.24, size: 0.24, every: 2, offset: 0, seconds: 1.90, delay: 0.00, tone: 1),
        Car(lane: 0.42, size: 0.27, every: 3, offset: 1, seconds: 1.25, delay: 0.60, tone: 2),
        Car(lane: 0.60, size: 0.30, every: 2, offset: 1, seconds: 1.90, delay: 0.00, tone: 0),
        Car(lane: 0.78, size: 0.33, every: 4, offset: 2, seconds: 1.10, delay: 0.80, tone: 1),
        Car(lane: 0.86, size: 0.35, every: 4, offset: 0, seconds: 1.50, delay: 0.30, tone: 2),
    ]

    private func tone(_ index: Int) -> RGB {
        switch index {
        case 0: return colors.accent
        case 1: return colors.second
        default: return colors.isDark ? RGB(hex: "#e9e9ee") : RGB(hex: "#2a2a30")
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = Double(geo.size.width)
            let h = Double(geo.size.height)
            let top = h * 0.16
            let track = h * 0.68
            let step = Int((sceneTime(date) / motionStep).rounded())
            ZStack(alignment: .topLeading) {
                // Asphalt, kerbs, lane marks and the start line. Each is a
                // line or two with a dash pattern, which stores far less
                // than drawing every block.
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

                ForEach(Self.cars.indices, id: \.self) { i in
                    car(Self.cars[i], step: step, width: w, top: top, track: track)
                }
            }
            .frame(width: w, height: h, alignment: .topLeading)
            .clipped()
        }
    }

    /// On its step a car crosses from off the left edge to off the right
    /// one. On the next it jumps back to the left, out of sight, and waits.
    private func car(_ car: Car, step: Int, width w: Double, top: Double, track: Double) -> some View {
        let height = track * car.size
        let width = height * 3.4
        let phase = (step + car.offset) % car.every
        let passing = phase == 0
        // At rest, the cars sit spread along the straight.
        let x = motion == .resting
            ? w * (0.25 + car.lane * 0.55)
            : (phase == car.every - 1 ? -width : w + width * 2.1)
        let color = tone(car.tone)
        return ZStack(alignment: .leading) {
            // A streak of speed behind the car.
            Capsule()
                .fill(LinearGradient(colors: [color.color.opacity(0), color.color.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                .frame(width: width * 1.5, height: height * 0.16)
                .offset(x: -width * 1.35, y: height * 0.08)
                .opacity(motion == .resting ? 0 : 1)
            RaceCarShape()
                .fill(color.color)
                .frame(width: width, height: height)
            RaceCarWheels()
                .fill(colors.isDark ? Color.black : Color(white: 0.12))
                .frame(width: width, height: height)
        }
        .frame(width: width, height: height, alignment: .leading)
        .position(x: x, y: top + track * car.lane)
        .animation(motion.animation(.linear(duration: car.seconds).delay(car.delay), snap: !passing), value: date)
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

/// An open-wheel race car from the side, nose to the right. An original
/// outline, not any team's or maker's car.
struct RaceCarShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Drawn on a 100 x 30 grid.
        let sx = rect.width / 100
        let sy = rect.height / 30
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var p = Path()
        // Rear wing.
        p.addRect(CGRect(origin: pt(1, 4), size: CGSize(width: 4 * sx, height: 13 * sy)))
        p.addRect(CGRect(origin: pt(1, 4), size: CGSize(width: 13 * sx, height: 3.5 * sy)))
        // Body: engine cover, cockpit, nose.
        p.move(to: pt(6, 22))
        p.addLine(to: pt(8, 15))
        p.addLine(to: pt(26, 12))
        p.addQuadCurve(to: pt(40, 6), control: pt(33, 6.5))
        p.addLine(to: pt(46, 6))
        p.addQuadCurve(to: pt(52, 13), control: pt(50, 7))
        p.addLine(to: pt(70, 15.5))
        p.addQuadCurve(to: pt(97, 21), control: pt(88, 17.5))
        p.addLine(to: pt(98, 23.5))
        p.addLine(to: pt(6, 23.5))
        p.closeSubpath()
        // Front wing.
        p.addRect(CGRect(origin: pt(90, 23), size: CGSize(width: 10 * sx, height: 3 * sy)))
        // Driver's helmet.
        p.addEllipse(in: CGRect(origin: pt(44.5, 5.5), size: CGSize(width: 7 * sx, height: 6.5 * sy)))
        return p
    }
}

/// The car's two wheels.
struct RaceCarWheels: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 100
        let sy = rect.height / 30
        var p = Path()
        for x in [18.0, 78.0] {
            let r = 7.0 * sy
            p.addEllipse(in: CGRect(x: rect.minX + x * sx - r, y: rect.minY + 22.5 * sy - r, width: r * 2, height: r * 2))
        }
        return p
    }
}
