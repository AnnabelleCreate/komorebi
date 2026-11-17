import SwiftUI

/// One activity Komorebi can open.
struct ActivityItem: Identifiable {
    enum Kind { case garden, lantern, story(Story) }
    var kind: Kind
    var id: String {
        switch kind {
        case .garden: return "garden"
        case .lantern: return "lantern"
        case .story(let s): return s.id
        }
    }
    var story: Story? {
        if case .story(let s) = kind { return s }
        return nil
    }
    var title: String {
        switch kind {
        case .garden: return "Sand garden"
        case .lantern: return "Lantern release"
        case .story(let s): return s.title
        }
    }
    var subtitle: String {
        switch kind {
        case .garden: return "Rake slow lines in the sand, or follow a path. It stays until you smooth it away."
        case .lantern: return "Put a thought into a paper lantern and let the river carry it. Nothing is saved."
        case .story(let s): return s.synopsis
        }
    }
    var shortLine: String {
        switch kind {
        case .garden: return "Ritual · as long as you like"
        case .lantern: return "Ritual · 2 min"
        case .story(let s): return "\(s.origin) · \(s.readMinutes) min read"
        }
    }
    var tags: [(String, String, Bool)] {
        switch kind {
        case .garden: return [("Any length", "clock", false), ("Garden", "leaf", true)]
        case .lantern: return [("2 min", "clock", false), ("Ritual", "flame", true)]
        case .story(let s): return [("\(s.readMinutes) min", "clock", false), (s.isPoems ? "Poems" : "Story", "book", true)]
        }
    }
    var artName: String {
        switch kind {
        case .garden: return "art-garden"
        case .lantern: return "art-lantern"
        case .story(let s): return s.coverImageName
        }
    }

    static func from(key: String) -> ActivityItem? {
        switch key {
        case "garden": return ActivityItem(kind: .garden)
        case "lantern": return ActivityItem(kind: .lantern)
        default: return StoryLibrary.shared.story(key).map { ActivityItem(kind: .story($0)) }
        }
    }

    @MainActor func open(router: Router) {
        switch kind {
        case .garden: router.open(.garden)
        case .lantern: router.open(.lantern)
        case .story(let s): router.open(.reader(s.id))
        }
    }
}

struct TonightView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        let featured = featuredSuggestion()
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("komorebi").font(KFont.title(20)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
                    Spacer()
                    let soundOn = store.state.settings.gentleSounds || store.state.settings.ambience
                    CircleIconButton(systemImage: soundOn ? "speaker.wave.2" : "speaker.slash",
                                     label: soundOn ? "Sounds on" : "Sounds off") {
                        store.state.settings.gentleSounds = !soundOn
                        store.state.settings.ambience = !soundOn
                    }
                }
                .padding(.top, 4)

                ScreenTitle(title: greeting, subtitle: store.state.name.isEmpty ? "Something slow for tonight." : "Something slow for tonight, \(store.state.name).")

                NowPlayingCard()

                FeaturedCard(item: featured.item, eyebrow: featured.eyebrow, continueFraction: featured.continueFraction)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("More for you").font(KFont.heading(19)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button("See all") { router.tab = .discover }.buttonStyle(GhostButtonStyle())
                    }
                    HStack(spacing: 12) {
                        ForEach(moreForYou(excluding: featured.item.id)) { item in
                            SmallActivityCard(item: item)
                        }
                    }
                }

                Button { router.tab = .kits } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Prefer paper?").font(KFont.heading(17)).foregroundStyle(Palette.text)
                            Text("This month’s kit: a sand tray, two paperbacks and quiet hands.").font(KFont.body(14)).foregroundStyle(Palette.text2)
                        }
                        Spacer()
                        Text("See kits").font(KFont.medium(14)).foregroundStyle(Palette.text)
                            .padding(.horizontal, 14).frame(minHeight: 40)
                            .overlay(Capsule().strokeBorder(Palette.outlineStrong))
                    }
                    .padding(16)
                    .kCard()
                }
                .buttonStyle(.plain)

                Text("No scores. No streaks. Nothing to keep up with.")
                    .font(KFont.body(13)).foregroundStyle(Palette.text3).frame(maxWidth: .infinity).padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .kScreen()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 5 { return "Still up?" }
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private func featuredSuggestion() -> (item: ActivityItem, eyebrow: String, continueFraction: Double?) {
        let library = StoryLibrary.shared
        if let last = library.story(store.state.lastStoryID), let p = store.state.progress[last.id], p.fraction > 0.02, !p.finished {
            return (ActivityItem(kind: .story(last)), "Pick up where you left off", p.fraction)
        }
        let h = Calendar.current.component(.hour, from: Date())
        if h < 5 { return (ActivityItem(kind: .garden), "For a wakeful night", nil) }
        if h >= 21 { return (ActivityItem(kind: .lantern), "Before sleep", nil) }
        let day = Calendar.current.component(.day, from: Date())
        if let story = library.stories.isEmpty ? nil : library.stories[day % library.stories.count] {
            return (ActivityItem(kind: .story(story)), "For tonight", nil)
        }
        return (ActivityItem(kind: .garden), "For tonight", nil)
    }

    private func moreForYou(excluding id: String) -> [ActivityItem] {
        var items = [ActivityItem(kind: .garden), ActivityItem(kind: .lantern)]
        if let story = StoryLibrary.shared.stories.first(where: { $0.id != id && store.state.progress[$0.id]?.finished != true }) {
            items.append(ActivityItem(kind: .story(story)))
        }
        return Array(items.filter { $0.id != id }.prefix(2))
    }
}

