import SwiftUI

enum PreviewMode: String, CaseIterable, Identifiable {
    case lock, home

    var id: String { rawValue }
    var title: String { self == .lock ? "Lock Screen" : "Home Screen" }
}

struct DetailView: View {
    let wall: Wallpaper
    let look: Look?

    @EnvironmentObject private var store: ThemeStore
    @State private var mode: PreviewMode = .home
    @State private var style: IconStyle = .color
    @State private var preview: UIImage?
    @State private var luminance: Double?
    @State private var status: String?
    @State private var busy = false

    private var theme: Theme { Theme(wallpaper: wall, backgroundLuminance: luminance) }
    private var signature: String { look?.signature ?? store.settings.signature }
    private var isCurrent: Bool {
        store.settings.wallpaperID == wall.id && store.settings.iconStyle == style
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PhonePreview(image: preview, mode: mode, theme: theme, style: style, signature: signature, seed: wall.seed)
                    .frame(maxHeight: 540)

                Picker("Screen", selection: $mode) {
                    ForEach(PreviewMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Icon style").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Picker("Icon style", selection: $style) {
                        ForEach(IconStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Button {
                    useTheme()
                } label: {
                    Label(isCurrent ? "This is your theme" : "Use this theme",
                          systemImage: isCurrent ? "checkmark.circle.fill" : "paintbrush.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCurrent)

                Text("Your Pocket Walls widgets switch to this theme straight away.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Button { Task { await saveWallpaper() } } label: {
                        Label("Save wallpaper", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                    }
                    Button { Task { await saveIcons() } } label: {
                        Label("Save icons", systemImage: "square.grid.2x2").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(busy)

                if isCurrent {
                    Button {
                        ShortcutsLink.runWallpaperShortcut()
                    } label: {
                        Label("Set wallpaper with one tap", systemImage: "bolt.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Text("Needs the \u{201C}\(ShortcutsLink.wallpaperShortcut)\u{201D} shortcut. The setup guide shows how to make it once.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let status {
                    Text(status)
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ColorRow(label: "Clock color", color: theme.clock)
                ColorRow(label: "Icon tint", color: theme.accent)

                NavigationLink(value: Route.setup) {
                    Label("Setup guide", systemImage: "checklist").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
        }
        .navigationTitle(look?.name ?? wall.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            style = look?.iconStyle ?? (store.settings.wallpaperID == wall.id ? store.settings.iconStyle : .color)
            let size = Device.pixelSize
            // Preview at a third of the screen's pixels: sharp, and quick to draw.
            let image = await ImageCache.shared.wallpaper(wall, width: size.width / 3, height: size.height / 3)
            preview = image
            if let cg = image?.cgImage { luminance = clockAreaLuminance(cg) }
        }
    }

    @MainActor
    private func useTheme() {
        store.settings = ThemeSettings(
            wallpaperID: wall.id,
            iconStyle: style,
            signature: look?.signature ?? store.settings.signature,
            clockLuminance: luminance
        )
        status = "Theme set. Add the Pocket Walls widgets once, and they'll follow every theme you pick."
    }

    @MainActor
    private func saveWallpaper() async {
        busy = true
        defer { busy = false }
        let size = Device.pixelSize
        status = "Rendering \(size.width) × \(size.height)…"
        guard let image = await ImageCache.shared.wallpaper(wall, width: size.width, height: size.height) else {
            status = "The wallpaper couldn't be drawn. Try again."
            return
        }
        do {
            try await PhotoSaver.save([image])
            status = "Saved to Photos. Open it, tap Share, then Use as Wallpaper."
        } catch {
            status = error.localizedDescription
        }
    }

    @MainActor
    private func saveIcons() async {
        busy = true
        defer { busy = false }
        status = "Drawing 24 icons…"
        let theme = self.theme
        let style = self.style
        let images = AppIconSpec.all.map { IconRenderer.image($0.id, size: 512, style: style, theme: theme) }
        do {
            try await PhotoSaver.save(images)
            status = "Saved 24 icons to Photos. The setup guide shows how to put them on your apps."
        } catch {
            status = error.localizedDescription
        }
    }
}

/// A color swatch with its code and a copy button.
struct ColorRow: View {
    let label: String
    let color: RGB
    @State private var copied = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.color)
                .frame(width: 34, height: 34)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.2)))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(color.hex).font(.body.monospacedDigit().weight(.semibold))
            }
            Spacer()
            Button(copied ? "Copied" : "Copy") {
                copyToClipboard(color.hex)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            }
            .buttonStyle(.bordered)
        }
    }
}

/// An iPhone mockup showing the wallpaper with the themed Lock Screen or
/// Home Screen on top.
struct PhonePreview: View {
    let image: UIImage?
    let mode: PreviewMode
    let theme: Theme
    let style: IconStyle
    let signature: String
    let seed: UInt32

    var body: some View {
        TimelineView(.everyMinute) { context in
            GeometryReader { geo in
                let w = geo.size.width
                ZStack {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Color.white.opacity(0.06)
                    }
                    if mode == .lock {
                        lockScreen(width: w, date: context.date)
                    } else {
                        homeScreen(width: w, date: context.date)
                    }
                    VStack {
                        Capsule().fill(.black).frame(width: w * 0.31, height: w * 0.09)
                        Spacer()
                        Capsule().fill(.white.opacity(0.85)).frame(width: w * 0.36, height: w * 0.014)
                    }
                    .padding(.vertical, w * 0.03)
                }
                .frame(width: w, height: geo.size.height)
                .clipShape(RoundedRectangle(cornerRadius: w * 0.13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: w * 0.13, style: .continuous)
                        .stroke(Color(white: 0.12), lineWidth: w * 0.025)
                )
            }
            .aspectRatio(1206.0 / 2622.0, contentMode: .fit)
        }
    }

    private func lockScreen(width w: CGFloat, date: Date) -> some View {
        VStack(spacing: 0) {
            Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.system(size: w * 0.05, weight: .semibold))
            Text(date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                .font(.system(size: w * 0.24, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            HStack(spacing: w * 0.06) {
                WaveformView(seed: seed)
                SignatureView(signature: signature, date: date)
            }
            .frame(height: w * 0.15)
            .padding(.horizontal, w * 0.09)
            .padding(.top, w * 0.02)
            Spacer()
        }
        .foregroundStyle(theme.clock.color)
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .padding(.top, w * 0.16)
    }

    private func homeScreen(width w: CGFloat, date: Date) -> some View {
        let colors = theme.widgetColors(style)
        let pad = w * 0.07
        let columns = Array(repeating: GridItem(.flexible(), spacing: w * 0.06), count: 4)
        return VStack(spacing: w * 0.045) {
            ScaledWidget(base: CGSize(width: 338, height: 158), width: w - pad * 2) {
                DaySentenceView(date: date, colors: colors)
                    .padding(16)
                    .background(colors.background.color)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            LazyVGrid(columns: columns, spacing: w * 0.04) {
                ForEach(AppIconSpec.grid.prefix(12)) { icon in
                    VStack(spacing: w * 0.012) {
                        Image(uiImage: ImageCache.shared.icon(icon.id, style: style, theme: theme))
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: w * 0.04, style: .continuous))
                        Text(icon.label)
                            .font(.system(size: w * 0.027, weight: .medium))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            HStack(spacing: w * 0.06) {
                ForEach(AppIconSpec.dock) { icon in
                    Image(uiImage: ImageCache.shared.icon(icon.id, style: style, theme: theme))
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: w * 0.04, style: .continuous))
                }
            }
            .padding(w * 0.04)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: w * 0.09, style: .continuous))
            .padding(.bottom, w * 0.03)
        }
        .padding(.horizontal, pad)
        .padding(.top, w * 0.17)
        .padding(.bottom, w * 0.02)
    }
}

/// Lays out a widget at its real point size, then scales it to fit.
struct ScaledWidget<Content: View>: View {
    let base: CGSize
    let width: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        let scale = width / base.width
        content()
            .frame(width: base.width, height: base.height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: width, height: base.height * scale, alignment: .topLeading)
    }
}
