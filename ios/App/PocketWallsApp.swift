import SwiftUI

@main
struct PocketWallsApp: App {
    @StateObject private var store = ThemeStore.shared
    @StateObject private var router = AppRouter.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            GalleryView()
                .environmentObject(store)
                .environmentObject(router)
                .preferredColorScheme(.dark)
                .onOpenURL { router.handle($0) }
                .task {
                    #if DEBUG
                    // `-openURL pocketwalls://…` on the launch command line
                    // opens that link, to reach a screen without tapping.
                    if let link = UserDefaults.standard.string(forKey: "openURL"), let url = URL(string: link) {
                        router.handle(url)
                    }
                    #endif
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { SetupCoordinator.shared.appBecameActive() }
        }
    }
}

enum Route: Hashable {
    case wallpaper(String)
    case look(String)
    case setup
    case widgets
    case live(String)
}
