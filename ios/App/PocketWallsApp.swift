import SwiftUI

@main
struct PocketWallsApp: App {
    @StateObject private var store = ThemeStore.shared

    var body: some Scene {
        WindowGroup {
            GalleryView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

enum Route: Hashable {
    case wallpaper(String)
    case look(String)
    case setup
}
