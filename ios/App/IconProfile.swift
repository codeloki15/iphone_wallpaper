import UIKit

/// A themed icon and the app it opens.
struct IconTarget: Identifiable, Hashable {
    let iconID: String
    let label: String
    /// The URL scheme that opens the app.
    let url: String
    let bundleID: String
    /// Set for apps that don't ship with iOS, so they are only offered when
    /// installed.
    let optional: Bool

    var id: String { iconID }
}

/// Builds a configuration profile that adds themed Home Screen icons.
///
/// iOS has no API for changing another app's icon. What it does allow is a
/// profile of "web clips": Home Screen icons with any image that open a URL.
/// Pointed at each app's URL scheme, they act as themed app icons, and one
/// profile installs them all. The user approves it in Settings.
enum IconProfile {
    static let fileName = "PocketWallsIcons.mobileconfig"

    static let targets: [IconTarget] = [
        IconTarget(iconID: "phone", label: "Phone", url: "mobilephone://", bundleID: "com.apple.mobilephone", optional: false),
        IconTarget(iconID: "messages", label: "Messages", url: "messages://", bundleID: "com.apple.MobileSMS", optional: false),
        IconTarget(iconID: "browser", label: "Safari", url: "x-web-search://", bundleID: "com.apple.mobilesafari", optional: false),
        IconTarget(iconID: "music", label: "Music", url: "music://", bundleID: "com.apple.Music", optional: false),
        IconTarget(iconID: "mail", label: "Mail", url: "message://", bundleID: "com.apple.mobilemail", optional: false),
        IconTarget(iconID: "calendar", label: "Calendar", url: "calshow://", bundleID: "com.apple.mobilecal", optional: false),
        IconTarget(iconID: "photos", label: "Photos", url: "photos-redirect://", bundleID: "com.apple.mobileslideshow", optional: false),
        IconTarget(iconID: "camera", label: "Camera", url: "camera://", bundleID: "com.apple.camera", optional: false),
        IconTarget(iconID: "maps", label: "Maps", url: "maps://", bundleID: "com.apple.Maps", optional: false),
        IconTarget(iconID: "weather", label: "Weather", url: "weather://", bundleID: "com.apple.weather", optional: false),
        IconTarget(iconID: "clock", label: "Clock", url: "clock-worldclock://", bundleID: "com.apple.mobiletimer", optional: false),
        IconTarget(iconID: "notes", label: "Notes", url: "mobilenotes://", bundleID: "com.apple.mobilenotes", optional: false),
        IconTarget(iconID: "store", label: "App Store", url: "itms-apps://", bundleID: "com.apple.AppStore", optional: false),
        IconTarget(iconID: "settings", label: "Settings", url: "App-prefs://", bundleID: "com.apple.Preferences", optional: false),
        IconTarget(iconID: "videocall", label: "FaceTime", url: "facetime://", bundleID: "com.apple.facetime", optional: false),
        IconTarget(iconID: "files", label: "Files", url: "shareddocuments://", bundleID: "com.apple.DocumentsApp", optional: false),
        IconTarget(iconID: "wallet", label: "Wallet", url: "shoebox://", bundleID: "com.apple.Passbook", optional: false),
        IconTarget(iconID: "health", label: "Health", url: "x-apple-health://", bundleID: "com.apple.Health", optional: false),
        IconTarget(iconID: "chat", label: "WhatsApp", url: "whatsapp://", bundleID: "net.whatsapp.WhatsApp", optional: true),
        IconTarget(iconID: "social", label: "Instagram", url: "instagram://", bundleID: "com.burbn.instagram", optional: true),
        IconTarget(iconID: "video", label: "YouTube", url: "youtube://", bundleID: "com.google.ios.youtube", optional: true),
        IconTarget(iconID: "audio", label: "Voice Memos", url: "voicememos://", bundleID: "com.apple.VoiceMemos", optional: false),
        IconTarget(iconID: "calculator", label: "Calculator", url: "calc://", bundleID: "com.apple.calculator", optional: false),
        IconTarget(iconID: "fitness", label: "Fitness", url: "fitnessapp://", bundleID: "com.apple.Fitness", optional: false),
    ]

