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
        let goTo = store.state.goTo.flatMap(ActivityItem.from(key:))
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
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
                .padding(.top, 16)

                ScreenTitle(title: greeting, subtitle: store.state.name.isEmpty ? "Here’s something for tonight." : "Here’s something for tonight, \(store.state.name).")

                NowPlayingCard()

                if let goTo {
                    GoToCard(item: goTo)
                }

                FeaturedCard(item: featured.item, eyebrow: featured.eyebrow, continueFraction: featured.continueFraction)

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(title: "Rituals", subtitle: "Let the day go")
                    HStack(spacing: 12) {
                        SmallActivityCard(item: ActivityItem(kind: .lantern))
                        SmallActivityCard(item: ActivityItem(kind: .garden))
                    }
                }

                StoryShelf()

                Button { router.tab = .kits } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Prefer paper?").font(KFont.heading(20)).foregroundStyle(Palette.text)
                            Text("This month’s kit: a sand tray, two paperbacks and quiet hands.").font(KFont.body(14)).foregroundStyle(Palette.text2)
                        }
                        Spacer()
                        Text("See kits").font(KFont.medium(14)).foregroundStyle(Palette.text)
                            .padding(.horizontal, 14).frame(minHeight: 44)
                            .overlay(Capsule().strokeBorder(Palette.outlineStrong))
                    }
                    .padding(16)
                    .kCard()
                }
                .buttonStyle(.plain)

                Text("No scores. No streaks. Nothing to keep up with.")
                    .font(KFont.body(14)).foregroundStyle(Palette.text3).frame(maxWidth: .infinity).padding(.top, 4)
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

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 5 { return "Still up?" }
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private func featuredSuggestion() -> (item: ActivityItem, eyebrow: String, continueFraction: Double?) {
        let library = StoryLibrary.shared
        let goToID = store.state.goTo
        if let last = library.story(store.state.lastStoryID), let p = store.state.progress[last.id], p.fraction > 0.02, !p.finished, last.id != goToID {
            return (ActivityItem(kind: .story(last)), "Pick up where you left off", p.fraction)
        }
        let h = Calendar.current.component(.hour, from: Date())
        if h < 5 && goToID != "garden" { return (ActivityItem(kind: .garden), "For a wakeful night", nil) }
        if h >= 21 && goToID != "lantern" { return (ActivityItem(kind: .lantern), "For tonight", nil) }
        let day = Calendar.current.component(.day, from: Date())
        let candidates = library.stories.filter { $0.id != goToID }
        if !candidates.isEmpty {
            return (ActivityItem(kind: .story(candidates[day % candidates.count])), "For tonight", nil)
        }
        return (ActivityItem(kind: goToID == "lantern" ? .garden : .lantern), "For tonight", nil)
    }
}

struct SectionHeading: View {
    var title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(KFont.heading(20)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
            if let subtitle { Text(subtitle).font(KFont.body(14)).foregroundStyle(Palette.text2) }
        }
    }
}

/// "Your go-to": the favorite chosen to always sit at the top of Tonight.
struct GoToCard: View {
    var item: ActivityItem
    @Environment(Router.self) private var router
    var body: some View {
        Button { item.open(router: router) } label: {
            HStack(spacing: 14) {
                ArtImage(name: item.artName)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill").font(.system(size: 11))
                        Text("YOUR GO-TO").font(KFont.medium(12, relativeTo: .caption)).tracking(1.4)
                    }
                    .foregroundStyle(Palette.gold)
                    Text(item.title).font(KFont.heading(20)).foregroundStyle(Palette.text).lineLimit(1)
                    Text(item.shortLine).font(KFont.body(14)).foregroundStyle(Palette.text2).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.background)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Palette.gold))
            }
            .padding(12)
            .kCard(radius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Your go-to: \(item.title). \(item.shortLine)")
        .accessibilityHint("Opens it")
    }
}

/// Short stories: collection tabs and a swipeable shelf of covers, as in the Figma prototype.
struct StoryShelf: View {
    @Environment(AppStore.self) private var store
    @Environment(\.komorebiReduceMotion) private var reduce
    @State private var collection = "myth"
    @State private var selectedID: String?

    var body: some View {
        let library = StoryLibrary.shared
        let stories = library.stories(in: collection)
        let current = library.story(selectedID) ?? stories.first
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: "From across Asia")
                Text("Find a story to linger over.").font(KFont.heading(24)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
            }
            if let problem = library.loadError {
                EmptyState(systemImage: "book.closed", title: "Stories unavailable", message: problem)
            } else {
                HStack(spacing: 20) {
                    ForEach(StoryLibrary.collections) { c in
                        Button {
                            withAnimation(Motion.ease(reduce)) { collection = c.id; selectedID = nil }
                            Haptics.shared.selection()
                        } label: {
                            VStack(spacing: 8) {
                                Text(c.name).font(collection == c.id ? KFont.medium(16) : KFont.body(16))
                                    .foregroundStyle(collection == c.id ? Palette.text : Palette.text2)
                                Rectangle().fill(collection == c.id ? Palette.gold : .clear).frame(height: 2)
                            }
                            .fixedSize()
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(collection == c.id ? .isSelected : [])
                    }
                    Spacer()
                }
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.outline).frame(height: 1).offset(y: -9) }

