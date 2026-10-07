import SwiftUI

// Motion that iOS itself keeps running.
//
// A widget is redrawn only when its timeline moves on to a new entry, with
// one exception: text that shows a running timer, which iOS updates every
// second for as long as the widget is on screen. The fonts in Shared/Fonts
// (made by tools/make_motion_fonts.py) have no letters. Their ligatures turn
// what the timer reads into a single glyph that draws a scene as it should
// look at that second. So a second hand, or a sky full of planets, is one
// `Text` in one of those fonts, and it keeps moving however rarely iOS
// refreshes the widget.

struct MotionFont {
    let name: String

    /// Second hands, colored with `foregroundStyle`.
    static let handDot = MotionFont(name: "PWHandDot")
    static let handNeedle = MotionFont(name: "PWHandNeedle")
    static let handLong = MotionFont(name: "PWHandLong")
    /// The Dial Clock's seconds: a growing arc led by a dot.
    static let sweep = MotionFont(name: "PWSweep")
    /// The Skeleton watch's balance wheel, globe and gem.
    static let skeleton = MotionFont(name: "PWSkeleton")
    /// Whole scenes for a watch dial: pistons, a roulette wheel, an orrery, dragons.
    static let engine = MotionFont(name: "PWEngine")
    static let roulette = MotionFont(name: "PWRoulette")
    static let carousel = MotionFont(name: "PWCarousel")
    static let dragon = MotionFont(name: "PWDragon")
    /// The planets, on round orbits and on tilted ones for a wide widget.
    static let orbit = MotionFont(name: "PWOrbit")
    static let orbitWide = MotionFont(name: "PWOrbitWide")

    /// Race Day: each car's body, all the wheels, and the lit start lights,
    /// each colored with `foregroundStyle`.
    static let raceA = MotionFont(name: "PWRaceA")
    static let raceB = MotionFont(name: "PWRaceB")
    static let raceC = MotionFont(name: "PWRaceC")
    static let raceWheels = MotionFont(name: "PWRaceWheels")
    static let raceLights = MotionFont(name: "PWRaceLights")

    /// A mask for FrameStack: everything on even seconds, nothing on odd ones.
    static let blink = MotionFont(name: "PWBlink")

    /// Sparkles on a constellation's stars.
    static func stars(_ sign: ZodiacSign) -> MotionFont { MotionFont(name: "PWStars" + sign.name) }
    /// Lights drifting down a region's rivers, colored with `foregroundStyle`.
    static func rivers(_ region: RiverRegion) -> MotionFont { MotionFont(name: "PWRivers" + region.key.capitalized) }
}

/// The top of the hour `date` is in. Motion fonts count from the top of an
/// hour, and ignore how many hours have gone by since, so one timeline
/// entry can keep a widget moving for as long as it lasts.
func hourStart(_ date: Date) -> Date {
    Calendar.current.dateInterval(of: .hour, for: date)?.start ?? date
}

/// A scene from a motion font, in a square `size` across, kept moving by iOS.
struct TimerGlyph: View {
    let font: MotionFont
    /// Any moment in the hour being shown.
    let date: Date
    let size: CGFloat
    /// Seconds after the top of the hour that the timer counts from.
    var offset: TimeInterval = 0

    var body: some View {
        // The font turns the whole of the timer's text into one glyph, one
        // `size` wide and tall. In an app the text is that size. In a widget
        // timer text takes all the width it is offered (and with
        // `fixedSize` far more, which pushes the glyph out of sight), so it
        // gets a frame a few glyphs wide with the text pushed to the
        // trailing edge, and the frame is moved to bring that edge's glyph
        // onto this view.
        Text(hourStart(date).addingTimeInterval(offset), style: .timer)
            .font(.custom(font.name, fixedSize: size))
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .frame(width: size * 3, height: size, alignment: .trailing)
            .offset(x: -size)
            .frame(width: size, height: size)
            .unredacted()
            .accessibilityHidden(true)
    }
}

/// Plays a recorded animation at several frames a second, in a square `size`
/// across, though timer text only changes once a second.
///
/// There are twice `fps` layers, each a timer started one frame after the
/// one before, in a font of its own that holds every 2 x fps-th frame. Each
/// layer is uncovered for one frame every two seconds, by a mask that is
/// itself a timer in the blink font (on for a second, off for a second),
/// and while it is covered its timer moves on to its next frame. A frame
/// paints its whole background, so the newest uncovered layer hides the
/// rest. The arrangement is Bryce Bostwick's (WidgetAnimation).
struct FrameStack: View {
    /// The fonts' shared name: layer 3 is drawn in this plus "03".
    let prefix: String
    let fps: Int
    /// Any moment in the hour being shown.
    let date: Date
    let size: CGFloat

    /// Every timer starts a few seconds before the hour, so that none is
    /// still waiting to start when the hour's timeline entry arrives.
    private let lead: TimeInterval = -4

    var body: some View {
        let step = 1 / Double(fps)
        ZStack {
            // The first second of every two: layer 0 is always there, and
            // each later layer covers it one frame after the one before.
            ZStack {
                layer(0, step)
                ForEach(1..<fps, id: \.self) { i in
                    layer(i, step).mask { blink(Double(i) * step) }
                }
            }
            // The second second: the same again, in a stack that is itself
            // only there for that second.
            ZStack {
                ForEach(fps..<(2 * fps), id: \.self) { i in
                    layer(i, step).mask { blink(Double(i) * step) }
                }
            }
            .mask { blink(-1) }
        }
        .frame(width: size, height: size)
    }

    /// A layer's timer runs a second behind its mask, so its glyph changes
    /// at the moment the mask covers it, and not while it is on show.
    private func layer(_ i: Int, _ step: Double) -> some View {
        TimerGlyph(font: MotionFont(name: prefix + String(format: "%02d", i)), date: date, size: size, offset: lead + 1 + Double(i) * step)
    }

    private func blink(_ offset: TimeInterval) -> some View {
        TimerGlyph(font: .blink, date: date, size: size, offset: lead + offset)
    }
}
