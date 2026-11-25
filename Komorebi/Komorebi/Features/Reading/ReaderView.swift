import SwiftUI

/// The reader from the Figma prototype: paged, swipe to turn, with read-along.
/// When the narration plays here, the sentence being read is highlighted and pages turn on their own.
struct ReaderView: View {
    var story: Story
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(NarrationPlayer.self) private var player
    @Environment(\.dismiss) private var dismiss
    @Environment(\.komorebiReduceMotion) private var reduce

    @State private var text: StoryText?
    @State private var pages: [StoryPage] = []
    @State private var layoutKey = ""
    @State private var page = 0
    @State private var restored = false
    @State private var showComfort = false
    @State private var lastManualTurn = Date.distantPast
    @State private var dimLevel: Double = 0

    init(story: Story) {
        self.story = story
        _text = State(initialValue: StoryText(story: story))
    }

    private var comfort: ReadingComfort { store.state.comfort }
    /// The final page after the story: "The end." and a line to keep.
    private var endPage: Int { pages.count }
    private var isListeningHere: Bool { player.story?.id == story.id && player.problem == nil }
    private var activeUnit: Int? {
        guard isListeningHere, let text, player.duration > 0, player.isPlaying || player.elapsed > 1 else { return nil }
        return text.unit(at: player.elapsed, duration: player.duration)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            GeometryReader { geo in
                let pageSize = CGSize(width: geo.size.width - 32, height: geo.size.height - 16)
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i])
                            .frame(width: pageSize.width, height: pageSize.height, alignment: .topLeading)
                            .padding(.horizontal, 16)
                            .tag(i)
                    }
                    theEnd.tag(endPage)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onAppear { layout(pageSize) }
                .onChange(of: pageSize) { _, size in layout(size) }
                .onChange(of: comfort) { _, _ in layout(pageSize, force: true) }
            }
            if isListeningHere && (player.isPlaying || player.elapsed > 1) { miniPlayer }
            footer
        }
        .background(Palette.background.ignoresSafeArea())
        .overlay {
            Color(hex: 0xFF9A3C).opacity(comfort.warmth * 0.3).blendMode(.multiply).ignoresSafeArea().allowsHitTesting(false)
        }
        .overlay { Color.black.opacity(dimLevel).ignoresSafeArea().allowsHitTesting(false) }
        .statusBarHidden(true)
        .sheet(isPresented: $showComfort) {
            ComfortSheet().presentationDetents([.medium, .large]).presentationBackground(Palette.card)
        }
        .onChange(of: page) { old, new in
            if new != old { SoundEngine.shared.play(.page, volume: 0.5) }
            saveProgress()
        }
        .onChange(of: activeUnit) { _, unit in follow(unit) }
        .task(id: comfort.dimSlowly) {
            dimLevel = 0
            guard comfort.dimSlowly else { return }
            let opened = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                let minutes = Date().timeIntervalSince(opened) / 60
                withAnimation(.easeInOut(duration: 4)) { dimLevel = min(0.45, minutes / 10 * 0.45) }
            }
        }
        .onDisappear { LoadingCenter.shared.end("reader-\(story.id)") }
        .onAppear {
            store.state.lastStoryID = story.id
        }
    }

    // MARK: Layout

    /// Lays out the pages off the main thread, so opening a long story or changing the text size never freezes the screen.
    /// If it takes more than a moment, the loading layer covers the reader.
    private func layout(_ size: CGSize, force: Bool = false) {
        guard let text else { return }
        let key = "\(Int(size.width))x\(Int(size.height))-\(comfort.sizeIndex)-\(comfort.serif)"
        guard force || key != layoutKey else { return }
        let anchorUnit = pages.indices.contains(page) ? pages[page].firstUnit : nil
        layoutKey = key
        let pointSize = comfort.pointSize, serif = comfort.serif
        let loadingID = "reader-\(story.id)"
        LoadingCenter.shared.begin(loadingID, "Opening the book…")
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                StoryPaginator.pages(for: text, size: pointSize, serif: serif, pageSize: size)
            }.value
            LoadingCenter.shared.end(loadingID)
            guard layoutKey == key else { return }
            pages = result
            if let anchorUnit {
                page = pages.firstIndex { $0.contains(unit: anchorUnit) } ?? 0
            } else if !restored {
                restored = true
                if let saved = store.state.progress[story.id], !saved.finished {
                    page = pages.firstIndex { $0.contains(unit: saved.blockIndex) } ?? 0
                }
                if let unit = activeUnit { page = pages.firstIndex { $0.contains(unit: unit) } ?? page }
            }
        }
    }

    private func saveProgress() {
        guard let text, !pages.isEmpty else { return }
        let unit = page >= endPage ? max(0, text.units.count - 1) : pages[page].firstUnit
        store.saveProgress(storyID: story.id, blockIndex: unit, blockCount: text.units.count)
    }

    /// Turns the page to keep up with the narration, unless the reader just turned it themselves.
    private func follow(_ unit: Int?) {
        guard let unit, Date().timeIntervalSince(lastManualTurn) > 8,
              let target = pages.firstIndex(where: { $0.contains(unit: unit) }), target != page else { return }
        withAnimation(reduce ? .easeInOut(duration: 0.3) : .easeInOut(duration: 0.5)) { page = target }
    }

    private func turn(_ delta: Int) {
        lastManualTurn = Date()
        let next = max(0, min(endPage, page + delta))
        withAnimation(reduce ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.35)) { page = next }
    }

    // MARK: Page

    private func pageView(_ p: StoryPage) -> some View {
        VStack(alignment: .leading, spacing: StoryPaginator.paragraphSpacing(comfort.pointSize)) {
            ForEach(p.slices.indices, id: \.self) { i in
                sliceView(p.slices[i])
            }
        }
        .simultaneousGesture(DragGesture(minimumDistance: 20).onChanged { _ in lastManualTurn = Date() })
    }

    @ViewBuilder
    private func sliceView(_ slice: StoryPage.Slice) -> some View {
        if let text {
            let paragraph = text.paragraphs[slice.paragraph]
            let active = activeUnit
            VStack(alignment: .leading, spacing: 4) {
                if let label = paragraph.label, slice.units.lowerBound == paragraph.units.lowerBound {
                    Text(label).font(KFont.heading(CGFloat(comfort.pointSize))).foregroundStyle(Palette.gold)
                        .accessibilityLabel("Song \(label)")
                }
                if paragraph.kind == .heading {
                    Text(text.units[slice.units.lowerBound].text)
                        .font(KFont.heading(CGFloat(comfort.pointSize) + 2))
                        .foregroundStyle(Palette.gold)
                        .accessibilityAddTraits(.isHeader)
                } else {
                    composed(slice, text: text, active: active)
                        .font(KFont.reading(CGFloat(comfort.pointSize), serif: comfort.serif))
                        .lineSpacing(StoryPaginator.lineSpacing(comfort.pointSize))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // During read-along, tap a paragraph to move the narration there.
                guard isListeningHere else { return }
                player.seek(to: text.time(ofUnit: slice.units.lowerBound, duration: player.duration))
                Haptics.shared.selection()
            }
        }
    }

    /// Joins sentences into one Text, highlighting the one being narrated.
    private func composed(_ slice: StoryPage.Slice, text: StoryText, active: Int?) -> Text {
        let separator = text.paragraphs[slice.paragraph].kind == .stanza ? "\n" : " "
        var result = Text("")
        for (n, i) in slice.units.enumerated() {
            let color: Color
            if let active { color = i == active ? Palette.text : Palette.text.opacity(0.45) } else { color = Palette.text }
            let piece = Text(text.units[i].text).foregroundColor(color)
            result = n == 0 ? piece : result + Text(separator) + piece
        }
        return result
    }

    private var theEnd: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "moon").font(.system(size: 24)).foregroundStyle(Palette.background)
                    .frame(width: 52, height: 52).background(Circle().fill(Palette.gold)).padding(.top, 24)
                Text("The end.").font(KFont.heading(24)).foregroundStyle(Palette.text)
                Text("\(story.title) · \(story.author)").font(KFont.body(14)).foregroundStyle(Palette.text2)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("A LINE TO KEEP").font(KFont.medium(14)).tracking(1).foregroundStyle(Palette.gold)
                        Spacer()
                        let kept = store.hasKept(line: story.keepLine, from: story.id)
                        Button {
                            store.keep(line: story.keepLine, from: story.id)
                            Haptics.shared.success()
                            SoundEngine.shared.play(.bell, volume: 0.5)
                        } label: {
                            Image(systemName: kept ? "bookmark.fill" : "bookmark").foregroundStyle(Palette.text).frame(width: 44, height: 44)
                        }
                        .disabled(kept)
                        .accessibilityLabel(kept ? "Kept in your Profile" : "Keep this line")
                    }
                    Text("“\(story.keepLine)”").font(KFont.reading(18, serif: true)).foregroundStyle(Palette.text)
                }
                .padding(16)
                .kCard(radius: 16, raised: false)
                Button("Back to Tonight") { dismiss() }.buttonStyle(PrimaryButtonStyle()).padding(.top, 8)
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            if let text { store.saveProgress(storyID: story.id, blockIndex: max(0, text.units.count - 1), blockCount: text.units.count) }
        }
    }

    // MARK: Chrome

    private var header: some View {
        HStack(spacing: 12) {
            CircleIconButton(systemImage: "xmark", label: "Close") { dismiss() }
            VStack(alignment: .leading, spacing: 1) {
                Text(story.title).font(KFont.heading(20)).foregroundStyle(Palette.text).lineLimit(1)
                if let text, !pages.isEmpty {
                    Text(page >= endPage ? "Finished" : "Page \(page + 1) of \(pages.count) · \(text.minutesLeft(from: pages[page].firstUnit)) min left")
                        .font(KFont.body(14)).foregroundStyle(Palette.text2)
                }
            }
            Spacer()
            CircleIconButton(systemImage: "moon", label: "Reading comfort") { showComfort = true }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var miniPlayer: some View {
        HStack {
            Text(story.title).font(KFont.medium(16)).foregroundStyle(Palette.text)
            Spacer()
            Text("\(max(0, player.duration - player.elapsed).playbackTime) left").font(KFont.body(14)).foregroundStyle(Palette.text2).monospacedDigit()
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15)).foregroundStyle(Palette.background)
                    .frame(width: 40, height: 40).background(Circle().fill(Palette.gold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
        }
        .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 4)
        .background(Capsule().fill(Palette.card))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onTapGesture { router.activity = .listen(story.id) }
        .gesture(DragGesture(minimumDistance: 20).onEnded { v in
            if v.translation.height < -30 { router.activity = .listen(story.id) }
        })
        .accessibilityAction(named: "Open player") { router.activity = .listen(story.id) }
        .transition(.opacity)
    }

    private var footer: some View {
        let bookmarked = store.state.bookmarks[story.id].map { b in pages.indices.contains(page) && pages[page].contains(unit: b) } ?? false
        return VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.outline)
                    Capsule().fill(Palette.gold).frame(width: geo.size.width * (pages.isEmpty ? 0 : Double(min(page + 1, pages.count)) / Double(pages.count)))
                }
            }
            .frame(height: 3)
            .accessibilityHidden(true)
            HStack(spacing: 12) {
                CircleIconButton(systemImage: "arrow.left", label: "Previous page") { turn(-1) }
                    .disabled(page == 0)
                Spacer()
                CircleIconButton(systemImage: isListeningHere && player.isPlaying ? "pause" : "headphones",
                                 label: isListeningHere && player.isPlaying ? "Pause narration" : "Read along with narration") { toggleReadAlong() }
                CircleIconButton(systemImage: bookmarked ? "bookmark.fill" : "bookmark", label: bookmarked ? "Remove bookmark" : "Bookmark this page") {
                    guard pages.indices.contains(page) else { return }
                    if bookmarked { store.state.bookmarks[story.id] = nil } else { store.state.bookmarks[story.id] = pages[page].firstUnit }
                    Haptics.shared.selection()
                }
                Spacer()
                CircleIconButton(systemImage: "arrow.right", label: "Next page") { turn(1) }
                    .disabled(page >= endPage)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func toggleReadAlong() {
        if isListeningHere && player.isPlaying {
            player.pause()
            return
        }
        player.load(story)
        guard player.problem == nil, let text else { return }
        // Start the narration from the top of this page, unless it's already partway through this page.
        if pages.indices.contains(page) {
            let current = player.duration > 0 ? text.unit(at: player.elapsed, duration: player.duration) : -1
            if !pages[page].contains(unit: current) {
                player.seek(to: text.time(ofUnit: pages[page].firstUnit, duration: player.duration > 0 ? player.duration : story.audioSeconds))
            }
        }
        lastManualTurn = .distantPast
        player.play()
    }
}

