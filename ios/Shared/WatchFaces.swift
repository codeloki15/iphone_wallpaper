import SwiftUI

// Watch-face widgets. The dial (case, bezel, markers, sub-dials) is an
// image made by tools/make_watch_faces.py; everything that moves is drawn
// here on top of it. The designs are original: no brand names or logos.
//
// Distances are in case radii, as in the generator: 1 is the case's edge.

enum WatchFace: String, CaseIterable, Identifiable {
    case diver, gmt, chrono, orrery

    var id: String { rawValue }
    var image: String { "watch-\(rawValue)" }

    var title: String {
        switch self {
        case .diver: return "Diver"
        case .gmt: return "Traveller"
        case .chrono: return "Chronograph"
        case .orrery: return "Skeleton"
        }
    }

    var summary: String {
        switch self {
        case .diver: return "A dive watch with a minute bezel, luminous markers and the date."
        case .gmt: return "A travel watch: the arrow hand shows world time on a day-and-night bezel."
        case .chrono: return "A chronograph with a sweeping red hand and dials for the hour, weekday and date."
        case .orrery: return "An open-worked watch with a swinging balance and a globe that circles once a minute."
        }
    }
}

/// A watch hand pointing to 12, in a square the size of the dial. It runs
/// from `start` (negative for a tail behind the center) to `length`, as wide
/// as `width` at the start and `tipWidth` where the point begins.
struct HandShape: Shape {
    var start: Double
    var length: Double
    var width: Double
    var tipWidth: Double
    /// How long the pointed end is. 0 gives a square end.
    var point: Double = 0

    func path(in rect: CGRect) -> Path {
        let unit = Double(min(rect.width, rect.height)) / 2 * 0.985
        let cx = Double(rect.midX)
        let cy = Double(rect.midY)
        func pt(_ x: Double, _ out: Double) -> CGPoint { CGPoint(x: cx + x * unit, y: cy - out * unit) }
        var p = Path()
        p.move(to: pt(-width / 2, start))
        p.addLine(to: pt(-tipWidth / 2, length - point))
        if point > 0 { p.addLine(to: pt(0, length)) }
        p.addLine(to: pt(tipWidth / 2, length - point))
        p.addLine(to: pt(width / 2, start))
        p.closeSubpath()
        return p
    }
}

/// A circle `radius` across its half-width, `out` case radii from the center
/// toward 12. Used for hand tips, the center cap and orbiting parts.
struct DotShape: Shape {
    var out: Double
    var radius: Double

    func path(in rect: CGRect) -> Path {
        let unit = Double(min(rect.width, rect.height)) / 2 * 0.985
        let r = radius * unit
        return Path(ellipseIn: CGRect(x: Double(rect.midX) - r, y: Double(rect.midY) - out * unit - r, width: r * 2, height: r * 2))
    }
}

struct WatchFaceView: View {
    let face: WatchFace
    let date: Date
    var motion: Motion = .running

