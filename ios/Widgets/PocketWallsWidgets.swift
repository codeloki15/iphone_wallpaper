import SwiftUI
import WidgetKit

@main
struct PocketWallsWidgetBundle: WidgetBundle {
    var body: some Widget {
        DaySentenceWidget()
        BigDateWidget()
        DialClockWidget()
        DayHeadlineWidget()
        SignatureWidget()
        WaveformWidget()
        SecondsRingWidget()
        RunningClockWidget()
    }
}

/// Every widget shows the theme chosen in the app, with an entry for each
/// minute so the time words stay current. Seconds run by themselves between
/// entries (see "Live seconds" in WidgetViews.swift).
struct ThemeEntry: TimelineEntry {
    let date: Date
    let settings: ThemeSettings
    var motion: Motion = .resting
}

struct ThemeProvider: TimelineProvider {
    func placeholder(in context: Context) -> ThemeEntry {
        ThemeEntry(date: Date(), settings: ThemeSettings.load())
    }

    func getSnapshot(in context: Context, completion: @escaping (ThemeEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ThemeEntry>) -> Void) {
        let settings = ThemeSettings.load()
        let now = Date()
        let start = Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
        // Two hours of entries, refreshed after one, so a late refresh
        // still has minutes to show.
        let entries = (0..<120).map { i in
            ThemeEntry(date: start.addingTimeInterval(Double(i) * 60), settings: settings)
        }
        completion(Timeline(entries: entries, policy: .after(start.addingTimeInterval(3600))))
    }
}

private extension View {
    /// The widget card in the theme's colors.
    func themedBackground(_ entry: ThemeEntry) -> some View {
        containerBackground(for: .widget) {
            entry.settings.widgetColors.background.color
        }
    }
}

struct DaySentenceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DaySentence", provider: ThemeProvider()) { entry in
            DaySentenceView(date: entry.date, colors: entry.settings.widgetColors)
                .themedBackground(entry)
        }
        .configurationDisplayName("Day Sentence")
        .description("\u{201C}It's Saturday.\u{201D} with the month and the time in words, in your theme.")
        .supportedFamilies([.systemMedium])
    }
}

struct BigDateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BigDate", provider: ThemeProvider()) { entry in
            BigDateView(date: entry.date, colors: entry.settings.widgetColors)
                .themedBackground(entry)
        }
        .configurationDisplayName("Big Date")
        .description("The day and month with a big, thin date.")
        .supportedFamilies([.systemSmall])
    }
}

/// A timeline for widgets that move. WidgetKit animates a widget only when
/// it goes from one entry to the next, and for two seconds at most, so
/// continuous motion needs entries `motionStep` apart, each animating
/// linearly into the next.
///
/// iOS stores every entry's view and rejects a timeline over about 10 MB
/// (it then leaves the widget alone for an hour), so the moving run is
/// limited: `movingMinutes` must suit how heavy the widget's view is. After
/// the run come entries a minute apart, drawn still, so the widget stays
/// correct if iOS is slow to ask for the next timeline.
struct MotionProvider: TimelineProvider {
    let movingMinutes: Int
    private let restingMinutes = 90

    func placeholder(in context: Context) -> ThemeEntry {
        ThemeEntry(date: Date(), settings: ThemeSettings.load())
    }

    func getSnapshot(in context: Context, completion: @escaping (ThemeEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ThemeEntry>) -> Void) {
        let settings = ThemeSettings.load()
        let now = Date().timeIntervalSinceReferenceDate
        let start = Date(timeIntervalSinceReferenceDate: (now / motionStep).rounded(.down) * motionStep)
        var count = Int(Double(movingMinutes) * 60 / motionStep)
        #if DEBUG
        // pocketwalls://debug/entries/<n> sets this, to measure archive sizes.
        let override = AppGroup.defaults.integer(forKey: "debugMotionEntries")
        if override > 0 { count = override }
        #endif
        var entries = (0..<count).map { i in
            ThemeEntry(
                date: start.addingTimeInterval(Double(i) * motionStep),
                settings: settings,
                motion: i == 0 ? .starting : .running
            )
        }
        let movingEnd = start.addingTimeInterval(Double(count) * motionStep)
        let firstMinute = Calendar.current.dateInterval(of: .minute, for: movingEnd)?.end ?? movingEnd
        entries.append(ThemeEntry(date: movingEnd, settings: settings, motion: .resting))
        for i in 0..<restingMinutes {
            entries.append(ThemeEntry(date: firstMinute.addingTimeInterval(Double(i) * 60), settings: settings, motion: .resting))
        }
        // Ask for the next moving run as this one ends.
        completion(Timeline(entries: entries, policy: .after(movingEnd)))
    }
}

struct DialClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DialClock", provider: MotionProvider(movingMinutes: 8)) { entry in
            DialClockView(date: entry.date, colors: entry.settings.widgetColors, motion: entry.motion)
                .themedBackground(entry)
        }
        .configurationDisplayName("Dial Clock")
        .description("The hour inside a ring that sweeps every minute, minutes on a curved scale, and running seconds.")
        .supportedFamilies([.systemMedium])
    }
}

struct DayHeadlineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayHeadline", provider: ThemeProvider()) { entry in
            DayHeadlineView(date: entry.date, colors: entry.settings.widgetColors)
                .themedBackground(entry)
        }
        .configurationDisplayName("Day Headline")
        .description("\u{201C}Satur\u{2013}day\u{201D}, the time as a sentence, and how much of today has passed.")
        .supportedFamilies([.systemLarge])
    }
}

struct SignatureWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Signature", provider: ThemeProvider()) { entry in
            SignatureView(signature: entry.settings.signature, date: entry.date)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Signature")
        .description("Your signature in handwriting, for the Lock Screen. Change the text in the app.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct WaveformWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Waveform", provider: ThemeProvider()) { entry in
            WaveformView(seed: entry.settings.wallpaper.seed)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Waveform")
        .description("A music waveform for the Lock Screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct SecondsRingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SecondsRing", provider: ThemeProvider()) { entry in
            SecondsRingView(date: entry.date)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Seconds Ring")
        .description("Running seconds inside a ring that fills every minute, for the Lock Screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct RunningClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RunningClock", provider: ThemeProvider()) { entry in
            RunningClockView(date: entry.date)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Running Clock")
        .description("The time with running seconds and a bar that fills every minute, for the Lock Screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}
