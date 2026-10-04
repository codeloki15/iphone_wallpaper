import AppIntents
import UIKit
import UniformTypeIdentifiers

/// A Shortcuts action that returns the current theme's wallpaper, sized for
/// this iPhone. Paired with Shortcuts' own Set Wallpaper action, it makes
/// applying a theme a single tap.
struct GetWallpaperIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Current Wallpaper"
    static var description = IntentDescription("Returns the wallpaper of your current Pocket Walls theme, sized for this iPhone.")

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let settings = ThemeSettings.load()
        let size = await MainActor.run { Device.pixelSize }
        guard let image = WallpaperRenderer.cgImage(settings.wallpaper, width: size.width, height: size.height),
              let data = UIImage(cgImage: image).pngData()
        else { throw WallpaperError.render }
        let file = IntentFile(data: data, filename: "\(settings.wallpaper.id).png", type: .png)
        return .result(value: file)
    }
}

enum WallpaperError: Error, CustomLocalizedStringResourceConvertible {
    case render

    var localizedStringResource: LocalizedStringResource {
        "Pocket Walls couldn't create the wallpaper."
    }
}

struct PocketWallsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetWallpaperIntent(),
            phrases: ["Get my \(.applicationName) wallpaper"],
            shortTitle: "Current Wallpaper",
            systemImageName: "photo"
        )
    }
}
