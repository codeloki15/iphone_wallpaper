import SwiftUI

// The widget designs, as plain SwiftUI views. The widget extension wraps
// them with WidgetKit backgrounds; the app shows them in its preview.

/// "It's Saturday." / OCTOBER, and the time as words.
struct DaySentenceView: View {
    let date: Date
    let colors: WidgetColors

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("It's \(TimeWords.weekday(date)).")
                .font(.system(size: 26, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(TimeWords.month(date).uppercased())
                .font(.system(size: 14, weight: .bold))
                .tracking(1.5)
            Spacer(minLength: 4)
            HStack {
                Text("Time now \(TimeWords.time(date))")
                Spacer()
                Text("\(TimeWords.day(date)) \(TimeWords.month(date))")
            }
            .font(.system(size: 11, weight: .medium))
            .opacity(0.75)
        }
        .foregroundStyle(colors.ink.color)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// SATURDAY / OCTOBER and a big, thin date.
struct BigDateView: View {
    let date: Date
    let colors: WidgetColors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(TimeWords.weekday(date).uppercased())
                .font(.system(size: 12, weight: .bold))
            Text(TimeWords.month(date).uppercased())
                .font(.system(size: 12, weight: .bold))
                .padding(.leading, 34)
            Text(TimeWords.period(date))
                .font(.system(size: 10, weight: .medium))
                .opacity(0.7)
                .padding(.top, 4)
            Spacer(minLength: 0)
            Text(TimeWords.day(date))
                .font(.system(size: 64, weight: .ultraLight))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .foregroundStyle(colors.ink.color)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// "Satur–" / "day", the time as a sentence, and how much of today is gone.
struct DayHeadlineView: View {
    let date: Date
    let colors: WidgetColors

    private var dayFraction: Double {
        let start = Calendar.current.startOfDay(for: date)
        return min(max(date.timeIntervalSince(start) / 86_400, 0), 1)
    }

    var body: some View {
        let parts = TimeWords.dayParts(date)
        VStack(alignment: .leading, spacing: 0) {
            Text(parts.0)
                .font(.system(size: 28, weight: .semibold))
            Text(parts.1)
                .font(.system(size: 76, weight: .ultraLight))
                .padding(.top, -10)
            Text(TimeWords.sentence(date))
                .font(.system(size: 14, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            Spacer(minLength: 8)
            WeekStrip(date: date, colors: colors)
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Int(dayFraction * 100))% of today")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.8)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(colors.ink.color.opacity(0.18))
                        Capsule().fill(colors.accent.color).frame(width: geo.size.width * dayFraction)
                    }
                }
                .frame(height: 6)
            }
        }
        .foregroundStyle(colors.ink.color)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// This week's dates, Sunday first, with today marked.
private struct WeekStrip: View {
    let date: Date
    let colors: WidgetColors

    private static let letters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: date) - 1
        let onAccent = colors.accent.luminance > 0.5 ? RGB(hex: "#111114") : RGB.white
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                let day = calendar.date(byAdding: .day, value: i - today, to: date) ?? date
                let isToday = i == today
                VStack(spacing: 5) {
                    Text(Self.letters[i])
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.55)
                    Text(TimeWords.day(day))
                        .font(.system(size: 15, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? onAccent.color : colors.ink.color)
                        .frame(width: 30, height: 30)
                        .background(isToday ? colors.accent.color : Color.clear, in: Circle())
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Live seconds
//
// Widgets can't run their own animations, but the system keeps two kinds of
// view moving by itself, on the Home Screen and the Lock Screen: timer text
// and timer-driven progress views. The seconds below are built from those,
// so they keep running between timeline updates.

/// The minute `date` falls in.
func minuteInterval(_ date: Date) -> ClosedRange<Date> {
    let start = Calendar.current.dateInterval(of: .minute, for: date)?.start ?? date
    return start...start.addingTimeInterval(60)
}

/// The seconds of the current minute as two ticking digits. Set the font
/// from outside.
struct LiveSeconds: View {
    let date: Date

    var body: some View {
        // Timer text reads "0:07", and later "1:07". Two hidden digits set
        // the size; the timer is pinned to their trailing edge and clipped,
        // so only its last two digits, the seconds, ever show. In a widget,
        // timer text fills whatever width it is offered and keeps its digits
        // at the leading edge unless told otherwise, hence the fixed frame
        // with trailing alignment.
        Text("00")
            .monospacedDigit()
            .hidden()
            .overlay(alignment: .trailing) {
                Text(minuteInterval(date).lowerBound, style: .timer)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .frame(width: 240, alignment: .trailing)
            }
            .clipped()
    }
}

/// A second hand for a ring: a track, an arc that grows through the minute,
/// and a dot that leads it round, ticking once a second. Color it with `.tint`.
struct SecondsSweep: View {
    let date: Date

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            // The same proportions as the font's arc (tools/make_motion_fonts.py).
            let width = size * 0.065
            let ring = size - width * 2.1
            ZStack {
                Circle()
                    .stroke(.tint.opacity(0.22), lineWidth: width)
                    .frame(width: ring, height: ring)
                TimerGlyph(font: .sweep, date: date, size: size)
                    .foregroundStyle(.tint)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// True in the widget extension, false in the app.
let isWidgetExtension = Bundle.main.bundlePath.hasSuffix(".appex")

/// A ring that fills once a minute, like a second hand going round. Color
/// it with `.tint`.
struct SecondsRing: View {
    let date: Date

    var body: some View {
        if isWidgetExtension {
            // Only the system can keep a widget moving, and it draws a
            // timer-driven circular progress view as a ring there.
            ProgressView(timerInterval: minuteInterval(date), countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                .progressViewStyle(.circular)
        } else {
            // Inside an app the same view draws as a spinner, so the app's
            // previews draw the ring themselves.
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                GeometryReader { geo in
                    let width = max(2, min(geo.size.width, geo.size.height) * 0.07)
                    let seconds = context.date.timeIntervalSince(minuteInterval(context.date).lowerBound)
                    ZStack {
                        Circle().stroke(.tint.opacity(0.22), lineWidth: width)
                        Circle()
                            .trim(from: 0, to: min(max(seconds / 60, 0), 1))
                            .stroke(.tint, style: StrokeStyle(lineWidth: width, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .padding(width / 2)
                }
            }
        }
    }
}

/// A bar that fills once a minute.
struct SecondsBar: View {
    let date: Date

    var body: some View {
        ProgressView(timerInterval: minuteInterval(date), countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
            .progressViewStyle(.linear)
    }
}

/// Lock Screen (circular): the seconds inside a ring that fills each minute.
struct SecondsRingView: View {
    let date: Date

    var body: some View {
        ZStack {
            SecondsRing(date: date)
            LiveSeconds(date: date)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
        }
    }
}

/// Lock Screen (rectangular): the time with running seconds, over a bar
/// that fills each minute.
struct RunningClockView: View {
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(TimeWords.weekday(date).uppercased()) \u{00B7} \(TimeWords.day(date)) \(TimeWords.month(date).prefix(3).uppercased())")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .opacity(0.8)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                Text(":")
                LiveSeconds(date: date)
            }
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .monospacedDigit()
            SecondsBar(date: date)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Dial

/// The dial: the hour inside a ring that sweeps once a minute, minutes on a
/// curved scale with the current minute in a pill at three o'clock, and the
/// date with ticking seconds to the right.
struct DialClockView: View {
    let date: Date
    let colors: WidgetColors

    var body: some View {
        GeometryReader { geo in
            DialFace(
                g: DialGeometry(width: Double(geo.size.width), height: Double(geo.size.height)),
                date: date,
                ink: colors.ink.color,
                accent: colors.accent.color
            )
        }
    }
}

/// Positions for the dial, in points.
struct DialGeometry {
    /// The dial is laid out on a grid 71 units wide; `k` is one unit.
    let k: Double
    let cx: Double
    let cy: Double
    let rm: Double
    /// Left edge of the date block.
    let dateX: Double
    let width: Double
    let height: Double
    let maxAngle = 58.0 * Double.pi / 180
    let step = 3.2 * Double.pi / 180

    init(width: Double, height: Double) {
        // Ticks fade out toward both ends of the scale, so the arc may run a
        // little past the top and bottom of the space it is given.
        let reach = 27.6 * sin(58.0 * Double.pi / 180)
        k = min(width / 71, height * 0.6 / reach)
        let left = (width - 71 * k) / 2
        cx = left + k * 14
        cy = height / 2
        rm = k * 22
        dateX = cx + rm + k * 10.5
        self.width = width
        self.height = height
    }

    func point(_ angle: Double, _ radius: Double) -> CGPoint {
        CGPoint(x: cx + cos(angle) * radius, y: cy + sin(angle) * radius)
    }

    /// Minutes from `current` to `v`, wrapped to -30...29.
    func delta(_ v: Int, _ current: Int) -> Int {
        (v - current + 90) % 60 - 30
    }
}

private struct DialFace: View {
    let g: DialGeometry
    let date: Date
    let ink: Color
    let accent: Color

    private var minute: Int { Calendar.current.component(.minute, from: date) }
    private var hour: Int {
        let h = Calendar.current.component(.hour, from: date) % 12
        return h == 0 ? 12 : h
    }

    var body: some View {
        let pillWidth = g.k * 11
        let pillLeft = g.cx + g.rm - pillWidth * 0.32
        ZStack(alignment: .topLeading) {
            DialScale(g: g, current: minute, ink: ink)
            // The second hand's ring sits between the hour and the minute scale.
            SecondsSweep(date: date)
                .tint(accent)
                .frame(width: g.k * 25, height: g.k * 25)
                .position(x: g.cx, y: g.cy)
            Text(String(format: "%02d", hour))
                .font(.system(size: g.k * 11, weight: .light))
                .foregroundStyle(ink)
                .position(x: g.cx, y: g.cy)
            Capsule()
                .stroke(ink, lineWidth: g.k * 0.5)
                .frame(width: pillWidth, height: g.k * 6.2)
                .position(x: pillLeft + pillWidth / 2, y: g.cy)
            Text(String(format: "%02d", minute))
                .font(.system(size: g.k * 4.2, weight: .medium))
                .foregroundStyle(ink)
                .position(x: pillLeft + pillWidth * 0.42, y: g.cy)
            DialDate(date: date, k: g.k)
                .foregroundStyle(ink)
                .frame(width: g.k * 24, alignment: .leading)
                .position(x: g.dateX + g.k * 12, y: g.cy)
        }
    }
}

/// The minute scale. A moving widget stores every timeline entry in full,
/// and iOS caps the total at about 10 MB, so this is drawn with as few views
/// as possible: two paths for the ticks, a label every five minutes, and
/// one gradient mask for the fade toward both ends.
private struct DialScale: View {
    let g: DialGeometry
    let current: Int
    let ink: Color

    /// Minutes on the visible part of the scale, as (value, angle).
    private var marks: [(Int, Double)] {
        (0..<60).compactMap { v in
            let d = g.delta(v, current)
            let angle = -Double(d) * g.step
            // The pill covers the current minute.
            return abs(angle) <= g.maxAngle && abs(d) > 1 ? (v, angle) : nil
        }
    }

    private func ticks(major: Bool) -> Path {
        Path { p in
            for (v, angle) in marks where (v % 5 == 0) == major {
                p.move(to: g.point(angle, g.rm + g.k * 3.6))
                p.addLine(to: g.point(angle, g.rm + (major ? g.k * 5.6 : g.k * 4.6)))
            }
        }
    }

    var body: some View {
        let reach = (g.rm + g.k * 5.6) * sin(g.maxAngle)
        let top = max(0, (g.cy - reach) / g.height)
        let bottom = min(1, (g.cy + reach) / g.height)
        let span = bottom - top
        ZStack(alignment: .topLeading) {
            ticks(major: false).stroke(ink.opacity(0.5), lineWidth: g.k * 0.3)
            ticks(major: true).stroke(ink, lineWidth: g.k * 0.45)
            // Labels next to the pill would collide with it.
            ForEach(marks.filter { $0.0 % 5 == 0 && abs(g.delta($0.0, current)) > 3 }, id: \.0) { v, angle in
                Text(String(format: "%02d", v))
                    .font(.system(size: g.k * 3.4, weight: .medium))
                    .foregroundStyle(ink)
                    .position(g.point(angle, g.rm))
            }
        }
        .frame(width: g.width, height: g.height, alignment: .topLeading)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: top),
                    .init(color: .black, location: top + span * 0.42),
                    .init(color: .black, location: top + span * 0.58),
                    .init(color: .clear, location: bottom),
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}

private struct DialDate: View {
    let date: Date
    let k: Double

    var body: some View {
        VStack(alignment: .leading, spacing: k * 1.2) {
            Text("\(TimeWords.day(date)) \(TimeWords.month(date).prefix(3).uppercased())")
                .font(.system(size: k * 2.8, weight: .medium))
                .tracking(k * 0.5)
                .opacity(0.85)
            Text(TimeWords.weekday(date).uppercased())
                .font(.system(size: k * 3.0, weight: .bold))
                .tracking(k * 0.5)
            HStack(alignment: .firstTextBaseline, spacing: k * 0.8) {
                LiveSeconds(date: date)
                    .font(.system(size: k * 4.4, weight: .medium))
                Text("SEC")
                    .font(.system(size: k * 2.2, weight: .semibold))
                    .tracking(k * 0.5)
                    .opacity(0.6)
            }
        }
        .fixedSize()
    }
}

/// Lock Screen: a handwritten signature with the date under it.
struct SignatureView: View {
    let signature: String
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            Text(signature.isEmpty ? "Pocket Walls" : signature)
                .font(.custom("SnellRoundhand-Bold", size: 26))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .rotationEffect(.degrees(-4))
            Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.custom("SnellRoundhand", size: 13))
                .opacity(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Lock Screen: a music label over a waveform that stays the same for a
/// given seed.
struct WaveformView: View {
    let seed: UInt32

    private var bars: [Double] {
        let rand = Rand(seed: seed)
        return (0..<34).map { i in
            let envelope = sin(Double(i) / 34 * .pi) * 0.6 + 0.4
            return max(0.12, envelope * (0.25 + rand() * 0.75))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Music", systemImage: "music.note")
                .font(.system(size: 12, weight: .semibold))
            GeometryReader { geo in
                HStack(alignment: .center, spacing: 1.5) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { _, v in
                        Capsule().frame(height: max(2, geo.size.height * v))
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