    // MARK: Which apps to include

    private static let selectionKey = "iconTargets"

    /// The icons the user wants installed. Until they choose, every app
    /// that ships with iOS plus the optional ones found on this iPhone.
    @MainActor
    static var selection: Set<String> {
        get {
            if let saved = UserDefaults.standard.string(forKey: selectionKey) {
                return Set(saved.split(separator: ",").map(String.init))
            }
            return Set(targets.filter { !$0.optional || isInstalled($0) }.map(\.iconID))
        }
        set {
            UserDefaults.standard.set(newValue.sorted().joined(separator: ","), forKey: selectionKey)
        }
    }

    @MainActor
    static var selectedTargets: [IconTarget] {
        let chosen = selection
        return targets.filter { chosen.contains($0.iconID) }
    }

    /// Needs the scheme listed under LSApplicationQueriesSchemes.
    @MainActor
    private static func isInstalled(_ target: IconTarget) -> Bool {
        guard let url = URL(string: target.url) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    // MARK: Profile

    /// The profile as XML, ready to hand to Safari. Identifiers are the same
    /// every time, so installing a new theme replaces the previous icons
    /// rather than adding a second set.
    static func build(theme: Theme, style: IconStyle, themeName: String, targets: [IconTarget]) -> Data? {
        let base = (Bundle.main.bundleIdentifier ?? "pocketwalls") + ".icons"
        var clips: [[String: Any]] = []
        for target in targets {
            // 180 px is a Home Screen icon at 3x.
            guard let png = IconRenderer.image(target.iconID, size: 180, style: style, theme: theme).pngData() else { continue }
            let identifier = "\(base).\(target.iconID)"
            clips.append([
                "PayloadType": "com.apple.webClip.managed",
                "PayloadVersion": 1,
                "PayloadIdentifier": identifier,
                "PayloadUUID": stableUUID(identifier),
                "PayloadDisplayName": target.label,
                "Label": target.label,
                "URL": target.url,
                // Opens the app directly where iOS honors it; otherwise the
                // URL scheme above does the job.
                "TargetApplicationBundleIdentifier": target.bundleID,
                "Icon": png,
                "IsRemovable": true,
                "Precomposed": true,
                "FullScreen": true,
                "IgnoreManifestScope": true,
            ])
        }
        guard !clips.isEmpty else { return nil }
        let profile: [String: Any] = [
            "PayloadType": "Configuration",
            "PayloadVersion": 1,
            "PayloadIdentifier": base,
            "PayloadUUID": stableUUID(base),
            "PayloadDisplayName": "Pocket Walls Icons",
            "PayloadDescription": "Adds \(clips.count) Home Screen icons in the \(themeName) theme. Each one opens its app. Remove this profile to remove them all.",
            "PayloadOrganization": "Pocket Walls",
            "PayloadContent": clips,
        ]
        return try? PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
    }

    /// A UUID derived from a string, so the same payload keeps its identity
    /// across installs.
    static func stableUUID(_ string: String) -> String {
        var bytes: [UInt8] = []
        for salt in 0..<4 {
            let h = fnvHash("\(salt):\(string)")
            bytes.append(contentsOf: [UInt8(h >> 24), UInt8((h >> 16) & 0xff), UInt8((h >> 8) & 0xff), UInt8(h & 0xff)])
        }
        // Mark it as a version 4, variant 1 UUID.
        bytes[6] = (bytes[6] & 0x0f) | 0x40
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        let hex = bytes.map { String(format: "%02X", $0) }.joined()
        let c = Array(hex)
        return "\(String(c[0..<8]))-\(String(c[8..<12]))-\(String(c[12..<16]))-\(String(c[16..<20]))-\(String(c[20..<32]))"
    }
}
