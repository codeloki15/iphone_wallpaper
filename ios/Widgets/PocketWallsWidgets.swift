import AppIntents
import SwiftUI
import WidgetKit

@main
struct PocketWallsWidgetBundle: WidgetBundle {
    var body: some Widget {
        MovingWidgets().body
        FigureWidgets().body
        WatchWidgets().body
        ClockWidgets().body
    }
}

/// Line-art figures that play at eight frames a second (FrameFigures.swift).
struct FigureWidgets: WidgetBundle {
    var body: some Widget {
        FigureGlobeWidget()
        FigureDeckWidget()
        FigureCradleWidget()
        FigureLighthouseWidget()
        FigureRipplesWidget()
        FigureSculptureWidget()
        FigureSwellWidget()
    }
}

/// Widgets that move: scenes drawn in MotionScenes.swift and Zodiac.swift.
struct MovingWidgets: WidgetBundle {
    var body: some Widget {
        OrbitWidget()
        ZodiacWidget()
        RaceWidget()
        RiversUSAWidget()
        RiversAsiaWidget()
        RiversCanadaWidget()
        RiversJapanWidget()
    }
}

/// Watch faces: dials drawn by tools/make_watch_faces.py, hands in WatchFaces.swift.
struct WatchWidgets: WidgetBundle {
    var body: some Widget {
        WatchDiverWidget()
        WatchTravellerWidget()
        WatchChronoWidget()
        WatchSkeletonWidget()
        WatchEngineWidget()
        WatchRouletteWidget()
        WatchCarouselWidget()
        WatchDragonWidget()
    }
}

struct ClockWidgets: WidgetBundle {
    var body: some Widget {
        DialClockWidget()
        DaySentenceWidget()
        BigDateWidget()
        DayHeadlineWidget()
        SignatureWidget()
        WaveformWidget()
        SecondsRingWidget()
        RunningClockWidget()
    }
}

/// Every widget shows the theme chosen in the app, with an entry for each
/// minute so the time words and the watch hands stay current. Seconds run
/// by themselves between entries (see "Live seconds" in WidgetViews.swift
/// and MotionFonts.swift).
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

/// A timeline for a widget whose motion is all timer text in a motion font
/// (MotionFonts.swift). iOS keeps that moving by itself, and the fonts go
/// on working however many hours the timer has run, so the widget needs an
/// entry only now and then. Fewer entries also keep the stored timeline
/// small: each one holds every timer in the widget, and a figure has 33.
struct TimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> ThemeEntry {
        ThemeEntry(date: Date(), settings: ThemeSettings.load())
    }

    func getSnapshot(in context: Context, completion: @escaping (ThemeEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ThemeEntry>) -> Void) {
        let settings = ThemeSettings.load()
        let start = hourStart(Date())
        // An entry every six hours for a day, refreshed after half of it.
        let entries = (0..<4).map { i in
            ThemeEntry(date: start.addingTimeInterval(Double(i) * 6 * 3600), settings: settings)
        }
        completion(Timeline(entries: entries, policy: .after(start.addingTimeInterval(12 * 3600))))
    }
}

struct DialClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DialClock", provider: ThemeProvider()) { entry in
            DialClockView(date: entry.date, colors: entry.settings.widgetColors)
                .themedBackground(entry)
        }
        .configurationDisplayName("Dial Clock")
        .description("The hour inside a ring that a dot circles every minute, minutes on a curved scale, and running seconds.")
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

// MARK: - Moving widgets

struct OrbitWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Orbit", provider: TimerProvider()) { entry in
            OrbitView(date: entry.date)
                .containerBackground(for: .widget) { SpaceSky() }
        }
        .configurationDisplayName("Orbit")
        .description("The eight planets circling the sun, each at its own speed, in a dark sky.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

/// The signs to choose from when editing the Zodiac widget.
enum ZodiacChoice: String, AppEnum {
    case current, aries, taurus, gemini, cancer, leo, virgo, libra, scorpio, sagittarius, capricorn, aquarius, pisces

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Sign"
    static var caseDisplayRepresentations: [ZodiacChoice: DisplayRepresentation] = [
        .current: "This month\u{2019}s sign",
        .aries: "Aries", .taurus: "Taurus", .gemini: "Gemini", .cancer: "Cancer",
        .leo: "Leo", .virgo: "Virgo", .libra: "Libra", .scorpio: "Scorpio",
        .sagittarius: "Sagittarius", .capricorn: "Capricorn", .aquarius: "Aquarius", .pisces: "Pisces",
    ]
}

struct ZodiacIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Zodiac"
    static var description = IntentDescription("Choose which constellation the widget shows.")

    @Parameter(title: "Sign", default: .current)
    var sign: ZodiacChoice
}

struct ZodiacEntry: TimelineEntry {
    let date: Date
    let sign: ZodiacSign
}

struct ZodiacProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ZodiacEntry {
        ZodiacEntry(date: Date(), sign: .current(on: Date()))
    }

    func snapshot(for configuration: ZodiacIntent, in context: Context) async -> ZodiacEntry {
        entry(configuration, at: Date())
    }

    func timeline(for configuration: ZodiacIntent, in context: Context) async -> Timeline<ZodiacEntry> {
        // The stars twinkle by themselves (a motion font). There is an
        // entry an hour all the same, because the sign is worked out for
        // each one, and so changes within the hour of the right midnight.
        let start = hourStart(Date())
        let entries = (0..<24).map { entry(configuration, at: start.addingTimeInterval(Double($0) * 3600)) }
        return Timeline(entries: entries, policy: .after(start.addingTimeInterval(12 * 3600)))
    }

    private func entry(_ configuration: ZodiacIntent, at date: Date) -> ZodiacEntry {
        ZodiacEntry(date: date, sign: ZodiacSign.named(configuration.sign.rawValue) ?? .current(on: date))
    }
}