                GeometryReader { geo in
                    let coverWidth: CGFloat = 160
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 18) {
                            ForEach(stories) { story in
                                NavigationLink(value: story.id) {
                                    StoryCover(story: story)
                                        .frame(width: coverWidth)
                                        .scaleEffect(story.id == current?.id ? 1 : 0.9)
                                        .opacity(story.id == current?.id ? 1 : 0.55)
                                        .animation(Motion.ease(reduce), value: current?.id)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(story.title), \(story.author). \(story.readMinutes) minute read.")
                                .id(story.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, max(0, (geo.size.width - coverWidth) / 2), for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $selectedID, anchor: .center)
                    .onChange(of: selectedID) { _, _ in Haptics.shared.selection() }
                }
                .frame(height: 245)
                .id(collection)

                if let current {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            ForEach(stories) { s in
                                Circle().fill(s.id == current.id ? Palette.text : Palette.outline).frame(width: 6, height: 6)
                            }
                        }
                        .accessibilityHidden(true)
                        Text(current.title).font(KFont.heading(24)).foregroundStyle(Palette.text)
                        Text("\(current.origin) · \(current.author)").font(KFont.body(14)).foregroundStyle(Palette.text2)
                        HStack(spacing: 14) {
                            Label("\(current.readMinutes) min read", systemImage: "book")
                            Label("\(current.listenMinutes) min listen", systemImage: "headphones")
                        }
                        .font(KFont.body(14)).foregroundStyle(Palette.gold)
                        NavigationLink(value: current.id) {
                            Label("Open", systemImage: "arrow.right").labelStyle(TrailingIconLabelStyle())
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
            }
        }
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
                    .font(KFont.body(16)).foregroundStyle(Palette.text2).lineLimit(3)
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
    @Environment(AppStore.self) private var store
    var body: some View {
        Button { item.open(router: router) } label: {
            VStack(alignment: .leading, spacing: 0) {
                ArtImage(name: item.artName)
                    .frame(height: 96)
                    .frame(maxWidth: .infinity)
                    .clipped()
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(KFont.heading(20)).foregroundStyle(Palette.text).lineLimit(2)
                    Text(item.shortLine).font(KFont.body(14, relativeTo: .caption)).foregroundStyle(Palette.text2).lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .kCard(radius: 16)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title). \(item.shortLine)")
        .overlay(alignment: .topTrailing) {
            Button {
                store.toggleFavorite(item.id)
                Haptics.shared.selection()
            } label: {
                Image(systemName: store.isFavorite(item.id) ? "heart.fill" : "heart")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.text)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Palette.background.opacity(0.55)).frame(width: 32, height: 32))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.isFavorite(item.id) ? "Remove \(item.title) from favorites" : "Add \(item.title) to favorites")
        }
    }
}

/// Shown on Tonight while a story is playing, or paused partway (even after closing the app).
struct NowPlayingCard: View {
    @Environment(NarrationPlayer.self) private var player
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        let library = StoryLibrary.shared
        let story = player.story ?? library.story(store.state.lastListenedID)
        if let story {
            let isCurrent = player.story?.id == story.id
            let position = isCurrent ? player.elapsed : (store.state.audioPositions[story.id] ?? 0)
            let duration = isCurrent && player.duration > 0 ? player.duration : story.audioSeconds
            let playing = isCurrent && player.isPlaying
            if playing || (position > 5 && position < duration - 5) {
                HStack(spacing: 12) {
                    StoryCover(story: story).frame(width: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playing ? "Now playing" : "Paused").font(KFont.medium(14, relativeTo: .caption)).foregroundStyle(Palette.gold)
                        Text(story.title).font(KFont.heading(20)).foregroundStyle(Palette.text).lineLimit(1)
                        Text("\(max(0, duration - position).playbackTime) left").font(KFont.body(14)).foregroundStyle(Palette.text2)
                    }
                    Spacer()
                    Button {
                        if !isCurrent { player.load(story) }
                        player.toggle()
                    } label: {
                        Image(systemName: playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Palette.background)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(Palette.gold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(playing ? "Pause \(story.title)" : "Resume \(story.title)")
                }
                .padding(12)
                .kCard(radius: 16)
                .overlay(alignment: .bottom) {
                    GeometryReader { geo in
                        Capsule().fill(Palette.gold).frame(width: geo.size.width * min(1, position / max(1, duration)), height: 3)
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 1)
                    .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
                .onTapGesture { router.open(.listen(story.id)) }
                .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
                    // Swipe up on the card to open the player.
                    if value.translation.height < -30 { router.open(.listen(story.id)) }
                })
                .accessibilityAction(named: "Open player") { router.open(.listen(story.id)) }
            }
        }
    }
}
