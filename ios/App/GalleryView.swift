import SwiftUI

struct GalleryView: View {
    @EnvironmentObject private var store: ThemeStore
    @State private var category = "All"
    @State private var path: [Route] = []

    private var walls: [Wallpaper] {
        category == "All" ? Catalog.all : Catalog.all.filter { $0.category == category }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    currentTheme
                    looks
                    chips
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 16) {
                        ForEach(walls) { wall in
                            NavigationLink(value: Route.wallpaper(wall.id)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    WallpaperThumb(wall: wall)
                                    Text(wall.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Pocket Walls")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.setup) {
                        Label("Set up", systemImage: "checklist")
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .wallpaper(let id):
                    if let wall = Catalog.wallpaper(id: id) { DetailView(wall: wall, look: nil) }
                case .look(let id):
                    if let look = Look.all.first(where: { $0.id == id }), let wall = Catalog.wallpaper(id: look.wallpaperID) {
                        DetailView(wall: wall, look: look)
                    }
                case .setup:
                    SetupGuideView()
                }
            }
        }
    }

    /// The theme the widgets show right now.
    private var currentTheme: some View {
        let settings = store.settings
        return NavigationLink(value: Route.setup) {
            HStack(spacing: 14) {
                WallpaperThumb(wall: settings.wallpaper)
                    .frame(width: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Current theme")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(settings.wallpaper.name)
                        .font(.headline)
                    Text("\(settings.iconStyle.title) icons · widgets follow this theme")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var looks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Complete looks")
                .font(.title3.weight(.bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Look.all) { look in
                        if let wall = Catalog.wallpaper(id: look.wallpaperID) {
                            NavigationLink(value: Route.look(look.id)) {
                                ZStack(alignment: .bottomLeading) {
                                    WallpaperThumb(wall: wall)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(look.name).font(.subheadline.weight(.bold))
                                        Text("\(look.iconStyle.title) icons").font(.caption2)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .bottom, endPoint: .top))
                                }
                                .frame(width: 128)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Catalog.categories, id: \.self) { name in
                    Button(name) { category = name }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(category == name ? Color.white : Color.white.opacity(0.08), in: Capsule())
                        .foregroundStyle(category == name ? Color.black : Color.white)
                }
            }
        }
    }
}

/// A wallpaper thumbnail at the phone's aspect ratio, rendered in the
/// background the first time it's shown.
struct WallpaperThumb: View {
    let wall: Wallpaper
    @State private var image: UIImage?

    var body: some View {
        Color.white.opacity(0.06)
            .aspectRatio(1206.0 / 2622.0, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .task(id: wall.id) {
                let loaded = await ImageCache.shared.wallpaper(wall, width: 270, height: 585)
                withAnimation(.easeOut(duration: 0.25)) { image = loaded }
            }
    }
}
