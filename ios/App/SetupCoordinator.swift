import SwiftUI
import UIKit

/// Where the app is, and links into it.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var path: [Route] = []
    /// A wallpaper whose screen should start setup as soon as it shows.
    @Published var setupOnOpen: String?
    /// The section the widget previews should open at ("lock"), if any.
    var widgetsAnchor: String?

    /// pocketwalls://theme/<id>          opens that wallpaper
    /// pocketwalls://theme/<id>/setup    opens it and starts setup
    /// pocketwalls://widgets[/lock]      opens the widget previews
    /// pocketwalls://shortcut/<result>   the wallpaper shortcut reporting back
    func handle(_ url: URL) {
        guard url.scheme == "pocketwalls" else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch url.host {
        case "shortcut":
            SetupCoordinator.shared.shortcutReported(parts.first ?? "", url: url)
        case "theme":
            guard let id = parts.first, Catalog.wallpaper(id: id) != nil else { return }
            if parts.dropFirst().first == "setup" { setupOnOpen = id }
            path = [.wallpaper(id)]
        case "widgets":
            widgetsAnchor = parts.first
            path = [.widgets]
        default:
            break
        }
    }
}

/// Runs "Set up theme": widgets, then wallpaper, then icons.
///
/// Widgets follow the saved theme by themselves. The wallpaper is set by a
/// shortcut the user makes once, because iOS gives apps no way to set it.
/// Icons go in as one profile that iOS asks the user to approve.
@MainActor
final class SetupCoordinator: ObservableObject {
    static let shared = SetupCoordinator()

    enum Step: Equatable {
        case idle
        case working
        case done
        /// The wallpaper shortcut isn't set up yet.
        case needsShortcut
        /// The wallpaper was saved to Photos to be set by hand.
        case savedToPhotos
        /// The icon profile is with Safari; the user approves it in Settings.
        case awaitingApproval
        case failed(String)
    }

    @Published private(set) var wallpaper: Step = .idle
    @Published private(set) var icons: Step = .idle

    private let defaults = UserDefaults.standard
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    /// True once the wallpaper shortcut has worked on this iPhone.
    private(set) var shortcutReady: Bool {
        get { defaults.bool(forKey: "wallpaperShortcutReady") }
        set { defaults.set(newValue, forKey: "wallpaperShortcutReady") }
    }

    /// Chosen in the setup sheet: go straight on to the icons after the
    /// wallpaper is set.
    private var installsIconsAutomatically: Bool { defaults.bool(forKey: "autoInstallIcons") }

    // MARK: Start

    func begin(wall: Wallpaper, style: IconStyle, signature: String, luminance: Double?) {
        // Saving the theme is all the widgets need.
        ThemeStore.shared.settings = ThemeSettings(wallpaperID: wall.id, iconStyle: style, signature: signature, clockLuminance: luminance)
        icons = .idle
        if shortcutReady {
            runWallpaperShortcut()
        } else {
            wallpaper = .needsShortcut
        }
    }

    // MARK: Wallpaper

    func runWallpaperShortcut() {
        wallpaper = .working
        ShortcutsLink.runWallpaperShortcut { [weak self] opened in
            if !opened { self?.wallpaper = .failed("The Shortcuts app couldn't be opened.") }
        }
    }

    /// Shortcuts reopened the app with the result.
    func shortcutReported(_ result: String, url: URL) {
        switch result {
        case "success":
            shortcutReady = true
            wallpaper = .done
            if installsIconsAutomatically && icons == .idle { installIcons() }
        case "cancel":
            wallpaper = .failed("The shortcut was cancelled.")
        default:
            let message = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "errorMessage" }?.value
            wallpaper = .failed(message ?? "The shortcut didn't finish.")
        }
    }

    /// The app came back to the front. If the shortcut never reported, it
    /// probably doesn't exist yet.
    func appBecameActive() {
        guard wallpaper == .working else { return }
        Task {
            // The callback link, when there is one, arrives just after this.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if wallpaper == .working {
                wallpaper = .failed("Shortcuts didn't report back. If the shortcut isn't set up yet, add it below.")
            }
        }
    }

    func saveWallpaperToPhotos() async {
        let wall = ThemeStore.shared.settings.wallpaper
        let size = Device.pixelSize
        wallpaper = .working
        guard let image = await ImageCache.shared.wallpaper(wall, width: size.width, height: size.height) else {
            wallpaper = .failed("The wallpaper couldn't be drawn. Try again.")
            return
        }
        do {
            try await PhotoSaver.save([image])
            wallpaper = .savedToPhotos
        } catch {
            wallpaper = .failed(error.localizedDescription)
        }
    }

    // MARK: Icons

    func installIcons() {
        let settings = ThemeStore.shared.settings
        let theme = settings.theme
        let style = settings.iconStyle
        let name = settings.wallpaper.name
        let targets = IconProfile.selectedTargets
        guard !targets.isEmpty else {
            icons = .failed("Choose at least one app first.")
            return
        }
        icons = .working
        Task.detached(priority: .userInitiated) {
            let data = IconProfile.build(theme: theme, style: style, themeName: name, targets: targets)
            await MainActor.run { self.hand(profile: data) }
        }
    }

    private func hand(profile: Data?) {
        guard let profile else {
            icons = .failed("The icons couldn't be prepared. Try again.")
            return
        }
        ProfileServer.shared.serve(profile, fileName: IconProfile.fileName) { url in
            Task { @MainActor in self.openInSafari(url) }
        }
    }

    private func openInSafari(_ url: URL?) {
        guard let url else {
            icons = .failed("The icons couldn't be sent to Safari. Try again.")
            return
        }
        // Keep serving for a little while after Safari comes to the front.
        endBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "icon-profile") { [weak self] in
            Task { @MainActor in self?.endBackgroundTask() }
        }
        Task {
            try? await Task.sleep(nanoseconds: 25_000_000_000)
            endBackgroundTask()
        }
        icons = .awaitingApproval
        // Only Safari can install a profile, so ask for it by name first in
        // case another browser is the default.
        let safari = URL(string: "x-safari-" + url.absoluteString)
        if let safari {
            UIApplication.shared.open(safari, options: [:]) { opened in
                if !opened {
                    Task { @MainActor in UIApplication.shared.open(url) }
                }
            }
        } else {
            UIApplication.shared.open(url)
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
