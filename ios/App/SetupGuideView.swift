import SwiftUI

/// The one-time setup, step by step. Everything an app is allowed to do has
/// a button; the rest is a short instruction.
struct SetupGuideView: View {
    @EnvironmentObject private var store: ThemeStore
    @ObservedObject private var setup = SetupCoordinator.shared
    @State private var status: String?
    @State private var busy = false

    private var settings: ThemeSettings { store.settings }
    private var theme: Theme { settings.theme }

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
                Text("Do these once. After that, Set up theme on any wallpaper changes your widgets and wallpaper by itself.")
            }

            Section {
                GuideStep(1, "Open Shortcuts and tap **+** to make a new shortcut.")
                Button("Open Shortcuts") { ShortcutsLink.newShortcut() }
                GuideStep(2, "Search for **Pocket Walls** and add **Get Current Wallpaper**.")
                GuideStep(3, "Search for **Set Wallpaper Photo** and add it. Tap its arrow and turn off **Show Preview**.")
                GuideStep(4, "Rename the shortcut to **\(ShortcutsLink.wallpaperShortcut)** and tap **Done**.")
                Button("Try it now") { setup.runWallpaperShortcut() }
                wallpaperStatus
                DisclosureGroup("Or set it by hand") {
                    Button { Task { await saveWallpaper() } } label: {
                        Label("Save wallpaper to Photos", systemImage: "square.and.arrow.down")
                    }
                    .disabled(busy)
                    GuideStep(1, "In Photos, open it and tap **Share**, then **Use as Wallpaper**, then **Add**.")
                }
            } header: {
                Text("1 · Wallpaper shortcut")
            } footer: {
                Text("iOS only lets the Shortcuts app set a wallpaper, so Pocket Walls hands it the image.")
            }

            Section {
                GuideStep(1, "Touch and hold an empty spot on your Home Screen, then tap **Edit** → **Add Widget**.")
                GuideStep(2, "Search for **Pocket Walls** and add the ones you like: **Orbit**, **Thunderstorm**, **Race Day**, **Rivers**, **Dial Clock**, **Day Sentence**, **Big Date** or **Day Headline**.")
                GuideStep(3, "That's it: when you set up another theme, the widgets change with it.")
                NavigationLink(value: Route.widgets) {
                    Label("See all the widgets", systemImage: "square.grid.2x2")
                }
            } header: {
                Text("2 · Home Screen widgets")
            } footer: {
                Text("iOS only lets you place widgets yourself.")
            }

            Section {
                TextField("Signature text", text: Binding(
                    get: { store.settings.signature },
                    set: { store.settings.signature = $0 }
                ))
                GuideStep(1, "Touch and hold the Lock Screen, tap **Customize** → **Lock Screen**.")
                GuideStep(2, "Tap the area under the time and add **Seconds Ring**, **Running Clock**, **Signature** or **Waveform** from Pocket Walls.")
                GuideStep(3, "Tap the time and set its color to the clock color below. In the color picker, the **Sliders** tab takes the code.")
                ColorRow(label: "Clock color", color: theme.clock)
            } header: {
                Text("3 · Lock Screen")
            }

            Section {
                GuideStep(1, "Tap **Install icons**. Safari opens and asks to download a profile: tap **Allow**, then **Close**.")
                Button { setup.installIcons() } label: {
                    Label("Install icons", systemImage: "square.grid.2x2")
                }
                NavigationLink {
                    AppPicker()
                } label: {
                    Label("Choose apps", systemImage: "checklist")
                }
                GuideStep(2, "Open **Settings** and tap **Profile Downloaded** near the top. Tap **Install**, enter your passcode, and tap **Install** again.")
                GuideStep(3, "The themed icons appear on your Home Screen. To hide an original, touch and hold it → **Remove App** → **Remove from Home Screen**.")
                DisclosureGroup("Or just tint your icons") {
                    GuideStep(1, "Touch and hold the Home Screen, tap **Edit** → **Customize** → **Tinted**, and pick this color.")
                    ColorRow(label: "Icon tint", color: theme.accent)
                }
            } header: {
                Text("4 · App icons")
            } footer: {
                Text("iOS doesn't let any app change other apps' icons. Pocket Walls adds its own icons that open your apps. To remove them all, delete the Pocket Walls Icons profile in Settings → General → VPN & Device Management.")
            }
        }
        .navigationTitle("Set up")
    }

    @ViewBuilder
    private var wallpaperStatus: some View {
        switch setup.wallpaper {
        case .working:
            StatusRow(.working, "Running the shortcut…", nil)
        case .done:
            StatusRow(.done, "It works", "Set up theme will change your wallpaper from now on.")
        case .failed(let message):
            StatusRow(.attention, "Not working yet", message)
        default:
            EmptyView()
        }
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
}
