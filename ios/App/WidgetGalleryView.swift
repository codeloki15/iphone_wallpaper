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
        TimelineView(.everyMinute) { context in
            let date = context.date
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Home Screen").font(.title3.weight(.bold))
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

                        Text("To add one, touch and hold your Home Screen or Lock Screen, tap Edit or Customize, and look for Pocket Walls. Seconds keep running by themselves.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                // pocketwalls://widgets/lock opens at the Lock Screen widgets.
                .onAppear {
                    if router.widgetsAnchor == "lock" { proxy.scrollTo("lock", anchor: .top) }
                    router.widgetsAnchor = nil
                }
            }
        }
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A Home Screen widget on its themed card, at real size.
    private func homeWidget<Content: View>(
        _ name: String, _ size: String, _ points: CGSize, _ colors: WidgetColors,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
                .padding(16)
                .frame(width: points.width, height: points.height)
                .background(colors.background.color)
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
