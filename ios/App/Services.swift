import Photos
import SwiftUI
import UIKit

/// Renders wallpapers off the main thread and keeps recent results.
/// Safe to share across threads: NSCache is thread-safe and `icons` is
/// guarded by a lock.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "pocketwalls.render", qos: .userInitiated, attributes: .concurrent)

    func wallpaper(_ wall: Wallpaper, width: Int, height: Int, variant: Int = 0) async -> UIImage? {
        let key = "\(wall.id)-\(width)x\(height)-\(variant)"
        if let hit = cache.object(forKey: key as NSString) { return hit }
        return await withCheckedContinuation { continuation in
            queue.async {
                let image = WallpaperRenderer.image(wall, width: width, height: height, variant: variant)
                if let image { self.cache.setObject(image, forKey: key as NSString) }
                continuation.resume(returning: image)
            }
        }
    }

    /// Theme icons at preview size, keyed by style and colors.
    private var icons: [String: UIImage] = [:]
    private let iconLock = NSLock()

    func icon(_ id: String, style: IconStyle, theme: Theme, size: CGFloat = 60) -> UIImage {
        let key = "\(id)-\(style.rawValue)-\(theme.accent.hex)-\(theme.second.hex)-\(Int(size))"
        iconLock.lock()
        defer { iconLock.unlock() }
        if let hit = icons[key] { return hit }
        let image = IconRenderer.image(id, size: size, style: style, theme: theme, scale: 3)
        icons[key] = image
        return image
    }
}

enum Device {
    /// This iPhone's screen in pixels, portrait.
    static var pixelSize: (width: Int, height: Int) {
        let native = UIScreen.main.nativeBounds.size
        let w = Int(min(native.width, native.height))
        let h = Int(max(native.width, native.height))
        return (w, h)
    }
}

enum PhotoSaver {
    enum SaveError: LocalizedError {
        case denied

        var errorDescription: String? {
            "Pocket Walls can't add photos. Allow it in Settings → Privacy & Security → Photos."
        }
    }

    static func save(_ images: [UIImage]) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.denied }
        try await PHPhotoLibrary.shared().performChanges {
            for image in images {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        }
    }
}

/// Links into the Shortcuts app.
enum ShortcutsLink {
    /// The shortcut people make once: Get Current Wallpaper → Set Wallpaper.
    static let wallpaperShortcut = "Pocket Walls Wallpaper"

    /// Runs the wallpaper shortcut. Shortcuts then reopens this app at
    /// pocketwalls://shortcut/success, /cancel or /error, which
    /// SetupCoordinator handles. `opened` is false if Shortcuts itself
    /// couldn't be opened.
    @MainActor
    static func runWallpaperShortcut(opened: @escaping @MainActor @Sendable (Bool) -> Void) {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "x-callback-url"
        components.path = "/run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: wallpaperShortcut),
            URLQueryItem(name: "x-success", value: "pocketwalls://shortcut/success"),
            URLQueryItem(name: "x-cancel", value: "pocketwalls://shortcut/cancel"),
            URLQueryItem(name: "x-error", value: "pocketwalls://shortcut/error"),
        ]
        guard let url = components.url else {
            opened(false)
            return
        }
        UIApplication.shared.open(url, options: [:]) { ok in
            Task { @MainActor in opened(ok) }
        }
    }

    @MainActor
    static func newShortcut() {
        guard let url = URL(string: "shortcuts://create-shortcut") else { return }
        UIApplication.shared.open(url)
    }
}

/// Copies text, such as a color code, to the clipboard.
func copyToClipboard(_ text: String) {
    UIPasteboard.general.string = text
}
