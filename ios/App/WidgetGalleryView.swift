import SwiftUI

/// Every Pocket Walls widget, live, in the current theme. The same views
/// the widget extension shows.
struct WidgetGalleryView: View {
    @EnvironmentObject private var store: ThemeStore
    @EnvironmentObject private var router: AppRouter

    // Widget sizes in points on a 6.1 to 6.3-inch iPhone.
    private let small = CGSize(width: 158, height: 158)
    private let medium = CGSize(width: 338, height: 158)
    private let large = CGSize(width: 338, height: 354)
    private let circular = CGSize(width: 72, height: 72)
    private let rectangular = CGSize(width: 160, height: 72)

    var body: some View {
        let settings = store.settings
        let colors = settings.widgetColors
        // Whatever moves by the second is timer text that iOS keeps running,
        // here as in the widgets, so the views only need redrawing when
        // the minute changes.
        TimelineView(.everyMinute) { context in
            let date = context.date
            ScrollViewReader { proxy in
                ScrollView {
                    // Lazy, so only the widgets on screen run their timers.
                    LazyVStack(alignment: .leading, spacing: 20) {
                        Text("Moving").font(.title3.weight(.bold))
                        homeWidget("Orbit", "Small, Medium or Large", medium, colors, padding: 0, sky: true) {
                            OrbitView(date: date)
                        }
                        HStack(alignment: .top, spacing: 16) {
                            homeWidget("Orbit", "Small", small, colors, padding: 0, sky: true) {
                                OrbitView(date: date)
                            }
                            homeWidget("Zodiac", "Small", small, colors, padding: 0, sky: true) {
                                ZodiacView(sign: .current(on: date), date: date)
                            }
                        }
                        homeWidget("Zodiac", "Small, Medium or Large", medium, colors, padding: 0, sky: true) {
                            ZodiacView(sign: .current(on: date), date: date)
                        }
                        .id("zodiac")
                        homeWidget("Race Day", "Medium", medium, colors, padding: 0) {
                            RaceView(date: date, colors: colors)
                        }
                        ForEach([RiverRegion.usa, .asia, .canada, .japan], id: \.key) { region in
                            homeWidget("Rivers of \(region.title)", "Medium or Large", medium, colors) {
                                RiversView(region: region, date: date, colors: colors)
                            }
                            .id(region.key == "usa" ? "rivers" : region.key)
                        }

                        Text("Line art").font(.title3.weight(.bold)).padding(.top, 8).id("figures")
                        ForEach(FrameFigure.all) { figure in
                            VStack(alignment: .leading, spacing: 6) {
                                FrameFigureView(figure: figure, date: date)
                                    .frame(width: medium.width, height: medium.height)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                Text("\(figure.title) \u{00B7} Medium or Large")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("Watches").font(.title3.weight(.bold)).padding(.top, 8).id("watches")
                        LazyVGrid(columns: [GridItem(.fixed(small.width), spacing: 16), GridItem(.fixed(small.width))], alignment: .leading, spacing: 16) {
                            ForEach(WatchFace.allCases) { face in
                                homeWidget(face.title, "Small or Large", small, colors, padding: 8) {
                                    WatchFaceView(face: face, date: date)
                                }
                            }
                        }

                        Text("Home Screen").font(.title3.weight(.bold)).padding(.top, 8).id("home")
                        homeWidget("Dial Clock", "Medium", medium, colors) { DialClockView(date: date, colors: colors) }
                        homeWidget("Day Sentence", "Medium", medium, colors) { DaySentenceView(date: date, colors: colors) }
                        homeWidget("Big Date", "Small", small, colors) { BigDateView(date: date, colors: colors) }
                        homeWidget("Day Headline", "Large", large, colors) { DayHeadlineView(date: date, colors: colors) }

                        Text("Lock Screen").font(.title3.weight(.bold)).padding(.top, 8).id("lock")
                        HStack(alignment: .top, spacing: 16) {
                            lockWidget("Seconds Ring", circular) { SecondsRingView(date: date) }
                            lockWidget("Running Clock", rectangular) { RunningClockView(date: date) }
                        }
                        HStack(alignment: .top, spacing: 16) {
                            lockWidget("Signature", rectangular) { SignatureView(signature: settings.signature, date: date) }
                            lockWidget("Waveform", rectangular) { WaveformView(seed: settings.wallpaper.seed) }
                        }

                        Text("To add one, touch and hold your Home Screen or Lock Screen, tap Edit or Customize, and look for Pocket Walls. To pick a Zodiac sign, touch and hold the widget and tap Edit Widget. Everything that moves ticks once a second and never stops.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                // pocketwalls://widgets/<section> opens at "zodiac", "rivers", "figures", "watches", "home" or "lock".
                .onAppear {
                    if let anchor = router.widgetsAnchor { proxy.scrollTo(anchor, anchor: .top) }
                    router.widgetsAnchor = nil
                }
            }
        }
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A Home Screen widget on its themed card, at real size. `padding` is
    /// 0 for scenes that run to the edges; `sky` gives the planets and the
    /// constellations their night sky.
    private func homeWidget<Content: View>(
        _ name: String, _ size: String, _ points: CGSize, _ colors: WidgetColors,
        padding: CGFloat = 16, sky: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
                .padding(padding)
                .frame(width: points.width, height: points.height)
                .background {
                    if sky { SpaceSky() } else { colors.background.color }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text("\(name) \u{00B7} \(size)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    /// A Lock Screen widget, white on a dark tile as iOS draws them.
    private func lockWidget<Content: View>(
        _ name: String, _ points: CGSize,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
                .foregroundStyle(.white)
                .tint(.white)
                .frame(width: points.width, height: points.height)
                .padding(8)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