    // Angles in degrees, clockwise from 12.
    private var t: Double { sceneTime(date) }
    private var hourAngle: Double {
        let hour = Double(Calendar.current.component(.hour, from: date) % 12)
        return (hour * 3600 + t) / 43_200 * 360
    }
    private var minuteAngle: Double { t / 3600 * 360 }
    private var secondAngle: Double { t * 6 }
    /// Glides between entries, and snaps when the hour turns and the angles start again.
    private var glide: Animation? { motion.animation(wraps: t < motionStep) }
    private var steel: LinearGradient {
        LinearGradient(colors: [Color(white: 0.97), Color(white: 0.62)], startPoint: .leading, endPoint: .trailing)
    }
    private let lume = Color(red: 0.93, green: 0.94, blue: 0.89)
    private let handShadow = Color.black.opacity(0.45)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let unit = Double(size) / 2 * 0.985
            ZStack {
                Image(face.image)
                    .resizable()
                switch face {
                case .diver: diver(unit: unit)
                case .gmt: traveller(unit: unit)
                case .chrono: chronograph(unit: unit)
                case .orrery: skeleton(unit: unit)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Shared pieces

    /// A hand with a luminous strip, turned to `angle`.
    private func lumeHand(_ metal: HandShape, _ strip: HandShape, angle: Double, unit: Double) -> some View {
        ZStack {
            metal.fill(steel)
            strip.fill(lume)
        }
        .shadow(color: handShadow, radius: unit * 0.02, y: unit * 0.02)
        .rotationEffect(.degrees(angle))
        .animation(glide, value: date)
    }

    /// The second hand: hidden while the widget rests, since it can't move then.
    private func secondHand<S: ShapeStyle>(_ style: S, length: Double, dotAt: Double?, unit: Double) -> some View {
        ZStack {
            HandShape(start: -0.18, length: length, width: 0.014, tipWidth: 0.008).fill(style)
            if let dotAt { DotShape(out: dotAt, radius: 0.034).fill(style) }
        }
        .shadow(color: handShadow, radius: unit * 0.015, y: unit * 0.02)
        .rotationEffect(.degrees(secondAngle))
        .opacity(motion == .resting ? 0 : 1)
        .animation(glide, value: date)
    }

    private func cap<S: ShapeStyle>(_ style: S, radius: Double = 0.045) -> some View {
        DotShape(out: 0, radius: radius).fill(style)
    }

    /// The date, in the window at 3 o'clock.
    private func dateText(unit: Double) -> some View {
        Text(TimeWords.day(date))
            .font(.system(size: unit * 0.115, weight: .bold))
            .foregroundStyle(Color(white: 0.08))
            .offset(x: unit * 0.50)
    }

    // MARK: Faces

    @ViewBuilder
    private func diver(unit: Double) -> some View {
        dateText(unit: unit)
        lumeHand(
            HandShape(start: -0.07, length: 0.38, width: 0.085, tipWidth: 0.115, point: 0.08),
            HandShape(start: 0.11, length: 0.34, width: 0.045, tipWidth: 0.07, point: 0.055),
            angle: hourAngle, unit: unit)
        lumeHand(
            HandShape(start: -0.08, length: 0.60, width: 0.07, tipWidth: 0.07, point: 0.06),
            HandShape(start: 0.13, length: 0.555, width: 0.034, tipWidth: 0.034, point: 0.04),
            angle: minuteAngle, unit: unit)
        secondHand(Color(white: 0.92), length: 0.62, dotAt: 0.43, unit: unit)
        cap(steel)
    }

    @ViewBuilder
    private func traveller(unit: Double) -> some View {
        dateText(unit: unit)
        // The arrow hand goes round once a day and reads world time (UTC)
        // against the 24-hour bezel.
        let utc = Double(date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400))
        ZStack {
            HandShape(start: -0.06, length: 0.60, width: 0.016, tipWidth: 0.016).fill(Color(red: 0.95, green: 0.45, blue: 0.16))
            HandShape(start: 0.55, length: 0.685, width: 0.12, tipWidth: 0.0, point: 0.0).fill(Color(red: 0.95, green: 0.45, blue: 0.16))
        }
        .shadow(color: handShadow, radius: unit * 0.015, y: unit * 0.015)
        .rotationEffect(.degrees(utc / 86_400 * 360))
        .animation(glide, value: date)
        lumeHand(
            HandShape(start: -0.07, length: 0.37, width: 0.075, tipWidth: 0.075, point: 0.05),
            HandShape(start: 0.11, length: 0.33, width: 0.036, tipWidth: 0.036, point: 0.035),
            angle: hourAngle, unit: unit)
        lumeHand(
            HandShape(start: -0.08, length: 0.60, width: 0.06, tipWidth: 0.06, point: 0.05),
            HandShape(start: 0.13, length: 0.56, width: 0.028, tipWidth: 0.028, point: 0.035),
            angle: minuteAngle, unit: unit)
        secondHand(Color(white: 0.92), length: 0.63, dotAt: nil, unit: unit)
        cap(steel)
    }

    @ViewBuilder
    private func chronograph(unit: Double) -> some View {
        let calendar = Calendar.current
        let hour24 = Double(calendar.component(.hour, from: date)) + t / 3600
        let weekday = Double(calendar.component(.weekday, from: date) - 1)
        let day = Double(calendar.component(.day, from: date) - 1)
        // Sub-dials: the weekday at 3, the date at 6, the 24-hour time at 9.
        subHand(angle: weekday / 7 * 360, x: 0.36, y: 0, unit: unit)
        subHand(angle: day / 31 * 360, x: 0, y: 0.36, unit: unit)
        subHand(angle: hour24 / 24 * 360, x: -0.36, y: 0, unit: unit)
        let ink = Color(white: 0.09)
        ZStack {
            HandShape(start: -0.07, length: 0.37, width: 0.07, tipWidth: 0.05, point: 0.05).fill(ink)
            HandShape(start: 0.10, length: 0.32, width: 0.022, tipWidth: 0.016).fill(Color.white)
        }
        .shadow(color: handShadow, radius: unit * 0.02, y: unit * 0.02)
        .rotationEffect(.degrees(hourAngle))
        .animation(glide, value: date)
        ZStack {
            HandShape(start: -0.08, length: 0.59, width: 0.055, tipWidth: 0.035, point: 0.05).fill(ink)
            HandShape(start: 0.12, length: 0.53, width: 0.018, tipWidth: 0.012).fill(Color.white)
        }
        .shadow(color: handShadow, radius: unit * 0.02, y: unit * 0.02)
        .rotationEffect(.degrees(minuteAngle))
        .animation(glide, value: date)
        secondHand(Color(red: 0.86, green: 0.13, blue: 0.13), length: 0.67, dotAt: nil, unit: unit)
        cap(ink)
        cap(Color(red: 0.86, green: 0.13, blue: 0.13), radius: 0.02)
    }

    private func subHand(angle: Double, x: Double, y: Double, unit: Double) -> some View {
        ZStack {
            HandShape(start: -0.03, length: 0.15, width: 0.022, tipWidth: 0.008).fill(Color.white)
            DotShape(out: 0, radius: 0.02).fill(Color.white)
        }
        .rotationEffect(.degrees(angle))
        .offset(x: x * unit, y: y * unit)
        .animation(glide, value: date)
    }

    @ViewBuilder
    private func skeleton(unit: Double) -> some View {
        let gold = Color(red: 0.86, green: 0.66, blue: 0.48)
        let step = Int((t / motionStep).rounded())
        // The balance wheel swings one way, then the other, each step.
        // (Inside the wheel's own frame, HandShape measures from the wheel's
        // radius, so these two spokes span it.)
        ZStack {
            Circle().stroke(gold, lineWidth: unit * 0.026)
            HandShape(start: -0.95, length: 0.95, width: 0.13, tipWidth: 0.13).fill(gold)
            HandShape(start: -0.95, length: 0.95, width: 0.13, tipWidth: 0.13).fill(gold).rotationEffect(.degrees(90))
        }
        .frame(width: unit * 0.30, height: unit * 0.30)
        .rotationEffect(.degrees(motion == .resting ? 0 : (step % 2 == 0 ? 42 : -42)))
        .offset(y: unit * 0.45)
        .animation(motion.animation(.easeInOut(duration: motionStep)), value: date)
        // A globe circles the dial once a minute, and a gem goes round
        // once in five.
        Circle()
            .fill(LinearGradient(
                colors: [Color(red: 0.55, green: 0.85, blue: 0.95), Color(red: 0.10, green: 0.32, blue: 0.62)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: unit * 0.14, height: unit * 0.14)
            .offset(y: -unit * 0.635)
            .rotationEffect(.degrees(secondAngle))
            .animation(glide, value: date)
        Circle()
            .fill(Color(white: 0.92))
            .frame(width: unit * 0.075, height: unit * 0.075)
            .offset(y: -unit * 0.635)
            .rotationEffect(.degrees(180 + t * 1.2))
            .animation(glide, value: date)
        // Open-worked hands: outlines only, so the movement shows through.
        HandShape(start: -0.06, length: 0.40, width: 0.09, tipWidth: 0.11, point: 0.10)
            .stroke(gold, lineWidth: unit * 0.022)
            .shadow(color: handShadow, radius: unit * 0.02, y: unit * 0.02)
            .rotationEffect(.degrees(hourAngle))
            .animation(glide, value: date)
        HandShape(start: -0.07, length: 0.60, width: 0.07, tipWidth: 0.085, point: 0.10)
            .stroke(gold, lineWidth: unit * 0.02)
            .shadow(color: handShadow, radius: unit * 0.02, y: unit * 0.02)
            .rotationEffect(.degrees(minuteAngle))
            .animation(glide, value: date)
        cap(gold, radius: 0.05)
    }
}
