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
    }
}

/// Every widget shows the theme chosen in the app, refreshed each minute
/// so the time words stay current.
struct ThemeEntry: TimelineEntry {
    let date: Date
    let settings: ThemeSettings
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
        let entries = (0..<60).map { i in
            ThemeEntry(date: start.addingTimeInterval(Double(i) * 60), settings: settings)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
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

struct DialClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DialClock", provider: ThemeProvider()) { entry in
            DialClockView(date: entry.date, colors: entry.settings.widgetColors)
                .themedBackground(entry)
        }
        .configurationDisplayName("Dial Clock")
        .description("The hour, with minutes on a curved scale.")
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
