import SwiftUI

/// A live wallpaper playing in a loop, with a button that saves it to
/// Photos as a Live Photo and the steps to put it on the Lock Screen.
struct LiveWallpaperView: View {
    let scene: LiveScene

    @State private var status: String?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                LivePreview(scene: scene)
                    .frame(maxHeight: 520)

                Button {
                    Task { await save() }
                } label: {
                    HStack(spacing: 10) {
                        if busy { ProgressView() }
                        Label(busy ? "Making the Live Photo…" : "Save as Live Photo", systemImage: "livephoto")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy)

                if let status {
                    Text(status)
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Put it on your Lock Screen").font(.headline)
                    GuideStep(1, "Tap **Save as Live Photo**. It takes a few seconds.")
                    GuideStep(2, "Touch and hold your Lock Screen, tap **+**, then **Photos**.")
                    GuideStep(3, "Open the **Live Photos** album and pick this one.")
                    GuideStep(4, "Check that the Live Photo button at the bottom left is on, then tap **Add**.")
                    Text("It plays when your Lock Screen wakes. iOS decides whether a Live Photo may move as a wallpaper; if it says motion isn't available, it still works as a still one. Live wallpapers show on the Lock Screen only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .navigationTitle(scene.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func save() async {
        busy = true
        defer { busy = false }
        status = nil
        let size = Device.pixelSize
        let scene = self.scene
        do {
            let files = try await Task.detached(priority: .userInitiated) {
                try LivePhoto.make(scene: scene, pixelWidth: size.width, pixelHeight: size.height) { _ in }
            }.value
            try await LivePhoto.save(files)
            status = "Saved to Photos. Look in the Live Photos album."
        } catch {
            status = error.localizedDescription
        }
    }
}

/// The scene playing in a loop, drawn small enough to redraw every frame.
struct LivePreview: View {
    let scene: LiveScene

    var body: some View {
        let size = Device.pixelSize
        let width = 210
        let height = width * size.height / size.width
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let loops = context.date.timeIntervalSinceReferenceDate / LivePhoto.seconds
            let progress = loops - loops.rounded(.down)
            if let frame = scene.cgImage(width: width, height: height, progress: progress) {
                Image(decorative: frame, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        }
    }
}

/// A still from a live wallpaper, for the gallery.
struct LiveThumb: View {
    let scene: LiveScene
    @State private var image: UIImage?

    var body: some View {
        Color.white.opacity(0.06)
            .aspectRatio(1206.0 / 2622.0, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .task(id: scene.id) {
                let scene = self.scene
                let made = await Task.detached(priority: .userInitiated) {
                    scene.cgImage(width: 270, height: 585, progress: LivePhoto.stillProgress)
                }.value
                if let made { image = UIImage(cgImage: made) }
            }
    }
}
