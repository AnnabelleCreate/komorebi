import SwiftUI

struct DiscoverView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "See all", stories = "Stories", rituals = "Rituals", kits = "Kits"
        var id: String { rawValue }
    }

    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @State private var filter: Filter = .all

    var body: some View {
        let library = StoryLibrary.shared
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenTitle(title: "Discover", subtitle: "Three quiet things, done well. Pick a kind, or see them all.")
                    .padding(.top, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Filter.allCases) { f in
                            FilterChip(title: f.rawValue, selected: filter == f) { filter = f; Haptics.shared.selection() }
                        }
                    }
                }

                if filter == .all || filter == .rituals {
                    section("Rituals") {
                        DiscoverRow(item: ActivityItem(kind: .lantern))
                        DiscoverRow(item: ActivityItem(kind: .garden))
                    }
                }

                if filter == .all || filter == .stories {
                    if let problem = library.loadError {
                        EmptyState(systemImage: "book.closed", title: "Stories unavailable", message: problem)
                    } else {
                        ForEach(StoryLibrary.collections) { collection in
                            section(collection.name) {
                                ForEach(library.stories(in: collection.id)) { story in
                                    NavigationLink(value: story.id) {
                                        DiscoverRowContent(item: ActivityItem(kind: .story(story)),
                                                           detail: "\(story.author) · \(story.readMinutes) min read · \(story.listenMinutes) min listen")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if filter == .all || filter == .kits {
                    section("Kits") {
                        Button { router.tab = .kits } label: {
                            DiscoverRowContent(title: "Kit of the month", detail: "Sand tray, paperbacks, quiet fidget toys. $18 all-in.", artName: "art-kit", favoriteKey: nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .kScreen()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: String.self) { id in
            if let story = StoryLibrary.shared.story(id) { BookDetailView(story: story) } else { MissingStoryView() }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(KFont.heading(19)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
            VStack(spacing: 10) { content() }
        }
    }
}

struct DiscoverRow: View {
    var item: ActivityItem
    @Environment(Router.self) private var router
    var body: some View {
        Button { item.open(router: router) } label: {
            DiscoverRowContent(item: item, detail: item.subtitle)
        }
        .buttonStyle(.plain)
    }
}

struct DiscoverRowContent: View {
    var title: String
    var detail: String
    var artName: String
    var favoriteKey: String?
    @Environment(AppStore.self) private var store

    init(item: ActivityItem, detail: String) {
        title = item.title
        self.detail = detail
        artName = item.artName
        favoriteKey = item.id
    }

    init(title: String, detail: String, artName: String, favoriteKey: String?) {
        self.title = title
        self.detail = detail
        self.artName = artName
        self.favoriteKey = favoriteKey
    }

    var body: some View {
        HStack(spacing: 14) {
            ArtImage(name: artName)
                .frame(width: 64, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(KFont.heading(17)).foregroundStyle(Palette.text)
                Text(detail).font(KFont.body(13)).foregroundStyle(Palette.text2).lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let key = favoriteKey {
                Button {
                    store.toggleFavorite(key)
                    Haptics.shared.selection()
                } label: {
                    Image(systemName: store.isFavorite(key) ? "heart.fill" : "heart")
                        .foregroundStyle(Palette.text)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.isFavorite(key) ? "Remove \(title) from favorites" : "Add \(title) to favorites")
            }
        }
        .padding(12)
        .kCard(radius: 16)
        .contentShape(Rectangle())
    }
}