/// Reading comfort: size, typeface, warmth, dim slowly. Saved for every story.
struct ComfortSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Reading comfort").font(KFont.heading(24)).foregroundStyle(Palette.text)
                Spacer()
                CircleIconButton(systemImage: "xmark", label: "Close") { dismiss() }
            }
            VStack(spacing: 0) {
                SettingRow(title: "Text size", detail: ReadingComfort.sizeNames[store.state.comfort.sizeIndex]) {
                    HStack(spacing: 8) {
                        CircleIconButton(systemImage: "textformat.size.smaller", label: "Smaller text") {
                            store.state.comfort.sizeIndex = max(0, store.state.comfort.sizeIndex - 1)
                        }
                        .disabled(store.state.comfort.sizeIndex == 0)
                        CircleIconButton(systemImage: "textformat.size.larger", label: "Larger text") {
                            store.state.comfort.sizeIndex = min(ReadingComfort.sizes.count - 1, store.state.comfort.sizeIndex + 1)
                        }
                        .disabled(store.state.comfort.sizeIndex == ReadingComfort.sizes.count - 1)
                    }
                }
                RowDivider()
                SettingRow(title: "Typeface", detail: nil) {
                    PillPicker(options: [(true, "Serif"), (false, "Sans")], selection: $store.state.comfort.serif, label: "Typeface")
                        .frame(width: 170)
                }
                RowDivider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Warmth").font(KFont.body(16)).foregroundStyle(Palette.text)
                    HStack {
                        Image(systemName: "sun.max").foregroundStyle(Palette.text2)
                        Slider(value: $store.state.comfort.warmth, in: 0...1).tint(Palette.gold).accessibilityLabel("Warmth")
                        Image(systemName: "flame").foregroundStyle(Palette.warm)
                    }
                }
                .padding(16)
                RowDivider()
                SettingRow(title: "Dim slowly as I read", detail: "The screen fades a little with each page") {
                    Toggle("", isOn: $store.state.comfort.dimSlowly).labelsHidden().tint(Palette.gold).accessibilityLabel("Dim slowly as I read")
                }
            }
            .kCard(radius: 16)
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .padding(16)
    }
}
