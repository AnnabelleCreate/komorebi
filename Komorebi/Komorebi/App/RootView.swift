import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var ready = false

    var body: some View {
        @Bindable var router = router
        let reduce = store.reduceMotion(system: systemReduceMotion)

        ZStack {
            Palette.background.ignoresSafeArea()
            if !ready {
                LoadingView(message: "Settling in…", style: .fullScreen).transition(.opacity)
            } else if store.state.onboarded {
                MainTabView().transition(.opacity)
            } else {
                OnboardingView().transition(.opacity)
            }
        }
        .overlay { WarmScreenTint(amount: store.state.settings.warmScreen) }
        .overlay(alignment: .top) { StatusBanner() }
        .animation(Motion.ease(reduce), value: store.state.onboarded)
        .animation(Motion.ease(reduce), value: ready)
        .task {
            // Stories and sounds load off the main thread so the first frame never freezes.
            await Task.detached(priority: .userInitiated) {
                _ = StoryLibrary.shared.stories.count
                SoundEngine.shared.prepare()
            }.value
            ready = true
        }
        .environment(\.komorebiReduceMotion, reduce)
        .modifier(AppTextSize(choice: store.state.textSize))
        .fullScreenCover(item: $router.activity) { route in
            ActivityHost(route: route)
                .environment(store)
                .environment(router)
                .environment(NarrationPlayer.shared)
                .environment(PromptScheduler.shared)
                .environment(\.komorebiReduceMotion, reduce)
                .modifier(AppTextSize(choice: store.state.textSize))
                .preferredColorScheme(.dark)
        }
        .onAppear {
            PromptScheduler.shared.apply(evening: store.state.evening, night: store.state.night)
            PromptScheduler.shared.scheduleKitReminders(for: store.state.orders)
        }
    }
}

/// An amber tint over everything outside the reader (which has its own warmth).
struct WarmScreenTint: View {
    var amount: Double
    var body: some View {
        Color(hex: 0xFF9A3C)
            .opacity(amount * 0.22)
            .blendMode(.multiply)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Shows rare problems: a damaged save that was recovered, or a save that failed.
struct StatusBanner: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        if let message = store.saveProblem ?? (store.recoveredFromDamagedSave ? "Komorebi couldn’t read its saved data, so it started fresh. A backup was kept on this phone." : nil) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle").foregroundStyle(Palette.gold)
                Text(message).font(KFont.body(13)).foregroundStyle(Palette.text)
                Spacer(minLength: 0)
                Button {
                    store.recoveredFromDamagedSave = false
                    store.saveProblem = nil
                } label: {
                    Image(systemName: "xmark").foregroundStyle(Palette.text2).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Dismiss")
            }
            .padding(12)
            .kCard(radius: 14, raised: true)
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }
}

struct MainTabView: View {
    @Environment(Router.self) private var router
    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            NavigationStack { TonightView() }
                .tabItem { Label("Tonight", systemImage: "moon.stars") }
                .tag(AppTab.tonight)
            NavigationStack { DiscoverView() }
                .tabItem { Label("Discover", systemImage: "magnifyingglass") }
                .tag(AppTab.discover)
            KitsTab()
                .tabItem { Label("Kits", systemImage: "shippingbox") }
                .tag(AppTab.kits)
            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(AppTab.profile)
        }
        .tint(Palette.gold)
        .onChange(of: router.tab) { _, _ in Haptics.shared.selection() }
    }
}

/// Hosts a full-screen activity.
struct ActivityHost: View {
    var route: ActivityRoute
    @Environment(AppStore.self) private var store
    var body: some View {
        Group {
            switch route {
            case .garden:
                GardenView()
            case .lantern:
                LanternView()
            case .reader(let id):
                if let story = StoryLibrary.shared.story(id) { ReaderView(story: story) } else { MissingStoryView() }
            case .listen(let id):
                if let story = StoryLibrary.shared.story(id) { ListenView(story: story) } else { MissingStoryView() }
            }
        }
        .overlay {
            if !isReader { WarmScreenTint(amount: store.state.settings.warmScreen) }
        }
    }

    private var isReader: Bool {
        if case .reader = route { return true }
        return false
    }
}

struct MissingStoryView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack {
            EmptyState(systemImage: "book.closed", title: "This story isn’t here",
                       message: "It may have been removed in an update.", actionTitle: "Back", action: { dismiss() })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
    }
}
