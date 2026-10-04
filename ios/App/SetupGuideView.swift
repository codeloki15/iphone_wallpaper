import SwiftUI

/// The one-time setup, step by step. Everything an app is allowed to do has
/// a button; the rest is a short instruction.
struct SetupGuideView: View {
    @EnvironmentObject private var store: ThemeStore
    @AppStorage("iconChecklist") private var checklist = ""
    @State private var status: String?
    @State private var busy = false

    private var settings: ThemeSettings { store.settings }
    private var theme: Theme { settings.theme }
    private var done: Set<String> { Set(checklist.split(separator: ",").map(String.init)) }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    WallpaperThumb(wall: settings.wallpaper).frame(width: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.wallpaper.name).font(.headline)
                        Text("\(settings.iconStyle.title) icons").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let status {
                    Text(status).font(.footnote.weight(.semibold))
                }
            } header: {
                Text("Your theme")
            } footer: {
                Text("Pick a different theme from the gallery at any time. Widgets update by themselves.")
            }

            Section {
                Step(1, "Tap **Save wallpaper** below. It goes to Photos at this iPhone's exact size.")
                Button { Task { await saveWallpaper() } } label: {
                    Label("Save wallpaper", systemImage: "square.and.arrow.down")
                }
                .disabled(busy)
                Step(2, "In Photos, open it and tap **Share**, then **Use as Wallpaper**, then **Add**.")
                DisclosureGroup("Make it one tap next time") {
                    Step(1, "Open Shortcuts and tap **+** to make a new shortcut.")
                    Step(2, "Add the **Get Current Wallpaper** action (search for Pocket Walls).")
                    Step(3, "Add **Set Wallpaper Photo** after it (on some iOS versions it's called Set Wallpaper). Turn off **Show Preview** if you like.")
                    Step(4, "Name the shortcut **\(ShortcutsLink.wallpaperShortcut)**.")
                    Button("Open Shortcuts") { ShortcutsLink.newShortcut() }
                    Button("Try it now") { ShortcutsLink.runWallpaperShortcut() }
                }
            } header: {
                Text("1 · Wallpaper")
            }

            Section {
                Step(1, "Touch and hold an empty spot on your Home Screen, then tap **Edit** → **Add Widget**.")
                Step(2, "Search for **Pocket Walls** and add **Day Sentence**, **Big Date**, **Dial Clock** or **Day Headline**.")
                Step(3, "That's it: when you pick another theme here, the widgets change with it.")
            } header: {
                Text("2 · Home Screen widgets")
            } footer: {
                Text("iOS only lets you place widgets yourself, so this step is done once.")
            }

            Section {
                TextField("Signature text", text: Binding(
                    get: { store.settings.signature },
                    set: { store.settings.signature = $0 }
                ))
                Step(1, "Touch and hold the Lock Screen, tap **Customize** → **Lock Screen**.")
                Step(2, "Tap the area under the time and add **Signature** or **Waveform** from Pocket Walls.")
                Step(3, "Tap the time and set its color to the clock color below. In the color picker, the **Sliders** tab takes the code.")
                ColorRow(label: "Clock color", color: theme.clock)
            } header: {
                Text("3 · Lock Screen")
            }

            Section {
                Step(1, "Quickest: touch and hold the Home Screen, tap **Edit** → **Customize** → **Tinted**, and pick this color.")
                ColorRow(label: "Icon tint", color: theme.accent)
                Step(2, "Or use the theme's own icons. Save them first:")
                Button { Task { await saveIcons() } } label: {
                    Label("Save 24 icons to Photos", systemImage: "square.grid.2x2")
                }
                .disabled(busy)
                Step(3, "For each app: in Shortcuts tap **+**, add **Open App** and choose the app. Tap the shortcut's name → **Add to Home Screen**, tap the icon, choose the matching one from Photos, then **Add**.")
                Button("Open Shortcuts") { ShortcutsLink.newShortcut() }
                DisclosureGroup("Checklist (\(done.count) of \(AppIconSpec.all.count))") {
                    ForEach(AppIconSpec.all) { icon in
                        Toggle(isOn: Binding(
                            get: { done.contains(icon.id) },
                            set: { on in toggle(icon.id, on) }
                        )) {
                            HStack(spacing: 10) {
                                Image(uiImage: ImageCache.shared.icon(icon.id, style: settings.iconStyle, theme: theme, size: 30))
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                Text(icon.label)
                            }
                        }
                    }
                }
            } header: {
                Text("4 · App icons")
            } footer: {
                Text("iOS doesn't let apps change other apps' icons, so each icon is a shortcut you make once. Opening an app this way can briefly show a Shortcuts banner.")
            }
        }
        .navigationTitle("Set up")
    }

    private func toggle(_ id: String, _ on: Bool) {
        var set = done
        if on { set.insert(id) } else { set.remove(id) }
        checklist = set.sorted().joined(separator: ",")
    }

    @MainActor
    private func saveWallpaper() async {
        busy = true
        defer { busy = false }
        let size = Device.pixelSize
        guard let image = await ImageCache.shared.wallpaper(settings.wallpaper, width: size.width, height: size.height) else {
            status = "The wallpaper couldn't be drawn. Try again."
            return
        }
        do {
            try await PhotoSaver.save([image])
            status = "Saved to Photos."
        } catch {
            status = error.localizedDescription
        }
    }

    @MainActor
    private func saveIcons() async {
        busy = true
        defer { busy = false }
        let theme = self.theme
        let style = settings.iconStyle
        let images = AppIconSpec.all.map { IconRenderer.image($0.id, size: 512, style: style, theme: theme) }
        do {
            try await PhotoSaver.save(images)
            status = "Saved 24 icons to Photos."
        } catch {
            status = error.localizedDescription
        }
    }
}

/// A numbered instruction. Markdown in the text (**bold**) is rendered.
private struct Step: View {
    let number: Int
    let text: String

    init(_ number: Int, _ text: String) {
        self.number = number
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 20, height: 20)
                .background(.white.opacity(0.12), in: Circle())
            Text(LocalizedStringKey(text))
                .font(.subheadline)
        }
    }
}
