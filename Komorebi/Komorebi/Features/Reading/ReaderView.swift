import SwiftUI

/// The reader: scrolls gently, remembers your place, and offers reading comfort settings.
struct ReaderView: View {
    var story: Story
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.komorebiReduceMotion) private var reduce

    @State private var position: Int?
    @State private var showComfort = false
    @State private var dimLevel: Double = 0
    @State private var openedAt = Date()
    @State private var restored = false

    private var comfort: ReadingComfort { store.state.comfort }
    private var endIndex: Int { story.blocks.count }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: 0x141726).ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: comfort.pointSize * 0.9) {
                        header.id(-1)
                        ForEach(Array(story.blocks.enumerated()), id: \.offset) { index, block in
                            blockView(block).id(index)
                        }
                        ending.id(endIndex)
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 24)
                    .padding(.top, 70)
                    .padding(.bottom, 60)
                }
                .scrollPosition(id: $position, anchor: .top)
                .onAppear {
                    guard !restored else { return }
                    restored = true
                    if let saved = store.state.progress[story.id], !saved.finished, saved.blockIndex > 0 {
                        DispatchQueue.main.async { proxy.scrollTo(saved.blockIndex, anchor: .top) }
                    }
                }
            }
            topBar
            progressBar
        }
        .overlay {
            Color(hex: 0xFF9A3C).opacity(comfort.warmth * 0.3).blendMode(.multiply).ignoresSafeArea().allowsHitTesting(false)
        }
        .overlay {
            Color.black.opacity(dimLevel).ignoresSafeArea().allowsHitTesting(false)
        }
        .statusBarHidden(true)
        .sheet(isPresented: $showComfort) {
            ComfortSheet().presentationDetents([.medium, .large]).presentationBackground(Palette.card)
        }
        .onChange(of: position) { _, newValue in
            guard let index = newValue, index >= 0 else { return }
            let clamped = min(index, max(0, story.blocks.count - 1))
            store.saveProgress(storyID: story.id, blockIndex: index >= endIndex ? story.blocks.count - 1 : clamped, blockCount: story.blocks.count)
        }
        .task(id: comfort.dimSlowly) {
            // "Dim slowly": lowers the page brightness over ten minutes while you read.
            openedAt = Date()
            dimLevel = 0
            guard comfort.dimSlowly else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                let minutes = Date().timeIntervalSince(openedAt) / 60
                withAnimation(.easeInOut(duration: 4)) { dimLevel = min(0.45, minutes / 10 * 0.45) }
            }
        }
        .onAppear {
            store.state.lastStoryID = story.id
            SoundEngine.shared.play(.page, volume: 0.6)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: story.collectionName)
            Text(story.title).font(KFont.title(30)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
            Text(story.author).font(KFont.body(16)).foregroundStyle(Palette.text2)
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func blockView(_ block: StoryBlock) -> some View {
        switch block.type {
        case .heading:
            Text(block.text ?? "")
                .font(KFont.heading(CGFloat(comfort.pointSize) + 2))
                .foregroundStyle(Palette.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .accessibilityAddTraits(.isHeader)
        case .paragraph:
            Text(block.text ?? "")
                .font(KFont.reading(CGFloat(comfort.pointSize), serif: comfort.serif))
                .foregroundStyle(Palette.text)
                .lineSpacing(comfort.pointSize * 0.45)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        case .poem:
            VStack(alignment: .leading, spacing: comfort.pointSize * 0.8) {
                if let number = block.text {
                    Text(number).font(KFont.heading(CGFloat(comfort.pointSize))).foregroundStyle(Palette.gold)
                        .accessibilityLabel("Song \(number)")
                }
                ForEach(Array((block.stanzas ?? []).enumerated()), id: \.offset) { _, stanza in
                    Text(stanza.joined(separator: "\n"))
                        .font(KFont.reading(CGFloat(comfort.pointSize), serif: comfort.serif))
                        .foregroundStyle(Palette.text)
                        .lineSpacing(comfort.pointSize * 0.45)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var ending: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("The end").font(KFont.heading(18)).foregroundStyle(Palette.text2).frame(maxWidth: .infinity).padding(.top, 20)
            VStack(alignment: .leading, spacing: 12) {
                Text("A line to keep, if you’d like").font(KFont.medium(14)).foregroundStyle(Palette.gold)
                Text("“\(story.keepLine)”").font(KFont.reading(19, serif: true)).foregroundStyle(Palette.text)
                let kept = store.hasKept(line: story.keepLine, from: story.id)
                Button {
                    store.keep(line: story.keepLine, from: story.id)
                    Haptics.shared.success()
                    SoundEngine.shared.play(.bell, volume: 0.5)
                } label: {
                    Label(kept ? "Kept in your Profile" : "Keep this line", systemImage: kept ? "checkmark" : "plus")
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                .disabled(kept)
            }
            .padding(18)
            .kCard(radius: 18, raised: false)
            Button("Close the book") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
        }
        .onAppear {
            store.saveProgress(storyID: story.id, blockIndex: max(0, story.blocks.count - 1), blockCount: story.blocks.count)
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            CircleIconButton(systemImage: "xmark", label: "Close") { dismiss() }
            Spacer()
            CircleIconButton(systemImage: "headphones", label: "Listen instead") { router.activity = .listen(story.id) }
            CircleIconButton(systemImage: "textformat.size", label: "Reading comfort") { showComfort = true }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(LinearGradient(colors: [Color(hex: 0x141726), Color(hex: 0x141726, opacity: 0)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    private var progressBar: some View {
        let fraction = store.state.progress[story.id]?.fraction ?? 0
        return VStack {
            Spacer()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.outline)
                    Capsule().fill(Palette.gold).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
            .accessibilityElement()
            .accessibilityLabel("\(Int(fraction * 100)) percent read")
        }
        .allowsHitTesting(false)
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
                Text("Reading comfort").font(KFont.title(22)).foregroundStyle(Palette.text)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(GhostButtonStyle())
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
                SettingRow(title: "Dim slowly", detail: "Lowers the page brightness over ten minutes") {
                    Toggle("", isOn: $store.state.comfort.dimSlowly).labelsHidden().tint(Palette.gold)
                }
            }
            .kCard(radius: 14)
            Text("“Only let me make my life simple and straight.”")
                .font(KFont.reading(CGFloat(store.state.comfort.pointSize), serif: store.state.comfort.serif))
                .foregroundStyle(Palette.text2)
            Spacer()
        }
        .padding(20)
    }
}