struct ZodiacWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Zodiac", intent: ZodiacIntent.self, provider: ZodiacProvider()) { entry in
            ZodiacView(sign: entry.sign, date: entry.date)
                .containerBackground(for: .widget) { SpaceSky() }
        }
        .configurationDisplayName("Zodiac")
        .description("A constellation of the zodiac with twinkling stars: this month\u{2019}s sign, or one you choose.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct RaceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Race", provider: TimerProvider()) { entry in
            RaceView(date: entry.date, colors: entry.settings.widgetColors)
                .themedBackground(entry)
        }
        .configurationDisplayName("Race Day")
        .description("A race start, again and again: five red lights, lights out, and the cars are away.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

// WidgetKit needs a type of its own for every kind of widget, so each
// region has one; they share this configuration.
private func riversConfiguration(kind: String, region: RiverRegion) -> some WidgetConfiguration {
    // Plain strings: WidgetKit stops the extension if a name or description
    // is built by interpolating into a literal.
    let name: String = "Rivers of " + region.title
    let description: String = "The great rivers of " + region.title + ", with lights drifting from source to mouth."
    return StaticConfiguration(kind: kind, provider: TimerProvider()) { entry in
        RiversView(region: region, date: entry.date, colors: entry.settings.widgetColors)
            .themedBackground(entry)
    }
    .configurationDisplayName(name)
    .description(description)
    .supportedFamilies([.systemMedium, .systemLarge])
}

struct RiversUSAWidget: Widget {
    var body: some WidgetConfiguration { riversConfiguration(kind: "RiversUSA", region: .usa) }
}

struct RiversAsiaWidget: Widget {
    var body: some WidgetConfiguration { riversConfiguration(kind: "RiversAsia", region: .asia) }
}

struct RiversCanadaWidget: Widget {
    var body: some WidgetConfiguration { riversConfiguration(kind: "RiversCanada", region: .canada) }
}

struct RiversJapanWidget: Widget {
    var body: some WidgetConfiguration { riversConfiguration(kind: "RiversJapan", region: .japan) }
}

// MARK: - Figures

private func figureConfiguration(_ figure: FrameFigure) -> some WidgetConfiguration {
    let name: String = figure.title
    let description: String = figure.caption
    return StaticConfiguration(kind: "Figure" + figure.key, provider: TimerProvider()) { entry in
        FrameFigureView(figure: figure, date: entry.date)
            .containerBackground(for: .widget) { FrameFigure.plate }
    }
    .configurationDisplayName(name)
    .description(description)
    .supportedFamilies([.systemMedium, .systemLarge])
    .contentMarginsDisabled()
}

struct FigureGlobeWidget: Widget {
    var body: some WidgetConfiguration { figureConfiguration(.globe) }
}

struct FigureDeckWidget: Widget {
    var body: some WidgetConfiguration { figureConfiguration(.deck) }
}

struct FigureCradleWidget: Widget {
    var body: some WidgetConfiguration { figureConfiguration(.cradle) }
}

struct FigureLighthouseWidget: Widget {
    var body: some WidgetConfiguration { figureConfiguration(.lighthouse) }
}

struct FigureRipplesWidget: Widget {
    var body: some WidgetConfiguration { figureConfiguration(.ripples) }
}

struct FigureSculptureWidget: Widget {
    var body: some WidgetConfiguration { figureConfiguration(.sculpture) }
}

struct FigureSwellWidget: Widget {
    var body: some WidgetConfiguration { figureConfiguration(.swell) }
}

// MARK: - Watch faces

private func watchConfiguration(kind: String, face: WatchFace) -> some WidgetConfiguration {
    let name: String = face.title + " Watch"
    let description: String = face.summary
    return StaticConfiguration(kind: kind, provider: ThemeProvider()) { entry in
        WatchFaceView(face: face, date: entry.date)
            .padding(8)
            .themedBackground(entry)
    }
    .configurationDisplayName(name)
    .description(description)
    .supportedFamilies([.systemSmall, .systemLarge])
    .contentMarginsDisabled()
}

struct WatchDiverWidget: Widget {
    var body: some WidgetConfiguration { watchConfiguration(kind: "WatchDiver", face: .diver) }
}

struct WatchTravellerWidget: Widget {
    var body: some WidgetConfiguration { watchConfiguration(kind: "WatchTraveller", face: .gmt) }
}

struct WatchChronoWidget: Widget {
    var body: some WidgetConfiguration { watchConfiguration(kind: "WatchChrono", face: .chrono) }
}

struct WatchSkeletonWidget: Widget {
    var body: some WidgetConfiguration { watchConfiguration(kind: "WatchSkeleton", face: .orrery) }
}

struct WatchEngineWidget: Widget {
    var body: some WidgetConfiguration { watchConfiguration(kind: "WatchEngine", face: .engine) }
}

struct WatchRouletteWidget: Widget {
    var body: some WidgetConfiguration { watchConfiguration(kind: "WatchRoulette", face: .roulette) }
}

struct WatchCarouselWidget: Widget {
    var body: some WidgetConfiguration { watchConfiguration(kind: "WatchCarousel", face: .carousel) }
}

struct WatchDragonWidget: Widget {
    var body: some WidgetConfiguration { watchConfiguration(kind: "WatchDragon", face: .dragon) }
}
