import SwiftUI

/// Shown after "Set up theme": what changed, and the few things iOS still
/// needs a person for.
struct SetupSheet: View {
    let wall: Wallpaper
    let style: IconStyle

    @ObservedObject private var setup = SetupCoordinator.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("autoInstallIcons") private var installsIconsAutomatically = false
    @State private var iconCount = IconProfile.selectedTargets.count

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        WallpaperThumb(wall: wall).frame(width: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(wall.name).font(.headline)
                            Text("\(style.title) icons").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Widgets") {
                    StatusRow(.done, "Widgets updated", "Your Pocket Walls widgets now use this theme.")
                    DisclosureGroup("Haven't added widgets yet?") {
                        GuideStep(1, "Touch and hold an empty spot on your Home Screen, then tap **Edit** → **Add Widget**.")
                        GuideStep(2, "Search for **Pocket Walls** and add the ones you like.")
                        GuideStep(3, "You only do this once. They follow every theme you set up.")
                    }
                    .font(.subheadline)
                }

                Section("Wallpaper") { wallpaperRows }

                Section {
                    iconRows
                } header: {
                    Text("App icons")
                } footer: {
                    Text("iOS doesn't let any app change other apps' icons. Pocket Walls adds its own icons that open your apps, and iOS asks you to approve them.")
                }
            }
            .navigationTitle("Set up theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { iconCount = IconProfile.selectedTargets.count }
        }
    }

    // MARK: Wallpaper

    @ViewBuilder
    private var wallpaperRows: some View {
        switch setup.wallpaper {
        case .working:
            StatusRow(.working, "Setting your wallpaper…", nil)
        case .done:
            StatusRow(.done, "Wallpaper set", "Lock Screen and Home Screen.")
        case .savedToPhotos:
            StatusRow(.done, "Saved to Photos", "Open it in Photos, tap Share, then Use as Wallpaper.")
            shortcutSetup
        case .failed(let message):
            StatusRow(.attention, "Wallpaper not set", message)
            shortcutSetup
        case .idle, .needsShortcut, .awaitingApproval:
            StatusRow(.attention, "One step, once", "Add a shortcut that lets Pocket Walls set your wallpaper. After that it changes by itself.")
            shortcutSetup
        }
    }

    @ViewBuilder
    private var shortcutSetup: some View {
        DisclosureGroup("How to add the shortcut") {
            GuideStep(1, "Tap **Open Shortcuts** below. It starts a new shortcut.")
            GuideStep(2, "Search for **Pocket Walls** and add **Get Current Wallpaper**.")
            GuideStep(3, "Search for **Set Wallpaper Photo** and add it. Tap its arrow and turn off **Show Preview**.")
            GuideStep(4, "Rename the shortcut to **\(ShortcutsLink.wallpaperShortcut)** and tap **Done**.")
        }
        .font(.subheadline)
        Button("Open Shortcuts") { ShortcutsLink.newShortcut() }
        Button("I've added it. Set my wallpaper") { setup.runWallpaperShortcut() }
        Button("Save to Photos instead") { Task { await setup.saveWallpaperToPhotos() } }
    }

    // MARK: Icons

    @ViewBuilder
    private var iconRows: some View {
        switch setup.icons {
        case .working:
            StatusRow(.working, "Preparing \(iconCount) icons…", nil)
        case .awaitingApproval:
            StatusRow(.attention, "Approve the icons", "iOS needs your OK before it adds them.")
            GuideStep(1, "In Safari, tap **Allow**, then **Close**.")
            GuideStep(2, "Open **Settings** and tap **Profile Downloaded** near the top.")
            GuideStep(3, "Tap **Install**, enter your passcode, and tap **Install** again.")
            Toggle("Start this by itself next time", isOn: $installsIconsAutomatically)
            Button("Send to Safari again") { setup.installIcons() }
        case .failed(let message):
            StatusRow(.attention, "Icons not installed", message)
            installControls
        case .idle, .done, .needsShortcut, .savedToPhotos:
            installControls
        }
    }

    @ViewBuilder
    private var installControls: some View {
        Button {
            setup.installIcons()
        } label: {
            Label("Install \(iconCount) icons", systemImage: "square.grid.2x2")
        }
        .disabled(iconCount == 0)
        NavigationLink {
            AppPicker()
        } label: {
            Label("Choose apps", systemImage: "checklist")
        }
    }
}

/// One line of progress: a mark, a title and a short explanation.
struct StatusRow: View {
    enum Kind { case done, working, attention }

    let kind: Kind
    let title: String
    let detail: String?

    init(_ kind: Kind, _ title: String, _ detail: String?) {
        self.kind = kind
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            switch kind {
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .working:
                ProgressView()
            case .attention:
                Image(systemName: "hand.tap.fill").foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// A numbered instruction. Markdown in the text (**bold**) is rendered.
struct GuideStep: View {
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

/// Which apps get a themed icon.
struct AppPicker: View {
    @EnvironmentObject private var store: ThemeStore
    @State private var selection = IconProfile.selection

    var body: some View {
        let settings = store.settings
        List {
            Section {
                ForEach(IconProfile.targets) { target in
                    Toggle(isOn: Binding(
                        get: { selection.contains(target.iconID) },
                        set: { on in
                            if on { selection.insert(target.iconID) } else { selection.remove(target.iconID) }
                            IconProfile.selection = selection
                        }
                    )) {
                        HStack(spacing: 10) {
                            Image(uiImage: ImageCache.shared.icon(target.iconID, style: settings.iconStyle, theme: settings.theme, size: 30))
                                .resizable()
                                .frame(width: 30, height: 30)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            Text(target.label)
                        }
                    }
                }
            } footer: {
                Text("Turn off any app you don't have. Its icon would do nothing when tapped.")
            }
        }
        .navigationTitle("Choose apps")
        .navigationBarTitleDisplayMode(.inline)
    }
}