struct FeaturedCard: View {
    var item: ActivityItem
    var eyebrow: String
    var continueFraction: Double?
    @Environment(Router.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            art
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .clipped()
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: eyebrow)
                Text(item.title).font(KFont.title(24)).foregroundStyle(Palette.text)
                HStack(spacing: 6) {
                    ForEach(item.tags.indices, id: \.self) { i in
                        ActivityTag(text: item.tags[i].0, systemImage: item.tags[i].1, filled: item.tags[i].2)
                    }
                }
                Text(continueFraction.map { "\(Int($0 * 100))% read. \(item.subtitle)" } ?? item.subtitle)
                    .font(KFont.body(15)).foregroundStyle(Palette.text2).lineLimit(3)
                HStack(spacing: 10) {
                    Button {
                        item.open(router: router)
                    } label: {
                        Label(continueFraction == nil ? "Open" : "Continue", systemImage: "arrow.right")
                            .labelStyle(TrailingIconLabelStyle())
                    }
                    .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                    if let s = item.story {
                        Button { router.open(.listen(s.id)) } label: { Label("Listen", systemImage: "headphones") }
                            .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                    }
                }
                .padding(.top, 4)
            }
            .padding(18)
        }
        .kCard(radius: 22)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var art: some View {
        if let s = item.story {
            ZStack {
                LinearGradient(colors: [Color(hexString: s.palette.first ?? "#E8DCC4"), Color(hexString: s.palette.last ?? "#1C2139")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                StoryCover(story: s).frame(width: 96).padding(.vertical, 18)
            }
        } else {
            ArtImage(name: item.artName)
        }
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) { configuration.title; configuration.icon }
    }
}

struct SmallActivityCard: View {
    var item: ActivityItem
    @Environment(Router.self) private var router
    var body: some View {
        Button { item.open(router: router) } label: {
            VStack(alignment: .leading, spacing: 0) {
                ArtImage(name: item.artName)
                    .frame(height: 96)
                    .frame(maxWidth: .infinity)
                    .clipped()
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(KFont.heading(16)).foregroundStyle(Palette.text).lineLimit(2)
                    Text(item.shortLine).font(KFont.body(12, relativeTo: .caption)).foregroundStyle(Palette.text2).lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .kCard(radius: 18)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title). \(item.shortLine)")
    }
}

/// Shown on Tonight while a story is being narrated, so it's easy to pause or go back to it.
struct NowPlayingCard: View {
    @Environment(NarrationPlayer.self) private var player
    @Environment(Router.self) private var router
    var body: some View {
        if let story = player.story, player.isPlaying || player.askStillAwake {
            HStack(spacing: 12) {
                StoryCover(story: story).frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Now playing").font(KFont.body(12, relativeTo: .caption)).foregroundStyle(Palette.gold)
                    Text(story.title).font(KFont.heading(16)).foregroundStyle(Palette.text).lineLimit(1)
                }
                Spacer()
                CircleIconButton(systemImage: player.isPlaying ? "pause.fill" : "play.fill",
                                 label: player.isPlaying ? "Pause" : "Play") { player.toggle() }
            }
            .padding(12)
            .kCard(radius: 16)
            .contentShape(Rectangle())
            .onTapGesture { router.open(.listen(story.id)) }
            .accessibilityAction(named: "Open player") { router.open(.listen(story.id)) }
        }
    }
}
